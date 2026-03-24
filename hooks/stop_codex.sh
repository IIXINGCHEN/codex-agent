#!/bin/bash
# Codex 一键清理
# 用法: ./stop_codex.sh <session-name|session-key|cwd>

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/runtime/session_store.sh"

SELECTOR="${1:?Usage: $0 <session-name|session-key|cwd>}"
SESSION_KEY="$(session_store_resolve_selector "$SELECTOR" 2>/dev/null || true)"
SESSION="$SELECTOR"
PROCESS_PID=""
LAUNCH_MODE="interactive"

if [ -n "$SESSION_KEY" ] && session_store_exists "$SESSION_KEY"; then
    SESSION_JSON="$(session_store_read "$SESSION_KEY")"
    SESSION="$(printf '%s' "$SESSION_JSON" | jq -r '.tmux_session // "'"$SELECTOR"'"')"
    LAUNCH_MODE="$(printf '%s' "$SESSION_JSON" | jq -r '.launch_mode // "interactive"')"
    PROCESS_PID="$(printf '%s' "$SESSION_JSON" | jq -r '.process_pid // ""')"
fi

MONITOR_PID_FILE=""
if [ -n "$SESSION_KEY" ]; then
    MONITOR_PID_FILE="$(session_store_monitor_pid_path "$SESSION_KEY")"
fi
LEGACY_MONITOR_PID_FILE="/tmp/codex_monitor_${SESSION}.pid"

# 杀 pane monitor
if [ -n "$MONITOR_PID_FILE" ] && [ -f "$MONITOR_PID_FILE" ]; then
    kill "$(cat "$MONITOR_PID_FILE")" 2>/dev/null || true
    rm -f "$MONITOR_PID_FILE"
    echo "✅ Monitor stopped"
elif [ -f "$LEGACY_MONITOR_PID_FILE" ]; then
    kill "$(cat "$LEGACY_MONITOR_PID_FILE")" 2>/dev/null || true
    rm -f "$LEGACY_MONITOR_PID_FILE"
    echo "✅ Monitor stopped (legacy pid path)"
else
    echo "ℹ️ Monitor PID file not found (may have already exited)"
fi
# 兜底：按精确 session 名匹配
pkill -f "pane_monitor\\.sh ${SESSION}$" 2>/dev/null || true

# 杀 tmux session
if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux kill-session -t "$SESSION"
    echo "✅ Session $SESSION killed"
else
    echo "ℹ️ Session $SESSION not found"
fi

if [ "$LAUNCH_MODE" = "print" ] && session_store_pid_exists "$PROCESS_PID"; then
    kill "$PROCESS_PID" 2>/dev/null || true
    echo "✅ Process $PROCESS_PID killed"
fi

if [ -n "$SESSION_KEY" ] && session_store_exists "$SESSION_KEY"; then
    session_store_merge "$SESSION_KEY" "$(jq -n \
        --arg now "$(session_store_now_iso)" \
        '{status: "stopped", process_running: false, codex_running: false, last_event: "manual_stop", last_activity_at: $now}')" >/dev/null || true
fi

# 清理日志（可选，取消注释启用）
# rm -f "/tmp/codex_monitor_${SESSION}.log"
