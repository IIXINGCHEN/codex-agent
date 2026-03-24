#!/bin/bash
# Show one managed Codex session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/session_store.sh"

AS_JSON=0
SELECTOR=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --json)
            AS_JSON=1
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [--json] <selector>

Selector resolution order:
  session_key -> tmux_session -> full cwd -> openclaw_session_id -> unique project_label -> unique cwd basename
EOF
            exit 0
            ;;
        *)
            if [ -n "$SELECTOR" ]; then
                echo "Too many selectors." >&2
                exit 1
            fi
            SELECTOR="$1"
            shift
            ;;
    esac
done

SELECTOR="${SELECTOR:?Usage: $0 [--json] <selector>}"
SESSION_KEY="$(session_store_resolve_selector_checked "$SELECTOR")"
session_store_refresh_live_state "$SESSION_KEY" >/dev/null 2>&1 || true
SESSION_JSON="$(session_store_read "$SESSION_KEY")"

if [ "$AS_JSON" -eq 1 ]; then
    printf '%s\n' "$SESSION_JSON"
    exit 0
fi

printf '%s\n' "session_key:        $(printf '%s' "$SESSION_JSON" | jq -r '.session_key')"
printf '%s\n' "status:             $(printf '%s' "$SESSION_JSON" | jq -r '.status // "-"' )"
printf '%s\n' "launch_mode:        $(printf '%s' "$SESSION_JSON" | jq -r '.launch_mode // "-"' )"
printf '%s\n' "project_label:      $(printf '%s' "$SESSION_JSON" | jq -r '.project_label // "-"' )"
printf '%s\n' "tmux_session:       $(printf '%s' "$SESSION_JSON" | jq -r '.tmux_session // "-"' )"
printf '%s\n' "openclaw_session:   $(printf '%s' "$SESSION_JSON" | jq -r '.openclaw_session_id // "-"' )"
printf '%s\n' "codex_thread_id:    $(printf '%s' "$SESSION_JSON" | jq -r '.codex_thread_id // "-"' )"
printf '%s\n' "current_command:    $(printf '%s' "$SESSION_JSON" | jq -r '.current_command // "-"' )"
printf '%s\n' "cwd:                $(printf '%s' "$SESSION_JSON" | jq -r '.cwd // "-"' )"
printf '%s\n' "monitor_log:        $(printf '%s' "$SESSION_JSON" | jq -r '.monitor_log // "-"' )"
printf '%s\n' "notify_log:         $(printf '%s' "$SESSION_JSON" | jq -r '.notify_log // "-"' )"
printf '%s\n' "run_log:            $(printf '%s' "$SESSION_JSON" | jq -r '.run_log // "-"' )"
printf '%s\n' "last_event:         $(printf '%s' "$SESSION_JSON" | jq -r '.last_event // "-"' )"
printf '%s\n' "last_summary:       $(printf '%s' "$SESSION_JSON" | jq -r '.last_summary // "-"' )"
