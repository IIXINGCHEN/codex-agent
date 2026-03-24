# Knowledge changelog

## 2026-03-24

### 版本与默认值更新

- `state/version.txt` 从 `0.104.0` 更新到 `0.116.0-alpha.10`
- 默认模型认知从 `gpt-5.2` 更新为 `gpt-5.4`
- 默认搜索配置认知保持为 `web_search = "live"`（来自本机配置）

### Feature 认知修正

- 明确记录 `collaboration_modes` 已 removed
- 明确记录 `steer` 已 removed
- 明确记录 `sqlite` 已 removed
- 明确记录 `multi_agent` 当前在本机为 stable+enabled

### OpenClaw 认知修正

- 不再使用“每天凌晨 4 点自动 reset”这种旧叙事
- 改为基于 `session.reset.mode` 与 `idleMinutes` 理解 session 生命周期
- 记录官方 docs 与本机 `openclaw skills` 子命令存在版本差异

### 运行时修复写入知识库

- startup update prompt 已纳入监控
- directory trust prompt 已纳入监控
- OpenClaw wake 统一改为显式 `--session-id`
- monitor PID 已迁移到私有 runtime 目录
- 通知摘要已改为脱敏预览

## 2026-02-25

保留为历史记录，但不再作为当前事实来源。
