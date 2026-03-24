# Codex CLI reference snapshot

来源：

- 本机 `codex --help`
- 本机 `codex exec --help`
- 本机 `codex review --help`
- 本机 `codex resume --help`
- 本机 `codex fork --help`
- [Codex CLI reference](https://developers.openai.com/codex/cli/reference)

校验日期：`2026-03-24`

## 顶层命令

| 命令 | 用途 |
|------|------|
| `codex` | 启动交互式 CLI |
| `codex exec` | 非交互式执行 |
| `codex review` | 非交互式代码审查 |
| `codex resume` | 恢复交互式会话 |
| `codex fork` | 分叉交互式会话 |
| `codex mcp` | 管理 MCP server |
| `codex features` | 查看/修改 feature flags |
| `codex sandbox` | 在 Codex 沙盒策略下执行命令 |
| `codex app` | 启动桌面应用 |

## 交互式常用参数

| 参数 | 说明 |
|------|------|
| `-m, --model <MODEL>` | 指定模型 |
| `-c, --config <key=value>` | 覆盖配置 |
| `-C, --cd <DIR>` | 指定工作目录 |
| `-s, --sandbox <MODE>` | `read-only` / `workspace-write` / `danger-full-access` |
| `-a, --ask-for-approval <POLICY>` | `untrusted` / `on-request` / `never` |
| `--full-auto` | 低摩擦自动执行预设 |
| `--search` | 开启 live web search |
| `--add-dir <DIR>` | 额外可写目录 |
| `--no-alt-screen` | 禁用备用屏幕，tmux 友好 |

## `codex exec`

最关键参数：

| 参数 | 说明 |
|------|------|
| `--full-auto` | 自动执行预设 |
| `-C, --cd <DIR>` | 指定工作目录 |
| `-o, --output-last-message <FILE>` | 输出最后一条消息到文件 |
| `--json` | JSONL 事件流 |
| `--ephemeral` | 不落地持久化 session |
| `--output-schema <FILE>` | 约束最终输出结构 |
| `--skip-git-repo-check` | 允许在非 git 目录运行 |

示例：

```bash
codex exec --full-auto -C /path/to/repo -o /tmp/last.txt "Fix the failing test"
```

## `codex review`

| 参数 | 说明 |
|------|------|
| `--uncommitted` | 审查未提交改动 |
| `--base <BRANCH>` | 基于指定分支审查 |
| `--commit <SHA>` | 审查指定提交 |
| `--title <TITLE>` | 为结果加标题 |

## `codex resume`

| 参数 | 说明 |
|------|------|
| `--last` | 恢复最近一次会话 |
| `--all` | 不限制当前工作目录 |
| `[SESSION_ID]` | 指定会话 ID |

## `codex fork`

| 参数 | 说明 |
|------|------|
| `--last` | 分叉最近一次会话 |
| `--all` | 不限制当前工作目录 |
| `[SESSION_ID]` | 指定会话 ID |

## `codex features`

常用：

```bash
codex features list
codex features enable unified_exec
codex features disable shell_snapshot
```

## `codex mcp`

常用：

```bash
codex mcp list
codex mcp get <name> --json
codex mcp add <name> -- <command...>
codex mcp add <name> --url <https-url>
```

## 当前最相关的配置键

```toml
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
web_search = "live"
personality = "friendly"
notify = ["python3", "/absolute/path/to/hooks/on_complete.py"]

[features]
unified_exec = true
shell_snapshot = true
shell_tool = true
undo = true
multi_agent = true
js_repl = true
```

## 当前不应继续宣称的旧内容

- 不要把 `gpt-5.2` 写成默认模型
- 不要再把 `steer` 写成可用 flag
- 不要再把 `collaboration_modes` 写成当前 feature
- 不要再用 `web_search_cached` 作为推荐配置入口
