# Codex config schema notes

来源：

- 本机 `~/.codex/config.toml`
- [Codex config reference](https://developers.openai.com/codex/config-reference)

校验日期：`2026-03-24`

这份文件不追求把整个 schema 原样抄一遍，只保留对 `codex-agent` 最有影响的字段。

## 当前最关键的顶层字段

| Key | 类型 | 当前关注点 |
|-----|------|-----------|
| `model` | `string` | 当前本机默认是 `gpt-5.4` |
| `model_provider` | `string` | 当前本机是 `custom` |
| `model_reasoning_effort` | `minimal | low | medium | high | xhigh` | 当前本机默认 `xhigh` |
| `model_reasoning_summary` | `auto | concise | detailed | none` | 仅在需要推理摘要时调整 |
| `model_verbosity` | `low | medium | high` | GPT-5 系列可用 |
| `review_model` | `string` | 可为 `/review` 单独指定模型 |
| `plan_mode_reasoning_effort` | `none | minimal | low | medium | high | xhigh` | 计划模式专用 |
| `web_search` | `disabled | cached | live` | 当前本机默认 `live` |
| `personality` | `none | friendly | pragmatic` | 当前本机默认 `friendly` |
| `notify` | `array<string>` | 本项目依赖它触发 [`hooks/on_complete.py`](/Users/abel/project/codex-agent/hooks/on_complete.py) |
| `project_root_markers` | `array<string>` | 项目根识别 |
| `project_doc_fallback_filenames` | `array<string>` | `AGENTS.md` 缺失时的回退名 |
| `tool_output_token_limit` | `number` | 工具输出保留上限 |

## Provider 相关

```toml
[model_providers.<id>]
name = "custom"
base_url = "http://127.0.0.1:23000/v1"
wire_api = "responses"
requires_openai_auth = true
```

官方文档当前明确：

- `wire_api` 现在只支持 `responses`
- `env_key` / `env_http_headers` / `http_headers` / `query_params` 都仍是合法配置项
- `experimental_bearer_token` 仍存在，但官方不建议优先使用

## 审批与沙盒

| Key | 类型 | 说明 |
|-----|------|------|
| `sandbox_mode` | `read-only | workspace-write | danger-full-access` | CLI 与 config 共用 |
| `approval_policy` | `untrusted | on-request | never | reject` | CLI `-a/--ask-for-approval` 的持久化版本 |
| `sandbox_workspace_write.network_access` | `boolean` | `workspace-write` 时是否允许网络 |
| `sandbox_workspace_write.writable_roots` | `array<string>` | 额外可写目录 |

## 项目信任

```toml
[projects."/absolute/path"]
trust_level = "trusted"
```

这会直接影响 Codex 是否跳过目录 trust prompt，以及是否加载项目级 `.codex/` 层。

## notify

官方文档定义：

- `notify` 是命令数组
- Codex 会向这个命令传一个 JSON payload
- 本项目用它接收 `agent-turn-complete`

最小示例：

```toml
notify = ["python3", "/absolute/path/to/hooks/on_complete.py"]
```

## TUI

| Key | 类型 | 说明 |
|-----|------|------|
| `tui.notifications` | `boolean | array<string>` | TUI 通知 |
| `tui.notification_method` | `auto | osc9 | bel` | 通知方式 |
| `tui.alternate_screen` | `auto | always | never` | 与 `--no-alt-screen` 对应 |
| `tui.theme` | `string` | 主题 |
| `tui.status_line` | `array<string> | null` | 状态栏 |

## MCP servers

```toml
[mcp_servers.<name>]
type = "stdio"
command = "npx"
args = ["package@latest"]

[mcp_servers.<name>.env]
API_KEY = "..."
```

本项目只依赖“Codex 能读到这些服务并正常启动”，不依赖某个特定 MCP 必须存在。

## Skills

```toml
[skills]
config = [
  { enabled = true, path = "/absolute/path/to/SKILL.md" }
]
```

## Agents / subagents

```toml
[agents]
max_depth = 3
max_threads = 5

[agents.<role-name>]
description = "..."
config_file = "/absolute/path/to/role.toml"
```

注意：

- 官方文档对外叙述更常用 “Subagents”
- 本机 feature flag 仍叫 `multi_agent`

## 仍然要特别注意的变化

- `tools.web_search` 已是旧入口，优先用顶层 `web_search`
- `experimental_instructions_file` 已改名为 `model_instructions_file`
- `sqlite_home` 仍在 schema 中，但本机 `sqlite` feature 已被标成 `removed`

## 与本项目最相关的推荐配置示例

```toml
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
web_search = "live"
personality = "friendly"
notify = ["python3", "/absolute/path/to/codex-agent/hooks/on_complete.py"]

[features]
unified_exec = true
shell_snapshot = true
shell_tool = true
undo = true
multi_agent = true
js_repl = true
```
