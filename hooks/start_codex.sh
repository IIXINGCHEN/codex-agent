#!/bin/bash
# Codex 一键启动器
# 用法: ./start_codex.sh <session-name> <workdir> [codex args...]
#
# 自动完成：
# 1. 创建 tmux session
# 2. 启动 Codex TUI
# 3. 记录 runtime session
# 4. 启动 pane monitor

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/runtime/session_store.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/hooks/pane_state.sh"

SESSION="${1:?Usage: $0 <session-name> <workdir> [codex args...]}"
WORKDIR="${2:?Usage: $0 <session-name> <workdir> [codex args...]}"
shift 2
CODEX_ARGS=("$@")

# 检查 tmux
if ! command -v tmux &>/dev/null; then
    echo "❌ tmux not found"
    exit 1
fi

# 检查 codex
if ! command -v codex &>/dev/null; then
    echo "❌ codex not found"
    exit 1
fi

if ! command -v bash &>/dev/null; then
    echo "❌ bash not found"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "❌ jq not found"
    exit 1
fi

# 检查 workdir
if [ ! -d "$WORKDIR" ]; then
    echo "❌ Directory not found: $WORKDIR"
    exit 1
fi

# 组装 runtime session 元数据
PROJECT_LABEL="${CODEX_AGENT_PROJECT_LABEL:-$(session_store_project_label_from_cwd "$WORKDIR")}"
SESSION_KEY="${CODEX_AGENT_SESSION_KEY:-$(session_store_slugify "$SESSION")}"
OPENCLAW_SESSION_ID="${CODEX_AGENT_OPENCLAW_SESSION_ID:-$(session_store_openclaw_session_id "$SESSION_KEY")}"
CHAT_ID="${CODEX_AGENT_CHAT_ID:-}"
CHANNEL="${CODEX_AGENT_CHANNEL:-telegram}"
AGENT_NAME="${CODEX_AGENT_NAME:-main}"
AUTO_TRUST="${CODEX_AGENT_AUTO_TRUST:-0}"
STARTED_AT="$(session_store_now_iso)"
MONITOR_LOG="$(session_store_monitor_log_path "$SESSION_KEY")"
NOTIFY_LOG="$(session_store_notify_log_path "$SESSION_KEY")"
MONITOR_PID_FILE="$(session_store_monitor_pid_path "$SESSION_KEY")"

# 杀掉同名旧 session
tmux kill-session -t "$SESSION" 2>/dev/null || true
pkill -f "pane_monitor.sh $SESSION" 2>/dev/null || true

# 构建 codex 命令
if [ "${#CODEX_ARGS[@]}" -eq 0 ]; then
    CODEX_ARGS=(--full-auto)
fi
case " ${CODEX_ARGS[*]} " in
    *" --no-alt-screen "*) ;;
    *) CODEX_ARGS=(--no-alt-screen "${CODEX_ARGS[@]}") ;;
esac

shell_escape() {
    printf '%q' "$1"
}

build_codex_command() {
    local cmd=""
    local arg

    cmd+="OPENCLAW_CODEX_RUNTIME_DIR=$(shell_escape "$(session_store_runtime_dir)") "
    cmd+="CODEX_AGENT_SESSION_KEY=$(shell_escape "$SESSION_KEY") "
    cmd+="CODEX_AGENT_OPENCLAW_SESSION_ID=$(shell_escape "$OPENCLAW_SESSION_ID") "
    cmd+="CODEX_AGENT_CHAT_ID=$(shell_escape "$CHAT_ID") "
    cmd+="CODEX_AGENT_CHANNEL=$(shell_escape "$CHANNEL") "
    cmd+="CODEX_AGENT_NAME=$(shell_escape "$AGENT_NAME") "
    cmd+="CODEX_AGENT_AUTO_TRUST=$(shell_escape "$AUTO_TRUST") "
    cmd+="codex"
    for arg in "${CODEX_ARGS[@]}"; do
        cmd+=" $(shell_escape "$arg")"
    done
    printf '%s\n' "$cmd"
}

CODEX_CMD="$(build_codex_command)"
BASH_BIN="$(command -v bash)"

build_tmux_launch_command() {
    local inner_cmd=""

    inner_cmd+="$CODEX_CMD"
    inner_cmd+="; codex_exit=\$?; "
    inner_cmd+="printf '\\n[Codex exited with status %s]\\n' \"\$codex_exit\"; "
    inner_cmd+="exec $(shell_escape "$BASH_BIN") --noprofile --norc"

    printf 'exec %s --noprofile --norc -lc %s\n' \
        "$(shell_escape "$BASH_BIN")" \
        "$(shell_escape "$inner_cmd")"
}

TMUX_LAUNCH_CMD="$(build_tmux_launch_command)"

SESSION_JSON="$(jq -n \
    --arg session_key "$SESSION_KEY" \
    --arg project_label "$PROJECT_LABEL" \
    --arg cwd "$WORKDIR" \
    --arg tmux_session "$SESSION" \
    --arg openclaw_session_id "$OPENCLAW_SESSION_ID" \
    --arg chat_id "$CHAT_ID" \
    --arg channel "$CHANNEL" \
    --arg agent_name "$AGENT_NAME" \
    --arg started_at "$STARTED_AT" \
    --arg monitor_log "$MONITOR_LOG" \
    --arg notify_log "$NOTIFY_LOG" \
    --arg codex_args "${CODEX_ARGS[*]}" \
    --arg auto_trust "$AUTO_TRUST" \
    '{
        session_key: $session_key,
        project_label: $project_label,
        cwd: $cwd,
        tmux_session: $tmux_session,
        launch_mode: "interactive",
        controller: "openclaw",
        status: "starting",
        managed_by: "openclaw",
        attached_clients: 0,
        tmux_exists: true,
        codex_running: false,
        chat_id: $chat_id,
        channel: $channel,
        agent_name: $agent_name,
        openclaw_session_id: $openclaw_session_id,
        codex_thread_id: "",
        last_summary: "",
        last_event: "launching",
        last_activity_at: $started_at,
        started_at: $started_at,
        monitor_log: $monitor_log,
        notify_log: $notify_log,
        codex_args: $codex_args,
        auto_trust: ($auto_trust == "1")
    }')"
session_store_write_json "$SESSION_KEY" "$SESSION_JSON"

# 1. 创建 tmux session + 直接启动 Codex
#
# 通过干净的 bash bootstrap 启动，避免用户交互 shell 的 rc / conda init
# 在 Codex 启动前先把 pane 卡死。
if ! tmux new-session -d -s "$SESSION" -c "$WORKDIR" "$TMUX_LAUNCH_CMD"; then
    echo "❌ Failed to create tmux session: $SESSION"
    exit 1
fi

# 等待 Codex 启动（检查 tmux 会话是否还活着）
sleep 2
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "❌ tmux session died immediately, Codex may have failed to start"
    session_store_merge "$SESSION_KEY" "$(jq -n --arg now "$(session_store_now_iso)" '{status: "stopped", last_event: "launch_failed", last_activity_at: $now}')" >/dev/null || true
    exit 1
fi

# 2. 启动 pane monitor（所有模式都启动，启动阻塞和审批都由它兜底）
session_store_ensure_dirs
nohup env CODEX_AGENT_AUTO_TRUST="$AUTO_TRUST" bash "$ROOT_DIR/hooks/pane_monitor.sh" "$SESSION" "$SESSION_KEY" > /dev/null 2>&1 &
echo $! > "$MONITOR_PID_FILE"
chmod 600 "$MONITOR_PID_FILE" 2>/dev/null || true
session_store_merge "$SESSION_KEY" "$(jq -n \
    --arg monitor_pid "$!" \
    --arg monitor_pid_file "$MONITOR_PID_FILE" \
    --arg now "$(session_store_now_iso)" \
    '{status: "running", monitor_pid: ($monitor_pid|tonumber), monitor_pid_file: $monitor_pid_file, last_event: "monitor_started", last_activity_at: $now}')" >/dev/null

pane_output_has_launch_error() {
    local output="${1:-}"

    printf '%s' "$output" | grep -Eq 'command not found|Traceback \(most recent call last\)|IndexError:|No such file or directory|Permission denied'
}

handle_startup_blockers() {
    local output=""
    local state=""
    local current_command=""
    local i

    for i in $(seq 1 8); do
        output="$(tmux capture-pane -t "$SESSION" -p -S -120 2>/dev/null || true)"
        state="$(pane_state_classify "$output")"
        current_command="$(session_store_tmux_current_command "$SESSION" 2>/dev/null || true)"

        case "$state" in
            startup_update)
                tmux send-keys -t "$SESSION" Down Down Enter
                session_store_merge "$SESSION_KEY" "$(jq -n \
                    --arg now "$(session_store_now_iso)" \
                    '{last_event: "startup_update_skipped", last_activity_at: $now}')" >/dev/null || true
                sleep 2
                ;;
            startup_trust)
                if [ "$AUTO_TRUST" = "1" ]; then
                    tmux send-keys -t "$SESSION" Enter
                    session_store_merge "$SESSION_KEY" "$(jq -n \
                        --arg now "$(session_store_now_iso)" \
                        '{last_event: "startup_trust_auto_confirmed", last_activity_at: $now}')" >/dev/null || true
                    sleep 2
                    continue
                fi
                session_store_merge "$SESSION_KEY" "$(jq -n \
                    --arg now "$(session_store_now_iso)" \
                    '{last_event: "startup_waiting_trust", last_activity_at: $now}')" >/dev/null || true
                echo "⚠️ Codex is waiting for directory trust confirmation."
                echo "   approve: tmux send-keys -t $SESSION Enter"
                echo "   quit:    tmux send-keys -t $SESSION Down Enter"
                return 0
                ;;
        esac

        if [ "$current_command" = "codex" ]; then
            return 0
        fi

        if pane_output_has_launch_error "$output"; then
            session_store_merge "$SESSION_KEY" "$(jq -n \
                --arg now "$(session_store_now_iso)" \
                '{status: "stopped", last_event: "launch_failed", last_activity_at: $now}')" >/dev/null || true
            echo "❌ Codex failed before the TUI became ready"
            echo "   inspect: tmux capture-pane -t $SESSION -p -S -200"
            return 1
        fi

        sleep 1
    done
}

if ! handle_startup_blockers; then
    if [ -f "$MONITOR_PID_FILE" ]; then
        kill "$(cat "$MONITOR_PID_FILE")" 2>/dev/null || true
        rm -f "$MONITOR_PID_FILE"
    fi
    exit 1
fi

echo "✅ Codex started"
echo "   session:  $SESSION"
echo "   key:      $SESSION_KEY"
echo "   workdir:  $WORKDIR"
echo "   mode:     ${CODEX_ARGS[*]}"
echo "   monitor:  PID $(cat "$MONITOR_PID_FILE")"
echo "   oc:       $OPENCLAW_SESSION_ID"
echo ""
echo "📎 tmux attach -t $SESSION    # 直接查看"
echo "🔪 ./stop_codex.sh $SESSION   # 一键清理"
