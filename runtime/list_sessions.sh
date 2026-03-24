#!/bin/bash
# List managed Codex sessions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/session_store.sh"

INCLUDE_STOPPED=0
AS_JSON=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --all)
            INCLUDE_STOPPED=1
            shift
            ;;
        --json)
            AS_JSON=1
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [--all] [--json]

List managed Codex sessions recorded by codex-agent.
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

SESSIONS_JSON="$(session_store_list_json "$INCLUDE_STOPPED")"

if [ "$AS_JSON" -eq 1 ]; then
    printf '%s\n' "$SESSIONS_JSON"
    exit 0
fi

COUNT="$(printf '%s' "$SESSIONS_JSON" | jq 'length')"
if [ "$COUNT" -eq 0 ]; then
    echo "No managed Codex sessions found."
    exit 0
fi

printf '%s\n' "Managed Codex sessions:"
printf '%s\n' "$SESSIONS_JSON" | jq -r '
    .[] |
    [
      .session_key,
      (.status // "unknown"),
      (.launch_mode // "-"),
      (.tmux_session // "-"),
      (.openclaw_session_id // "-"),
      (.cwd // "-")
    ] | @tsv
' | while IFS=$'\t' read -r session_key status launch_mode tmux_session openclaw_session_id cwd; do
    printf '%s\n' "- ${session_key} | ${status} | ${launch_mode} | tmux=${tmux_session} | oc=${openclaw_session_id} | ${cwd}"
done
