# Codex feature flags snapshot

校验来源：

- `codex --version`
- `codex features list`
- [Codex Feature Maturity](https://developers.openai.com/codex/feature-maturity)

校验日期：`2026-03-24`
本机版本：`codex-cli 0.116.0-alpha.10`

## 结论先行

- 不要再把 `steer`、`collaboration_modes`、`sqlite` 当作当前可用功能；本机 CLI 已标记为 `removed`。
- `multi_agent` 现在是 `stable = true`，但官方文档页面更常用的对外词是 “Subagents”。
- `js_repl` 仍是 `experimental = true`，可以用，但不应当写成稳定能力。
- `web_search_cached` / `web_search_request` 已处于 `deprecated`，优先使用顶层 `web_search` 配置。

## 当前值得关注的 flags

| Flag | Maturity | Enabled | 说明 |
|------|----------|---------|------|
| `unified_exec` | stable | `true` | 当前 CLI 的统一执行链路，建议保持开启 |
| `shell_snapshot` | stable | `true` | shell 环境快照 |
| `shell_tool` | stable | `true` | shell 工具能力 |
| `undo` | stable | `true` | 撤销能力 |
| `personality` | stable | `true` | 人格化输出支持 |
| `fast_mode` | stable | `true` | 快速服务层支持 |
| `skill_mcp_dependency_install` | stable | `true` | skill/MCP 依赖安装支持 |
| `multi_agent` | stable | `true` | 本机 flag 名仍是 `multi_agent`，官方文档对外多写作 subagents |
| `js_repl` | experimental | `true` | 持久化 JS REPL，可用但仍属实验性 |
| `apply_patch_freeform` | under development | `true` | 自由格式 patch，在当前环境已启用 |

## 当前明确不该再依赖的 flags

| Flag | CLI 状态 | 处理建议 |
|------|----------|----------|
| `collaboration_modes` | removed | 不再作为能力前提 |
| `steer` | removed | 不再作为能力前提 |
| `sqlite` | removed | 不再宣称“可直接操作 sqlite feature” |
| `search_tool` | removed | 不再用旧 feature 名描述搜索 |
| `request_rule` | removed | 不再建议用户开启 |

## 当前仍在开发但默认关闭的 flags

这些不应写进默认工作流，除非先确认本机版本确实需要：

| Flag | Maturity | Enabled |
|------|----------|---------|
| `child_agents_md` | under development | `false` |
| `code_mode` | under development | `false` |
| `exec_permission_approvals` | under development | `false` |
| `tool_suggest` | under development | `false` |
| `runtime_metrics` | under development | `false` |

## 已废弃的搜索相关 flag

| Flag | 状态 | 正确替代 |
|------|------|----------|
| `web_search_cached` | deprecated | `web_search = "cached"` |
| `web_search_request` | deprecated | `web_search = "live"` / `--search` |

## 对文档写作的影响

- 讨论 feature 成熟度时，使用官方页面的语义：
  - `Under development`
  - `Experimental`
  - `Beta`
  - `Stable`
- 讨论“这台机器现在到底开没开”时，以 `codex features list` 为准。
- 任何新文档如果仍出现 `steer`、`collaboration_modes`、`sqlite` 作为建议开启项，都应视为过时内容。
