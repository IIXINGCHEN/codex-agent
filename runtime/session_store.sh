#!/bin/bash
# Runtime helpers for managed Codex sessions.
# This file is intended to be sourced by other scripts.

session_store_runtime_dir() {
    printf '%s\n' "${OPENCLAW_CODEX_RUNTIME_DIR:-$HOME/.openclaw/runtime/codex-agent}"
}

session_store_sessions_dir() {
    printf '%s\n' "$(session_store_runtime_dir)/sessions"
}

session_store_logs_dir() {
    printf '%s\n' "$(session_store_runtime_dir)/logs"
}

session_store_outputs_dir() {
    printf '%s\n' "$(session_store_runtime_dir)/outputs"
}

session_store_pids_dir() {
    printf '%s\n' "$(session_store_runtime_dir)/pids"
}

session_store_now_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

session_store_ensure_dirs() {
    mkdir -p "$(session_store_sessions_dir)" "$(session_store_logs_dir)" "$(session_store_outputs_dir)" "$(session_store_pids_dir)"
    chmod 700 "$(session_store_runtime_dir)" "$(session_store_sessions_dir)" "$(session_store_logs_dir)" "$(session_store_outputs_dir)" "$(session_store_pids_dir)" 2>/dev/null || true
}

session_store_slugify() {
    local input="${1:-}"

    input=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')
    input=$(printf '%s' "$input" | tr -cs 'a-z0-9._-' '-')
    input=$(printf '%s' "$input" | sed -E 's/^-+//; s/-+$//; s/-+/-/g')

    if [ -z "$input" ]; then
        input="session"
    fi

    printf '%s\n' "$input"
}

session_store_project_label_from_cwd() {
    local cwd="${1:-}"
    local base

    base=$(basename "$cwd" 2>/dev/null || true)
    session_store_slugify "$base"
}

session_store_current_openclaw_session_id() {
    local name
    local value

    for name in CODEX_AGENT_OPENCLAW_SESSION_ID OPENCLAW_SESSION_ID OPENCLAW_CURRENT_SESSION_ID OPENCLAW_OPENCLAW_SESSION_ID; do
        value="${!name:-}"
        if [ -n "$value" ] && [ "$value" != "null" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    done

    return 1
}

session_store_session_file() {
    local session_key="${1:?session key required}"
    printf '%s/%s.json\n' "$(session_store_sessions_dir)" "$session_key"
}

session_store_lock_dir() {
    local session_key="${1:?session key required}"
    printf '%s/.%s.lock\n' "$(session_store_sessions_dir)" "$session_key"
}

session_store_openclaw_session_id() {
    local session_key="${1:?session key required}"
    local existing=""

    existing="$(session_store_current_openclaw_session_id 2>/dev/null || true)"
    if [ -n "$existing" ]; then
        printf '%s\n' "$existing"
        return 0
    fi

    session_store_slugify "codex-agent-$session_key"
}

session_store_monitor_log_path() {
    local session_key="${1:?session key required}"
    printf '%s/pane-monitor-%s.log\n' "$(session_store_logs_dir)" "$session_key"
}

session_store_notify_log_path() {
    local session_key="${1:?session key required}"
    printf '%s/notify-%s.log\n' "$(session_store_logs_dir)" "$session_key"
}

session_store_run_log_path() {
    local session_key="${1:?session key required}"
    printf '%s/run-%s.log\n' "$(session_store_logs_dir)" "$session_key"
}

session_store_last_message_path() {
    local session_key="${1:?session key required}"
    printf '%s/%s.last.txt\n' "$(session_store_outputs_dir)" "$session_key"
}

session_store_monitor_pid_path() {
    local session_key="${1:?session key required}"
    printf '%s/pane-monitor-%s.pid\n' "$(session_store_pids_dir)" "$session_key"
}

session_store_acquire_lock() {
    local session_key="${1:?session key required}"
    local lock_dir
    local attempt=0

    lock_dir=$(session_store_lock_dir "$session_key")
    session_store_ensure_dirs

    while ! mkdir "$lock_dir" 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ "$attempt" -ge 200 ]; then
            echo "Failed to acquire session lock: $session_key" >&2
            return 1
        fi
        sleep 0.05
    done
}

session_store_release_lock() {
    local session_key="${1:?session key required}"
    local lock_dir

    lock_dir=$(session_store_lock_dir "$session_key")
    rmdir "$lock_dir" 2>/dev/null || true
}

session_store_exists() {
    local session_key="${1:?session key required}"
    [ -f "$(session_store_session_file "$session_key")" ]
}

session_store_read() {
    local session_key="${1:?session key required}"
    local file

    file=$(session_store_session_file "$session_key")
    [ -f "$file" ] || return 1
    cat "$file"
}

session_store_write_json() {
    local session_key="${1:?session key required}"
    local json="${2:?json required}"
    local file
    local tmp

    session_store_ensure_dirs
    file=$(session_store_session_file "$session_key")
    tmp=$(mktemp "$(session_store_sessions_dir)/.${session_key}.XXXXXX")
    printf '%s\n' "$json" > "$tmp"
    chmod 600 "$tmp" 2>/dev/null || true
    mv "$tmp" "$file"
    chmod 600 "$file" 2>/dev/null || true
}

session_store_merge() {
    local session_key="${1:?session key required}"
    local patch_json="${2:?patch json required}"
    local current='{}'
    local merged

    session_store_acquire_lock "$session_key" || return 1

    if session_store_exists "$session_key"; then
        current=$(session_store_read "$session_key") || {
            session_store_release_lock "$session_key"
            return 1
        }
    fi

    merged=$(jq -n \
        --argjson current "$current" \
        --argjson patch "$patch_json" \
        '$current + $patch') || {
        session_store_release_lock "$session_key"
        return 1
    }

    session_store_write_json "$session_key" "$merged" || {
        session_store_release_lock "$session_key"
        return 1
    }

    session_store_release_lock "$session_key"
}

session_store_attached_clients() {
    local tmux_session="${1:-}"

    if [ -z "$tmux_session" ] || ! command -v tmux >/dev/null 2>&1; then
        printf '0\n'
        return 0
    fi

    if ! tmux has-session -t "$tmux_session" 2>/dev/null; then
        printf '0\n'
        return 0
    fi

    tmux list-clients -t "$tmux_session" 2>/dev/null | awk 'END { print NR }'
}

session_store_tmux_exists() {
    local tmux_session="${1:-}"

    if [ -z "$tmux_session" ] || ! command -v tmux >/dev/null 2>&1; then
        return 1
    fi

    tmux has-session -t "$tmux_session" 2>/dev/null
}

session_store_tmux_current_command() {
    local tmux_session="${1:-}"

    if ! session_store_tmux_exists "$tmux_session"; then
        return 1
    fi

    tmux display-message -p -t "$tmux_session" '#{pane_current_command}' 2>/dev/null
}

session_store_tmux_tty() {
    local tmux_session="${1:-}"

    if ! session_store_tmux_exists "$tmux_session"; then
        return 1
    fi

    tmux display-message -p -t "$tmux_session" '#{pane_tty}' 2>/dev/null
}

session_store_tmux_has_command() {
    local tmux_session="${1:-}"
    local target_command="${2:-}"
    local tty

    if [ -z "$target_command" ]; then
        return 1
    fi

    tty="$(session_store_tmux_tty "$tmux_session" 2>/dev/null || true)"
    tty="${tty#/dev/}"
    if [ -z "$tty" ]; then
        return 1
    fi

    ps -o command= -t "$tty" 2>/dev/null | grep -Eq "(^|[[:space:]]|/)$target_command([[:space:]]|$)"
}

session_store_pid_exists() {
    local pid="${1:-}"

    if [ -z "$pid" ]; then
        return 1
    fi

    case "$pid" in
        *[!0-9]*)
            return 1
            ;;
    esac

    kill -0 "$pid" 2>/dev/null
}

session_store_refresh_live_state() {
    local session_key="${1:?session key required}"
    local json
    local tmux_session
    local launch_mode
    local process_pid
    local status
    local attached_clients
    local tmux_exists="false"
    local process_running="false"
    local current_command=""
    local codex_running="false"
    local patch_json

    json=$(session_store_read "$session_key") || return 1
    tmux_session=$(printf '%s' "$json" | jq -r '.tmux_session // ""')
    launch_mode=$(printf '%s' "$json" | jq -r '.launch_mode // ""')
    process_pid=$(printf '%s' "$json" | jq -r '.process_pid // ""')
    status=$(printf '%s' "$json" | jq -r '.status // "running"')
    attached_clients=$(session_store_attached_clients "$tmux_session")

    if session_store_tmux_exists "$tmux_session"; then
        tmux_exists="true"
        current_command="$(session_store_tmux_current_command "$tmux_session" 2>/dev/null || true)"
        if [ "$current_command" = "codex" ] || session_store_tmux_has_command "$tmux_session" "codex"; then
            current_command="codex"
            codex_running="true"
        fi
    fi

    if session_store_pid_exists "$process_pid"; then
        process_running="true"
    fi

    if [ "$launch_mode" = "interactive" ]; then
        if [ "$tmux_exists" = "true" ] && [ "$codex_running" = "true" ]; then
            status="running"
        else
            status="stopped"
        fi
    fi

    if [ "$launch_mode" = "print" ]; then
        if [ "$process_running" = "true" ]; then
            status="running"
        else
            status="stopped"
        fi
    fi

    patch_json=$(jq -n \
        --arg status "$status" \
        --arg tmux_exists "$tmux_exists" \
        --arg process_running "$process_running" \
        --arg current_command "$current_command" \
        --arg codex_running "$codex_running" \
        --argjson attached_clients "$attached_clients" \
        '{
            status: $status,
            tmux_exists: ($tmux_exists == "true"),
            process_running: ($process_running == "true"),
            current_command: $current_command,
            codex_running: ($codex_running == "true"),
            attached_clients: $attached_clients
        }')

    session_store_merge "$session_key" "$patch_json" >/dev/null
}

session_store_list_keys() {
    local dir
    local file

    session_store_ensure_dirs
    dir=$(session_store_sessions_dir)

    shopt -s nullglob
    for file in "$dir"/*.json; do
        basename "$file" .json
    done
    shopt -u nullglob
}

session_store_list_json() {
    local include_stopped="${1:-0}"
    local first=1
    local session_key
    local json
    local status

    printf '['
    while IFS= read -r session_key; do
        [ -n "$session_key" ] || continue
        session_store_refresh_live_state "$session_key" >/dev/null 2>&1 || true
        json=$(session_store_read "$session_key") || continue
        status=$(printf '%s' "$json" | jq -r '.status // "running"')

        if [ "$include_stopped" != "1" ] && [ "$status" != "running" ] && [ "$status" != "starting" ]; then
            continue
        fi

        if [ "$first" -eq 0 ]; then
            printf ','
        fi
        first=0
        printf '%s' "$json"
    done < <(session_store_list_keys)
    printf ']\n'
}

session_store_describe() {
    local session_key="${1:?session key required}"
    local json

    json=$(session_store_read "$session_key") || return 1
    printf '%s\n' "$(printf '%s' "$json" | jq -r '[.session_key, .project_label, .status, .launch_mode, .tmux_session, .cwd] | @tsv')"
}

session_store_resolve_selector() {
    local selector="${1:-}"
    local session_key
    local json
    local project_label
    local tmux_session
    local cwd
    local cwd_base
    local openclaw_session_id
    local label_matches=()
    local base_matches=()

    [ -n "$selector" ] || return 1

    while IFS= read -r session_key; do
        [ -n "$session_key" ] || continue
        session_store_refresh_live_state "$session_key" >/dev/null 2>&1 || true
        json=$(session_store_read "$session_key") || continue

        project_label=$(printf '%s' "$json" | jq -r '.project_label // ""')
        tmux_session=$(printf '%s' "$json" | jq -r '.tmux_session // ""')
        cwd=$(printf '%s' "$json" | jq -r '.cwd // ""')
        openclaw_session_id=$(printf '%s' "$json" | jq -r '.openclaw_session_id // ""')
        cwd_base=""
        if [ -n "$cwd" ]; then
            cwd_base=$(basename "$cwd" 2>/dev/null || true)
        fi

        if [ "$session_key" = "$selector" ] || [ "$tmux_session" = "$selector" ] || [ "$cwd" = "$selector" ] || [ "$openclaw_session_id" = "$selector" ]; then
            printf '%s\n' "$session_key"
            return 0
        fi

        if [ "$project_label" = "$selector" ]; then
            label_matches+=("$session_key")
        fi

        if [ -n "$cwd_base" ] && [ "$cwd_base" = "$selector" ]; then
            base_matches+=("$session_key")
        fi
    done < <(session_store_list_keys)

    if [ "${#label_matches[@]}" -eq 1 ]; then
        printf '%s\n' "${label_matches[0]}"
        return 0
    fi

    if [ "${#base_matches[@]}" -eq 1 ]; then
        printf '%s\n' "${base_matches[0]}"
        return 0
    fi

    if [ "${#label_matches[@]}" -gt 1 ]; then
        echo "Multiple sessions match label '$selector':" >&2
        for session_key in "${label_matches[@]}"; do
            session_store_describe "$session_key" >&2 || true
        done
        return 2
    fi

    if [ "${#base_matches[@]}" -gt 1 ]; then
        echo "Multiple sessions match cwd basename '$selector':" >&2
        for session_key in "${base_matches[@]}"; do
            session_store_describe "$session_key" >&2 || true
        done
        return 2
    fi

    return 1
}

session_store_resolve_selector_checked() {
    local selector="${1:-}"
    local session_key
    local rc
    local errexit_was_set=0

    case $- in
        *e*) errexit_was_set=1 ;;
    esac

    set +e
    session_key="$(session_store_resolve_selector "$selector")"
    rc=$?
    if [ "$errexit_was_set" -eq 1 ]; then
        set -e
    fi

    if [ "$rc" -eq 0 ]; then
        printf '%s\n' "$session_key"
        return 0
    fi

    case "$rc" in
        2)
            echo "❌ Multiple managed Codex sessions match: $selector" >&2
            ;;
        *)
            echo "❌ No managed Codex session matches: $selector" >&2
            ;;
    esac

    return "$rc"
}
