# Codex Agent

让 OpenClaw 以“受控运行时”的方式操作 Codex CLI，而不是只靠一堆临时 tmux 命令。

## 当前基线

- 校验日期：`2026-03-24`
- 本机 Codex：`codex-cli 0.116.0-alpha.10`
- 本机 OpenClaw：`OpenClaw 2026.3.11`
- 本机默认 Codex 配置：`model = "gpt-5.4"`、`model_reasoning_effort = "xhigh"`、`web_search = "live"`

这次升级的核心目标有两个：

1. 把旧版文档里已经过时的 Codex / OpenClaw 认知清掉。
2. 把运行时做成可追踪、可恢复、可验证，而不是“启动了就全靠运气”。

## 现在它能做什么

- 用 [`hooks/start_codex.sh`](/Users/abel/project/codex-agent/hooks/start_codex.sh) 启动一个受管的交互式 Codex tmux 会话。
- 用 [`hooks/run_codex.sh`](/Users/abel/project/codex-agent/hooks/run_codex.sh) 启动一个受管的 `codex exec` 一次性任务。
- 把每个会话登记到 `~/.openclaw/runtime/codex-agent/` 下，保留 `session_key`、`openclaw_session_id`、日志、输出和状态。
- 用 [`runtime/list_sessions.sh`](/Users/abel/project/codex-agent/runtime/list_sessions.sh) / [`runtime/session_status.sh`](/Users/abel/project/codex-agent/runtime/session_status.sh) 查看会话。
- 交互式启动会先用干净的 `bash --noprofile --norc` bootstrap Codex，避免用户 shell init / conda 异常在 TUI 启动前把 pane 卡死。
- 识别并处理 Codex 启动阶段的新阻塞点：
  - 自更新提示 `Update available! ... Press enter to continue`
  - 目录信任提示 `Do you trust the contents of this directory?`
- 在审批、完成通知和重新唤醒 OpenClaw 时显式传 `--session-id`，避免消息飘到错误上下文。
- 把日志和 monitor PID 都收进私有 runtime 目录，避免继续把敏感数据裸写到 `/tmp`。
- 对 `on_complete.py` 的外发摘要做脱敏和裁剪，避免把完整回复原样发到聊天通道。

## 为什么旧版需要大修

旧仓库里最明显的过时点有这些：

- 版本状态还停在 `0.104.0`，但本机已经是 `0.116.0-alpha.10`。
- 文档仍把 `gpt-5.2` 当默认模型，而本机实际默认已经是 `gpt-5.4`。
- 旧知识库还把 `steer`、`collaboration_modes`、`sqlite` 当可用 feature，但当前 CLI 已把它们标成 `removed`。
- 旧说明把 OpenClaw session reset 描述成“每天凌晨 4 点自动重置”，这和当前官方文档/本机 CLI 的说法不一致。现在应按 `session.reset.mode` 与 `idleMinutes` 来理解，文档默认值是 60 分钟空闲过期。
- 旧 hook 只按“审批提示”匹配 pane 内容，没覆盖 Codex 的新更新提示和 trust 提示，所以会出现“脚本显示启动成功，实际上 UI 卡在启动页”的假成功。

## 架构原则

本项目参考了 `/Users/abel/project/claude-code-agent` 的一些好思路，但没有照搬 Claude 的设计。

保留的思路：

- 稳定 `session_key`
- 稳定 `openclaw_session_id`
- 会话 runtime registry
- 显式状态查询
- wake 去重

没有照搬的部分：

- Claude 专用 hook 生命周期
- Claude 权限回调模型
- Claude 风格的本地/接管双控制面

Codex 这边仍然坚持“Codex 原生命令 + tmux + notify hook + OpenClaw 显式路由”的设计。

## 关键文件

- [`hooks/start_codex.sh`](/Users/abel/project/codex-agent/hooks/start_codex.sh)：交互式会话入口
- [`hooks/run_codex.sh`](/Users/abel/project/codex-agent/hooks/run_codex.sh)：非交互式执行入口
- [`hooks/pane_monitor.sh`](/Users/abel/project/codex-agent/hooks/pane_monitor.sh)：监控 trust / update / approval
- [`hooks/on_complete.py`](/Users/abel/project/codex-agent/hooks/on_complete.py)：Codex `notify` hook
- [`runtime/session_store.sh`](/Users/abel/project/codex-agent/runtime/session_store.sh)：runtime 元数据与选择器解析
- [`runtime/list_sessions.sh`](/Users/abel/project/codex-agent/runtime/list_sessions.sh)：列出受管会话
- [`runtime/session_status.sh`](/Users/abel/project/codex-agent/runtime/session_status.sh)：查看单个会话
- [`tests/regression.sh`](/Users/abel/project/codex-agent/tests/regression.sh)：当前回归测试

## 推荐用法

### 1. 交互式长任务

```bash
bash hooks/start_codex.sh codex-agent-demo /absolute/workdir --full-auto
```

然后用这些命令观察状态：

```bash
bash runtime/list_sessions.sh
bash runtime/session_status.sh codex-agent-demo
tmux attach -t codex-agent-demo
```

结束时：

```bash
bash hooks/stop_codex.sh codex-agent-demo
```

### 2. 一次性自动执行

```bash
bash hooks/run_codex.sh /absolute/workdir --full-auto "Summarize the repository state."
```

这会把最后一条消息写入 runtime outputs，并登记到 session store。

### 3. 用 OpenClaw 驱动

让 OpenClaw 调用本 skill 时，优先让它：

1. 先判断是 `start_codex.sh` 还是 `run_codex.sh`
2. 启动后读取 [`runtime/session_status.sh`](/Users/abel/project/codex-agent/runtime/session_status.sh)
3. 遇到 trust / approval 时通过同一个 `openclaw_session_id` 回到原对话

## 安装入口

安装步骤见 [INSTALL.md](https://github.com/dztabel-happy/codex-agent/blob/main/INSTALL.md)。

本地快速验证最重要的三条命令：

```bash
codex --version
openclaw --version
bash tests/regression.sh
```

## 已知上游差异

这里有一个必须明确写出来的现实差异：

- OpenClaw 官方文档已经有更丰富的 skills 体系和 ClawHub 安装路径。
- 但你这台机器上的 `openclaw skills --help` 目前仍只有 `list` / `info` / `check`。

所以本仓库当前文档采用的策略是：

- 以官方文档理解“未来/标准设计”
- 以本机 CLI 结果决定“今天这台机器到底能跑什么”
- 一旦两者冲突，安装步骤优先写成本机可执行的路径

## 参考依据

- OpenAI Codex CLI features: [developers.openai.com/codex/cli/features](https://developers.openai.com/codex/cli/features)
- OpenAI Codex CLI reference: [developers.openai.com/codex/cli/reference](https://developers.openai.com/codex/cli/reference)
- OpenAI Codex config reference: [developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference)
- OpenAI latest model guide: [developers.openai.com/api/docs/guides/latest-model](https://developers.openai.com/api/docs/guides/latest-model)
- OpenClaw config reference: [docs.openclaw.ai/gateway/configuration-reference](https://docs.openclaw.ai/gateway/configuration-reference)
- OpenClaw `agent` CLI: [docs.openclaw.ai/cli/agent](https://docs.openclaw.ai/cli/agent)
- OpenClaw `skills` CLI: [docs.openclaw.ai/cli/skills](https://docs.openclaw.ai/cli/skills)
- OpenClaw `onboard` CLI: [docs.openclaw.ai/cli/onboard](https://docs.openclaw.ai/cli/onboard)
