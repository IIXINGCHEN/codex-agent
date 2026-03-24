# Codex Agent 安装指南

## 1. 前提条件

确保下面这些命令都能跑：

```bash
codex --version
openclaw --version
tmux -V
jq --version
python3 --version
```

推荐最低校验基线：

- Codex：`0.116.0-alpha.10` 或更新
- OpenClaw：`2026.3.11` 或更新

## 2. 安装 skill 到工作区

当前这台机器上，`openclaw skills` 还没有暴露原生安装子命令，所以先用工作区安装法：

```bash
mkdir -p ~/.openclaw/workspace/skills
cd ~/.openclaw/workspace/skills
git clone https://github.com/dztabel-happy/codex-agent.git
```

校验：

```bash
test -f ~/.openclaw/workspace/skills/codex-agent/SKILL.md
openclaw skills list | grep -i codex-agent || true
openclaw skills check || true
```

如果你已经把仓库放在别处，也可以直接软链或复制到 `~/.openclaw/workspace/skills/codex-agent`。

## 3. 配置 Codex notify hook

编辑 `~/.codex/config.toml`，加入：

```toml
notify = ["python3", "/Users/<you>/.openclaw/workspace/skills/codex-agent/hooks/on_complete.py"]
```

如果你已经有 `notify`，把这个脚本追加进去或改成你自己的绝对路径。

Codex 官方配置参考把 `notify` 定义为“接收 Codex JSON payload 的命令数组”，这正是本项目完成通知的入口。

## 4. 配置环境变量

推荐放进 `~/.zshrc` 或 `~/.bashrc`：

```bash
export CODEX_AGENT_CHAT_ID="your-chat-id"
export CODEX_AGENT_CHANNEL="telegram"
export CODEX_AGENT_NAME="main"
```

可选项：

```bash
export CODEX_AGENT_AUTO_TRUST="1"
```

`CODEX_AGENT_AUTO_TRUST=1` 只适用于你明确已经把目标目录当作可信目录的场景。否则保留默认 `0`，由监控器提示你手动确认。

## 5. 调整 OpenClaw session reset

这一项现在不要再按“每天凌晨 4 点重置”理解。

当前 OpenClaw 官方配置文档和 docs 搜索结果都表明，session reset 的核心是 `session.reset.mode` 和 `idleMinutes`；当前文档默认空闲过期是 60 分钟。对于长任务，这通常太短。

建议至少改到 24 小时，长任务较多的话改到 7 天：

```json
{
  "session": {
    "reset": {
      "mode": "idle",
      "idleMinutes": 10080
    }
  }
}
```

配置文件通常是：

```bash
openclaw config file
```

改完后校验：

```bash
openclaw config validate
```

如果你有运行中的 gateway，再按你的部署方式重启它。

## 6. 设置脚本权限

```bash
cd ~/.openclaw/workspace/skills/codex-agent
chmod +x hooks/*.sh runtime/*.sh tests/regression.sh
```

`on_complete.py` 不要求可执行位，但设上也无妨：

```bash
chmod +x hooks/on_complete.py
```

## 7. 运行回归测试

```bash
cd ~/.openclaw/workspace/skills/codex-agent
bash tests/regression.sh
```

这会验证至少这些关键点：

- 私有日志权限
- OpenClaw 唤醒使用显式 `--session-id`
- pane 状态识别（update / trust / approval）
- `start_codex.sh` 会登记 runtime session 与 monitor PID
- `on_complete.py` 会脱敏摘要并保留显式路由

## 8. 做一次真实 smoke test

### 交互式

```bash
cd ~/.openclaw/workspace/skills/codex-agent
bash hooks/start_codex.sh codex-agent-smoke /Users/<you>/project --full-auto
```

查看状态：

```bash
bash runtime/list_sessions.sh
bash runtime/session_status.sh codex-agent-smoke
```

结束：

```bash
bash hooks/stop_codex.sh codex-agent-smoke
```

### 一次性执行

```bash
bash hooks/run_codex.sh /Users/<you>/project --full-auto "Reply with exactly: SMOKE_OK"
```

## 9. 常见问题

### `start_codex.sh` 说启动成功，但 tmux 里还卡着

先看：

```bash
bash runtime/session_status.sh <session>
tmux attach -t <session>
```

当前仓库已经自动处理 Codex 的更新提示，并会识别 trust prompt；如果目录不可信且没开 `CODEX_AGENT_AUTO_TRUST=1`，状态里会显示等待 trust。

当前版本还会用干净 shell bootstrap Codex，所以如果这里仍然失败，优先怀疑 Codex 本体、目录 trust、审批等待或真实运行错误，而不是你的交互 shell rc / conda init 抢先执行。

### 没收到通知

先检查：

```bash
grep notify ~/.codex/config.toml
```

再手动验证消息通道：

```bash
openclaw message send --channel telegram --target "$CODEX_AGENT_CHAT_ID" --message "codex-agent test"
```

### OpenClaw 被唤醒了，但上下文不对

先看会话登记是否稳定：

```bash
bash runtime/session_status.sh <session>
```

确认里面的 `openclaw_session_id` 是固定值，并且 OpenClaw idle reset 没设置得太短。

### `openclaw skills install` 不存在

这不是你配置错了，而是当前本机 CLI 和最新文档存在版本差异。这个仓库现在默认采用“工作区安装 + `openclaw skills list/check` 校验”的方式。
