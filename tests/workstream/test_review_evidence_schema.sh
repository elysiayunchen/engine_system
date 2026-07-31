#!/usr/bin/env bash
# Test: review evidence schema(T-069 AC-10,12,13,14, v6.20.0)
set -euo pipefail
echo "[test_review_evidence_schema.sh] T-069 AC-10,12,13,14 evidence schema"
PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

PIPELINE="$PWD/engine/scripts/engine-review-pipeline.sh"
REPO="$PWD"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# fake-bin:semgrep 输出 1 条 ERROR+HIGH(→critical)+1 条 WARNING(→high)+1 条 INFO(→medium)
mkdir -p "$TMPDIR/fake-bin"
cat > "$TMPDIR/fake-bin/semgrep" <<'MOCK'
#!/usr/bin/env bash
# 真实 semgrep 对 --version 返回干净版本号;scan 调用返回 findings JSON
if [ "${1:-}" = "--version" ]; then
  echo "semgrep 1.50.0"
  exit 0
fi
cat <<JSON
{"results":[
  {"check_id":"js.eval","path":"bad.js","start":{"line":1,"col":1},"extra":{"severity":"ERROR","message":"eval() dangerous","metadata":{"impact":"ERROR"},"confidence":"HIGH"}},
  {"check_id":"js.warn","path":"bad.js","start":{"line":2,"col":1},"extra":{"severity":"WARNING","message":"warning issue","metadata":{"impact":"WARNING"},"confidence":"HIGH"}},
  {"check_id":"js.info","path":"bad.js","start":{"line":3,"col":1},"extra":{"severity":"INFO","message":"info issue","metadata":{"impact":"INFO"},"confidence":"HIGH"}}
]}
JSON
MOCK
# fake eslint:--version 返回版本号;1 条 severity=2 (error → high)
cat > "$TMPDIR/fake-bin/eslint" <<'MOCK'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  echo "v9.8.0"
  exit 0
fi
cat <<JSON
[{"filePath":"bad.js","messages":[{"ruleId":"no-unused-vars","severity":2,"message":"unused","line":10,"column":5}]}]
JSON
MOCK
chmod +x "$TMPDIR/fake-bin/semgrep" "$TMPDIR/fake-bin/eslint"

cd "$TMPDIR"
git init -q; git config user.email "t@t.com"; git config user.name "t"
mkdir -p engine/tasks engine/scripts engine/review/evidence
cp "$REPO/engine/review/config.json" engine/review/config.json
echo "eval('x');" > bad.js
cat > engine/tasks/T-FIX.md <<'EOF'
> status: active
GOAL: fixture
## WRITE-SET
- bad.js
AC: AC-1 pass | verify: true
EOF
git add . && git commit -q -m "T-FIX"

rc=0
PATH="$TMPDIR/fake-bin:$PATH" ENGINE_DIR="$PWD/engine" bash "$PIPELINE" T-FIX >/dev/null 2>&1 || rc=$?
REVIEW="engine/review/evidence/T-FIX/REVIEW.json"
SECURITY="engine/review/evidence/T-FIX/SECURITY.json"
QUALITY="engine/review/evidence/T-FIX/QUALITY.json"

# AC-10 schema 完整性
if [ "$rc" -eq 1 ] \
  && grep -q '"write_provenance"' "$REVIEW" \
  && grep -q '"writer":"engine-review"' "$REVIEW" \
  && grep -q '"pipeline_version":"v6.20.0"' "$REVIEW" \
  && grep -q '"code_fingerprint"' "$REVIEW" \
  && grep -q '"evidence_manifest_sha256"' "$REVIEW" \
  && grep -q '"tool_versions"' "$REVIEW" \
  && grep -q '"tool_detection"' "$REVIEW" \
  && grep -q '"config_layers"' "$REVIEW"; then
  ok "AC-10 schema complete (write_provenance + fingerprint + manifest_sha256 + tool_versions + tool_detection + config_layers)"
else
  bad "AC-10 schema incomplete (rc=$rc)"
fi

# AC-12 finding id 正则 ^<tool>-<rule_id>-<file>:<line>:<col>$
# 注意:file 含 / 等字符,正则放宽为 [^:]+
id_ok=$(python3 -c "
import json,re
with open('$SECURITY') as f: d=json.load(f)
pat=re.compile(r'^semgrep-[^-]+-[^:]+:[0-9]+:[0-9]+$')
for x in d.get('findings',[]):
    if not pat.match(x.get('id','')):
        print('FAIL:'+x.get('id',''))
        break
else:
    print('OK')
")
if [ "$id_ok" = "OK" ]; then ok "AC-12 finding id regex matches"; else bad "AC-12 id regex fail: $id_ok"; fi

# AC-13 严重度映射:ERROR+HIGH → critical, WARNING → high, INFO → medium; eslint 2 → high
sev_check=$(python3 -c "
import json
with open('$SECURITY') as f: s=json.load(f)
with open('$QUALITY') as f: q=json.load(f)
sec_sevs=sorted([x['severity'] for x in s.get('findings',[])])
qual_sevs=sorted([x['severity'] for x in q.get('findings',[])])
expected_sec=sorted(['critical','high','medium'])
expected_qual=sorted(['high'])
print('OK' if sec_sevs==expected_sec and qual_sevs==expected_qual else f'FAIL sec={sec_sevs} qual={qual_sevs}')
")
if [ "$sev_check" = "OK" ]; then ok "AC-13 severity mapping (semgrep ERROR+HIGH=critical, WARNING=high, INFO=medium; eslint 2=high)"; else bad "AC-13 mapping fail: $sev_check"; fi

# AC-14 code_fingerprint 重算 == REVIEW.json
fp_check=$(python3 -c "
import json,subprocess
with open('$REVIEW') as f: r=json.load(f)
fp=r.get('code_fingerprint',{})
ok=True
for fpath,sha in fp.items():
    try:
        actual=subprocess.check_output(['git','rev-parse',f'HEAD:{fpath}'],stderr=subprocess.DEVNULL).decode().strip()
    except: actual=''
    if actual!=sha: ok=False; print(f'FP MISMATCH {fpath}: {sha} vs {actual}'); break
print('OK' if ok else 'FAIL')
")
if [ "$fp_check" = "OK" ]; then ok "AC-14 code_fingerprint matches git rev-parse HEAD:<file>"; else bad "AC-14 fp fail: $fp_check"; fi

# AC-14 evidence_manifest_sha256 重算(含 SECURITY + QUALITY,排除 REVIEW 自身)
manifest_check=$(python3 -c "
import hashlib,json,os
evidence_dir='engine/review/evidence/T-FIX'
with open('engine/review/evidence/T-FIX/REVIEW.json') as f: r=json.load(f)
expected=r.get('evidence_manifest_sha256','')
files=sorted([f for f in os.listdir(evidence_dir) if f.endswith('.json') and f!='REVIEW.json'])
h=hashlib.sha256()
for fname in files:
    with open(os.path.join(evidence_dir,fname),'rb') as fp:
        h.update(fp.read())
actual=h.hexdigest()
print('OK' if actual==expected else f'FAIL expected={expected} actual={actual}')
")
if [ "$manifest_check" = "OK" ]; then ok "AC-14 evidence_manifest_sha256 matches recomputed (SECURITY + QUALITY, excludes REVIEW)"; else bad "AC-14 manifest fail: $manifest_check"; fi

echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
