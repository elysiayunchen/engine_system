# T-055 Progress

## 2026-07-29 T-055 v6.14.0 done

- AC-1: engine-verify.ps1 L67-74 检测 `C:\Program Files (x86)\Git\bin\bash.exe`(`${env:ProgramFiles(x86)}` 优先 + 硬编码兜底)PASS
- AC-2: engine-verify.ps1 L82-97 通过 `git --exec-path` 反推 bash 路径(3 层 Split-Path + Join-Path bin\bash.exe)PASS
- AC-3: 现有标准路径检测仍工作(Test-Path $gitBash 保留)PASS
- AC-4: diff engine/scripts/engine-verify.ps1 plugin/engine/scripts/engine-verify.ps1 BYTE-IDENTICAL
- AC-5: scripts/check.sh CHECK PASSED
- AC-6: VERSION 6.14.0 + CHANGELOG v6.14.0 段存在

Test: tests/workstream/test_engine_verify_bash_detection.{sh,ps1} 11 pass 0 fail
