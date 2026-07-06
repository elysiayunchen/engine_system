#!/usr/bin/env bash
# Engine System — 安装流校验测试(T-022 Task 3 / D-019a)
#
# 测试三组:
#   I1 正路:本地 file:// 源、带 --version(伪 tag)跑安装,manifest 为真哈希
#      → 校验通过,输出 verified 计数,exit 0;
#   I2 篡改:沙箱源里改一个被 manifest 覆盖的文件一字节 → 安装非零退出
#      且报错信息指名文件;
#   I3 兼容:manifest 去掉 sha256 键的旧格式 → 跳过校验并提示,安装成功。
#
# 沙箱手法抄 release.yml:72-116:
#   - 造 fake curl/wget 处理 file:// URL(cp 落地);
#   - sed 替换 install.sh 里 BASE_URL 与 manifest/runtime-law.md 下载地址为 file://;
#   - 沙箱内注入真 sha256(由 plugin/<src> 工作区字节实时算出)。
#
# 用法:bash tests/install-flow/run-install-tests.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

pass=0
fail=0

ok()  { echo "PASS  $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1 ($2)"; fail=$((fail+1)); }

# 创建沙箱:plugin/ + runtime-law.md 拷贝
setup_sandbox() {
  local sbx="$1"
  mkdir -p "$sbx/home" "$sbx/plugin"
  cp -a "$REPO_ROOT/plugin/." "$sbx/plugin/"
  cp "$REPO_ROOT/runtime-law.md" "$sbx/" 2>/dev/null || true
}

# 对 sandbox manifest 每条 src 算 sha256 并回填(保持单行格式)
inject_sha256() {
  local sbx="$1"
  local manifest="$sbx/plugin/manifest.json"
  # 先清掉已有 sha256(含 placeholder)
  sed -i 's/, "sha256": "[^"]*"//g' "$manifest"
  # 逐条插入
  while IFS= read -r src; do
    if [[ -f "$sbx/plugin/$src" ]]; then
      hash=$(sha256sum "$sbx/plugin/$src" | cut -d' ' -f1)
      sed -i "s|\"src\": \"$src\"|\"src\": \"$src\", \"sha256\": \"$hash\"|" "$manifest"
    fi
  done < <(grep -oE '"src"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest" | sed 's/.*"src"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
}

# 造 fake curl/wget:只处理 file://(cp 落地);http/https 返回 404
make_fake_curl() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/curl" <<'FAKE'
#!/usr/bin/env bash
url=""; dest=""; write_code=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) dest="$2"; shift 2 ;;
    -w) write_code=true; shift 2 ;;
    -sSL|-s|-L) shift ;;
    http*|file*) url="$1"; shift ;;
    *) shift ;;
  esac
done
if [[ "$url" == file://* ]]; then
  src="${url#file://}"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
    if $write_code; then echo "200"; fi
    exit 0
  else
    if $write_code; then echo "404"; fi
    exit 1
  fi
fi
if $write_code; then echo "404"; fi
exit 1
FAKE
  chmod +x "$bin_dir/curl"
  cp "$bin_dir/curl" "$bin_dir/wget"
}

# 把 install.sh 改为本地 file:// 源
patch_installer() {
  local sbx="$1"
  local out="$2"
  sed \
    -e 's|BASE_URL="https://raw.githubusercontent.com/${REPO}/v${VERSION_TAG}/${PLUGIN_DIR}"|BASE_URL="file://'"$sbx"'/plugin"|' \
    -e 's|BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${PLUGIN_DIR}"|BASE_URL="file://'"$sbx"'/plugin"|' \
    -e 's|https://raw.githubusercontent.com/${REPO}/v${VERSION_TAG}/${PLUGIN_DIR}/manifest.json|file://'"$sbx"'/plugin/manifest.json|' \
    -e 's|https://raw.githubusercontent.com/${REPO}/v${VERSION_TAG}/runtime-law.md|file://'"$sbx"'/runtime-law.md|' \
    -e 's|https://raw.githubusercontent.com/${REPO}/${BRANCH}/runtime-law.md|file://'"$sbx"'/runtime-law.md|' \
    "$INSTALL_SH" > "$out"
  chmod +x "$out"
}

echo "=== I. Install flow ==="

# I1: 正路 — manifest 全真哈希,校验通过,exit 0
sbx="$(mktemp -d)"
trap 'rm -rf "$sbx"' EXIT
setup_sandbox "$sbx"
inject_sha256 "$sbx"
make_fake_curl "$sbx/bin"
patch_installer "$sbx" "$sbx/install-local.sh"

work1="$(mktemp -d)"
(cd "$work1" && HOME="$sbx/home" PATH="$sbx/bin:$PATH" bash "$sbx/install-local.sh" --version 99.99.99 >"$sbx/i1.out" 2>&1)
rc=$?
rm -rf "$work1"
if [[ "$rc" -eq 0 ]] && grep -qi "verified" "$sbx/i1.out"; then
  ok "I1 normal-path checksum verify passes"
else
  bad "I1 normal-path checksum verify passes" "rc=$rc output:$(head -5 "$sbx/i1.out")"
fi

# I2: 篡改 — 改一个文件一字节 → 安装非零退出且报错指名文件
sbx2="$(mktemp -d)"
setup_sandbox "$sbx2"
inject_sha256 "$sbx2"
# 篡改 engine/README.md(沙箱源里改,安装后会被复制到目标)
printf 'tampered\n' >> "$sbx2/plugin/engine/README.md"
make_fake_curl "$sbx2/bin"
patch_installer "$sbx2" "$sbx2/install-local.sh"

work2="$(mktemp -d)"
(cd "$work2" && HOME="$sbx2/home" PATH="$sbx2/bin:$PATH" bash "$sbx2/install-local.sh" --version 99.99.99 >"$sbx2/i2.out" 2>&1)
rc=$?
rm -rf "$work2"
if [[ "$rc" -ne 0 ]] && grep -qi "README.md" "$sbx2/i2.out"; then
  ok "I2 tamper-detect hard-fail"
else
  bad "I2 tamper-detect hard-fail" "rc=$rc output:$(head -10 "$sbx2/i2.out")"
fi
rm -rf "$sbx2"

# I3: 兼容 — 去掉一条 sha256 键 → 跳过并提示,安装成功
sbx3="$(mktemp -d)"
setup_sandbox "$sbx3"
inject_sha256 "$sbx3"
# 去掉第一行的 sha256(第 3 行是 manifest 第一条)
sed -i '3s/, "sha256": "[^"]*"//' "$sbx3/plugin/manifest.json"
make_fake_curl "$sbx3/bin"
patch_installer "$sbx3" "$sbx3/install-local.sh"

work3="$(mktemp -d)"
(cd "$work3" && HOME="$sbx3/home" PATH="$sbx3/bin:$PATH" bash "$sbx3/install-local.sh" --version 99.99.99 >"$sbx3/i3.out" 2>&1)
rc=$?
rm -rf "$work3"
if [[ "$rc" -eq 0 ]]; then
  ok "I3 missing-sha256 skip-and-success"
else
  bad "I3 missing-sha256 skip-and-success" "rc=$rc output:$(head -5 "$sbx3/i3.out")"
fi
rm -rf "$sbx3"

echo ""
echo "=========================================="
echo "PASS=$pass  FAIL=$fail"
[ "$fail" -eq 0 ]
