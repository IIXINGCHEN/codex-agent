# Standard task workflow

## 目标

让 OpenClaw 以当前版本的 Codex 和本仓库 runtime 层稳定完成任务。

## Step 1. 先分流

### 用交互式 tmux runtime

适合：

- 长任务
- 需要中途审批
- 需要人工随时 `tmux attach`
- 需要保留完整 TUI 上下文

入口：

```bash
bash hooks/start_codex.sh <session-name> <workdir> [codex args...]
```

### 用非交互式 exec runtime

适合：

- 一次性任务
- CI / cron / report
- 不需要人工接管

入口：

```bash
bash hooks/run_codex.sh <workdir> [codex exec args...]
```

### 用 `codex review`

适合：

- code review
- PR 风险检查
- 未提交改动检查

## Step 2. 启动前确认

- 工作目录存在
- `codex`、`openclaw`、`tmux`、`jq` 可用
- 必要时先确认目录 trust 配置
- 若任务依赖最新事实，先要求 Codex 搜索官方来源

## Step 3. 启动

交互式示例：

```bash
bash hooks/start_codex.sh codex-agent-demo /absolute/workdir --full-auto
```

非交互式示例：

```bash
bash hooks/run_codex.sh /absolute/workdir --full-auto "Summarize the repository state."
```

## Step 4. 读状态，不要盲猜

```bash
bash runtime/list_sessions.sh
bash runtime/session_status.sh <selector>
```

优先关注这些字段：

- `status`
- `launch_mode`
- `last_event`
- `openclaw_session_id`
- `monitor_log`
- `notify_log`

## Step 5. 处理三类阻塞

### 1. update prompt

当前 monitor 已能自动跳过。

### 2. trust prompt

如果没开自动信任：

```bash
tmux send-keys -t <session> Enter
```

如果不信任：

```bash
tmux send-keys -t <session> Down Enter
```

### 3. approval prompt

先看 monitor 报告的命令，再决定是否批准。不要仅因为“以前文档说 full-auto 就不会弹审批”而忽略它。

## Step 6. 检查结果

交互式：

```bash
tmux capture-pane -t <session> -p -S -200
```

非交互式：

- 看 `run_log`
- 看 `last_message_file`
- 看 runtime session JSON

## Step 7. 验证

至少做一项：

- 运行测试
- 运行 lint
- 最小 smoke test
- 人工核对关键输出

## Step 8. 收尾

交互式任务完成后：

```bash
bash hooks/stop_codex.sh <selector>
```

如果要保留现场供人工后续接管，可以先不 stop，只通过 `runtime/session_status.sh` 标记和汇报当前状态。
