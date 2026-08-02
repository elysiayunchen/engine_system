# progress — [Task ID: T-088] CI 健康检查与分发一致性

> Last updated: 2026-08-02 | owner: a-codex

## §1 已确认问题

- CI 的 Linux/Windows check 使用 shallow checkout，历史 evidence provenance 对象不可见。
- install.sh、install.ps1、plugin/manifest.json 的分发路径集合不一致。
- task-card C4 fixture 未生成 T-077 引入的 GATE.json。
- SessionStart shell hook 实际输出超过 N1 的 400 行预算。

## §2 当前进度

- [x] 创建 T-088 并覆盖本次写集。
- [x] 完成补丁并通过本地回归：task-card 29/29、manifest 86/86、hook 400 行、check.ps1 PASS。
- [ ] 推送后确认 GitHub Actions 全绿。

## §3 下一步

运行 manifest 集合校验、task-card 回归、hook 行数检查，再提交并观察远端 CI。
