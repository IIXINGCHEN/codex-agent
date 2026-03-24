#!/bin/bash
# Codex TUI pane 监控器
# 用法: ./pane_monitor.sh <tmux-session-name> [session-key]

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/runtime/session_store.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/hooks/hook_common.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/hooks/pane_state.sh"

SESSION="${1:?Usage: $0 <tmux-session-name> [session-key]}"
SESSION_KEY="${2:-$(session_store_resolve_selector "$SESSION" 2>/dev/null || session_store_slugify "$SESSION")}"
CHECK_INTERVAL=3
LAST_STATE=""
NOTIFIED_APPROVAL=""
NOTIFIED_BLOCKER=""
CAPTURE_LINES=80

LOG_FILE="$(hook_prepare_log_file "pane-monitor-$SESSION_KEY")"

load_session_json() {
    if session_store_exists "$SESSION_KEY"; then
        session_store_refresh_live_state "$SESSION_KEY" >/dev/null 2>&1 || true
        session_store_read "$SESSION_KEY"
        return 0
    fi
    printf '%s\n' '{}'
}

update_session_state() {
    local patch_json="${1:?patch json required}"
    if session_store_exists "$SESSION_KEY"; then
        session_store_merge "$SESSION_KEY" "$patch_json" >/dev/null || true
    fi
}

session_auto_trust() {
    local session_json
    session_json="$(load_session_json)"
    if [ "$(printf '%s' "$session_json" | jq -r '.auto_trust // false')" = "true" ]; then
        printf '1\n'
    else
        printf '0\n'
    fi
}

notify_openclaw() {
    local importance="${1:?importance required}"
    local user_msg="${2:-}"
    local agent_msg="${3:-}"
    local session_json
    local controller
    local chat_id
    local channel
    local agent_name
    local attached_clients

    session_json="$(load_session_json)"
    controller="$(printf '%s' "$session_json" | jq -r '.controller // "openclaw"')"
    chat_id="$(printf '%s' "$session_json" | jq -r '.chat_id // ""')"
    channel="$(printf '%s' "$session_json" | jq -r '.channel // "telegram"')"
    agent_name="$(printf '%s' "$session_json" | jq -r '.agent_name // "main"')"
    attached_clients="$(printf '%s' "$session_json" | jq -r '.attached_clients // 0')"

    if [ "$attached_clients" -eq 0 ]; then
        hook_send_user_message "$LOG_FILE" "$channel" "$chat_id" "$user_msg" || true
    else
        hook_log "$LOG_FILE" "User notify suppressed (attached clients: $attached_clients)"
    fi

    hook_wake_openclaw "$LOG_FILE" "$SESSION_KEY" "$controller" "$agent_name" "$channel" "$agent_msg" || true
}

cleanup() {
    local pid_file
    pid_file="$(session_store_monitor_pid_path "$SESSION_KEY")"
    rm -f "$pid_file"
    update_session_state "$(jq -n --arg now "$(session_store_now_iso)" '{monitor_pid: null, last_activity_at: $now}')"
    hook_log "$LOG_FILE" "Monitor exiting, cleaned up PID file"
}
trap cleanup EXIT

hook_log "$LOG_FILE" "Monitor started for session: $SESSION ($SESSION_KEY)"

while true; do
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        update_session_state "$(jq -n --arg now "$(session_store_now_iso)" '{status: "stopped", last_event: "tmux_session_missing", last_activity_at: $now}')"
        hook_log "$LOG_FILE" "Session $SESSION gone, exiting"
        exit 0
    fi

    OUTPUT="$(tmux capture-pane -t "$SESSION" -p -S -"$CAPTURE_LINES" 2>/dev/null)"
    STATE="$(pane_state_classify "$OUTPUT")"

    case "$STATE" in
        startup_update)
            if [ "$LAST_STATE" != "startup_update" ]; then
                tmux send-keys -t "$SESSION" Down Down Enter
                update_session_state "$(jq -n --arg now "$(session_store_now_iso)" '{last_event: "startup_update_skipped", last_activity_at: $now}')"
                hook_log "$LOG_FILE" "Skipped Codex self-update prompt"
            fi
            LAST_STATE="startup_update"
            ;;

        startup_trust)
            if [ "$(session_auto_trust)" = "1" ] || [ "${CODEX_AGENT_AUTO_TRUST:-0}" = "1" ]; then
                if [ "$LAST_STATE" != "startup_trust_auto" ]; then
                    tmux send-keys -t "$SESSION" Enter
                    update_session_state "$(jq -n --arg now "$(session_store_now_iso)" '{last_event: "startup_trust_auto_confirmed", last_activity_at: $now}')"
                    hook_log "$LOG_FILE" "Auto-confirmed directory trust prompt"
                fi
                LAST_STATE="startup_trust_auto"
                NOTIFIED_BLOCKER=""
                sleep 2
                continue
            fi

            if [ "$NOTIFIED_BLOCKER" != "startup_trust" ]; then
                NOTIFIED_BLOCKER="startup_trust"
                update_session_state "$(jq -n --arg now "$(session_store_now_iso)" '{last_event: "startup_waiting_trust", last_activity_at: $now}')"
                USER_MSG="⏸️ Codex 等待目录信任确认
📁 session: $SESSION
🛡️ 目标目录需要确认 trust 后才能继续。"
                AGENT_MSG="[Codex Monitor] 目录信任确认等待。
session: $SESSION
session_key: $SESSION_KEY
请确认这个目录是否可信。
批准: tmux send-keys -t $SESSION Enter
退出: tmux send-keys -t $SESSION Down Enter"
                notify_openclaw important "$USER_MSG" "$AGENT_MSG"
                hook_log "$LOG_FILE" "Trust prompt detected"
            fi
            LAST_STATE="startup_trust"
            ;;

        approval)
            CMD="$(pane_extract_approval_command "$OUTPUT")"
            APPROVAL_STATE="approval:$CMD"
            if [ "$APPROVAL_STATE" != "$NOTIFIED_APPROVAL" ]; then
                NOTIFIED_APPROVAL="$APPROVAL_STATE"
                NOTIFIED_BLOCKER=""
                update_session_state "$(jq -n \
                    --arg command "$CMD" \
                    --arg now "$(session_store_now_iso)" \
                    '{last_event: "approval_waiting", pending_command: $command, last_activity_at: $now}')"
                USER_MSG="⏸️ Codex 等待审批
📋 命令: ${CMD:-unknown}
🔧 session: $SESSION"
                AGENT_MSG="[Codex Monitor] 审批等待，请处理。
session: $SESSION
session_key: $SESSION_KEY
command: ${CMD:-unknown}
请在 tmux 里判断批准或拒绝。"
                notify_openclaw important "$USER_MSG" "$AGENT_MSG"
                hook_log "$LOG_FILE" "Approval detected: $CMD"
            fi
            LAST_STATE="approval"
            ;;

        working)
            if [ "$LAST_STATE" != "working" ]; then
                update_session_state "$(jq -n --arg now "$(session_store_now_iso)" '{last_event: "working", last_activity_at: $now, pending_command: null, status: "running"}')"
            fi
            LAST_STATE="working"
            NOTIFIED_BLOCKER=""
            ;;

        *)
            if [ "$LAST_STATE" = "approval" ] || [ "$LAST_STATE" = "startup_trust" ] || [ "$LAST_STATE" = "startup_update" ]; then
                update_session_state "$(jq -n --arg now "$(session_store_now_iso)" '{last_event: "idle", pending_command: null, last_activity_at: $now, status: "running"}')"
                hook_log "$LOG_FILE" "Back to idle"
            fi
            LAST_STATE="unknown"
            NOTIFIED_APPROVAL=""
            ;;
    esac

    sleep "$CHECK_INTERVAL"
done
