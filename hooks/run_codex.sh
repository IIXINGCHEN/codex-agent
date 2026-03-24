#!/bin/bash
# Codex one-shot managed runner.
# Usage: ./run_codex.sh <workdir> [codex exec args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/runtime/session_store.sh"

WORKDIR="${1:?Usage: $0 <workdir> [codex exec args...]}"
shift
CODEX_ARGS=("$@")

if ! command -v codex >/dev/null 2>&1; then
    echo "❌ codex not found"
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq not found"
    exit 1
fi
if [ ! -d "$WORKDIR" ]; then
    echo "❌ Directory not found: $WORKDIR"
    exit 1
fi

PROJECT_LABEL="${CODEX_AGENT_PROJECT_LABEL:-$(session_store_project_label_from_cwd "$WORKDIR")}"
SESSION_KEY="${CODEX_AGENT_SESSION_KEY:-$(session_store_slugify "codex-run-$PROJECT_LABEL-$(date +%s)-$$")}"
OPENCLAW_SESSION_ID="${CODEX_AGENT_OPENCLAW_SESSION_ID:-$(session_store_openclaw_session_id "$SESSION_KEY")}"
CHAT_ID="${CODEX_AGENT_CHAT_ID:-}"
CHANNEL="${CODEX_AGENT_CHANNEL:-telegram}"
AGENT_NAME="${CODEX_AGENT_NAME:-main}"
STARTED_AT="$(session_store_now_iso)"
RUN_LOG="$(session_store_run_log_path "$SESSION_KEY")"
LAST_MESSAGE_FILE="$(session_store_last_message_path "$SESSION_KEY")"
NOTIFY_LOG="$(session_store_notify_log_path "$SESSION_KEY")"

session_store_ensure_dirs

if [ "${#CODEX_ARGS[@]}" -eq 0 ]; then
    CODEX_ARGS=(--full-auto "Summarize the repository state.")
fi

JSON="$(jq -n \
    --arg session_key "$SESSION_KEY" \
    --arg project_label "$PROJECT_LABEL" \
    --arg cwd "$WORKDIR" \
    --arg openclaw_session_id "$OPENCLAW_SESSION_ID" \
    --arg chat_id "$CHAT_ID" \
    --arg channel "$CHANNEL" \
    --arg agent_name "$AGENT_NAME" \
    --arg started_at "$STARTED_AT" \
    --arg run_log "$RUN_LOG" \
    --arg notify_log "$NOTIFY_LOG" \
    --arg last_message_file "$LAST_MESSAGE_FILE" \
    --arg codex_args "${CODEX_ARGS[*]}" \
    '{
        session_key: $session_key,
        project_label: $project_label,
        cwd: $cwd,
        launch_mode: "print",
        controller: "openclaw",
        status: "starting",
        managed_by: "openclaw",
        attached_clients: 0,
        tmux_exists: false,
        process_running: false,
        chat_id: $chat_id,
        channel: $channel,
        agent_name: $agent_name,
        openclaw_session_id: $openclaw_session_id,
        codex_thread_id: "",
        last_summary: "",
        last_event: "launching",
        last_activity_at: $started_at,
        started_at: $started_at,
        run_log: $run_log,
        notify_log: $notify_log,
        last_message_file: $last_message_file,
        codex_args: $codex_args
    }')"
session_store_write_json "$SESSION_KEY" "$JSON"

(
    cd "$WORKDIR"
    exec env \
        OPENCLAW_CODEX_RUNTIME_DIR="$(session_store_runtime_dir)" \
        CODEX_AGENT_SESSION_KEY="$SESSION_KEY" \
        CODEX_AGENT_OPENCLAW_SESSION_ID="$OPENCLAW_SESSION_ID" \
        CODEX_AGENT_CHAT_ID="$CHAT_ID" \
        CODEX_AGENT_CHANNEL="$CHANNEL" \
        CODEX_AGENT_NAME="$AGENT_NAME" \
        codex exec -C "$WORKDIR" -o "$LAST_MESSAGE_FILE" "${CODEX_ARGS[@]}"
) >"$RUN_LOG" 2>&1 &
PROCESS_PID=$!

session_store_merge "$SESSION_KEY" "$(jq -n \
    --arg process_pid "$PROCESS_PID" \
    --arg run_log "$RUN_LOG" \
    --arg last_event "launch_started" \
    --arg last_activity_at "$(session_store_now_iso)" \
    '{process_pid: ($process_pid|tonumber), process_running: true, run_log: $run_log, last_event: $last_event, last_activity_at: $last_activity_at, status: "running"}')" >/dev/null

echo "✅ Codex exec started"
echo "   session_key:   $SESSION_KEY"
echo "   oc_session:    $OPENCLAW_SESSION_ID"
echo "   pid:           $PROCESS_PID"
echo "   run_log:       $RUN_LOG"
echo "   last_message:  $LAST_MESSAGE_FILE"
