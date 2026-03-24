# Local capabilities snapshot

校验日期：`2026-03-24`

## Codex

- 版本：`codex-cli 0.116.0-alpha.10`
- 默认模型：`gpt-5.4`
- 默认推理强度：`xhigh`
- 默认网页搜索：`live`
- 默认 personality：`friendly`

当前本机确认可用的核心子命令：

- `codex`
- `codex exec`
- `codex review`
- `codex resume`
- `codex fork`
- `codex mcp`
- `codex features`
- `codex sandbox`
- `codex app`

## OpenClaw

- 版本：`2026.3.11`
- 当前本机确认可用：
  - `openclaw agent --session-id`
  - `openclaw message send`
  - `openclaw config file/get/set/unset/validate`
  - `openclaw onboard`
  - `openclaw docs`
  - `openclaw skills list/info/check`

### 本机与官方文档的差异

官方 docs 已经描述更完整的 skills / ClawHub 体系，但本机 CLI 目前还没有暴露 `openclaw skills install` 这类安装子命令。

因此本项目当前采取的原则是：

- 设计理念参考官方最新文档
- 安装步骤以本机 CLI 真正能执行的路径为准

## 本机 MCP 能力

来自 `codex mcp list` 的已启用服务：

| 名称 | 类型/入口 | 用途 |
|------|-----------|------|
| `ace-tool` | stdio | 代码上下文搜索 |
| `chrome-devtools` | stdio | DevTools 浏览器控制 |
| `chrome-mcp-server` | stdio | 浏览器桥接与页面操作 |
| `exa` | stdio | 语义搜索 / 页面抓取 / 研究 |
| `grok-search` | stdio | 实时搜索 / 抓取 |
| `playwright` | stdio | 浏览器自动化 |
| `scrape-do` | stdio | 强抓取 / 反爬 / 渲染页 |

注意：

- 文档里只记录“服务名与能力”，不记录本机任何密钥。
- 能不能用，以 `codex mcp list` 的启用状态和实际调用结果为准。

## codex-agent 自己新增的运行时能力

### Interactive runtime

- [`hooks/start_codex.sh`](/Users/abel/project/codex-agent/hooks/start_codex.sh)
- [`hooks/pane_monitor.sh`](/Users/abel/project/codex-agent/hooks/pane_monitor.sh)
- [`hooks/stop_codex.sh`](/Users/abel/project/codex-agent/hooks/stop_codex.sh)

### Non-interactive runtime

- [`hooks/run_codex.sh`](/Users/abel/project/codex-agent/hooks/run_codex.sh)

### Session registry

- [`runtime/session_store.sh`](/Users/abel/project/codex-agent/runtime/session_store.sh)
- [`runtime/list_sessions.sh`](/Users/abel/project/codex-agent/runtime/list_sessions.sh)
- [`runtime/session_status.sh`](/Users/abel/project/codex-agent/runtime/session_status.sh)

### Current runtime guarantees

- 每个受管会话有稳定 `session_key`
- 每个受管会话有稳定 `openclaw_session_id`
- 日志和 PID 文件进入私有 runtime 目录
- `on_complete.py` 外发摘要默认脱敏
- monitor 能识别 update / trust / approval 三类关键阻塞

## 当前推荐模型策略

参考依据：

- 本机默认配置
- [Codex CLI features](https://developers.openai.com/codex/cli/features)
- [Using GPT-5.4](https://developers.openai.com/api/docs/guides/latest-model)

建议：

| 场景 | 推荐 |
|------|------|
| 默认编码 / 调试 / 重构 | `gpt-5.4` |
| 简单低风险修改 | `gpt-5.4` + `low`/`medium` reasoning |
| 架构设计 / 高风险迁移 / 深度排障 | `gpt-5.4` + `high`/`xhigh` reasoning |
| 需要显式并行拆分任务 | 明确在 prompt 中要求 subagents / multiple agents |

不要再把 `gpt-5.2` 写成默认。
