#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

assert_eq() {
    local expected="${1:?expected required}"
    local actual="${2:?actual required}"
    local message="${3:-assert_eq failed}"

    if [ "$expected" != "$actual" ]; then
        echo "ASSERT_EQ failed: $message" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
}

assert_contains() {
    local needle="${1:?needle required}"
    local haystack_file="${2:?haystack file required}"

    if ! grep -Fq -- "$needle" "$haystack_file"; then
        echo "ASSERT_CONTAINS failed: '$needle' not found in $haystack_file" >&2
        exit 1
    fi
}

assert_not_contains() {
    local needle="${1:?needle required}"
    local haystack_file="${2:?haystack file required}"

    if grep -Fq -- "$needle" "$haystack_file"; then
        echo "ASSERT_NOT_CONTAINS failed: '$needle' unexpectedly found in $haystack_file" >&2
        exit 1
    fi
}

assert_file_mode() {
    local expected="${1:?expected mode required}"
    local path="${2:?path required}"
    local actual

    if actual="$(stat -f '%Lp' "$path" 2>/dev/null)"; then
        :
    else
        actual="$(stat -c '%a' "$path")"
    fi

    if [ "$expected" != "$actual" ]; then
        echo "ASSERT_FILE_MODE failed: $path" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
}

wait_for_contains() {
    local needle="${1:?needle required}"
    local haystack_file="${2:?haystack file required}"
    local attempts="${3:-50}"
    local delay="${4:-0.1}"
    local i

    for i in $(seq 1 "$attempts"); do
        if grep -Fq -- "$needle" "$haystack_file" 2>/dev/null; then
            return 0
        fi
        sleep "$delay"
    done

    echo "WAIT_FOR_CONTAINS failed: '$needle' not found in $haystack_file" >&2
    exit 1
}

test_hook_logs_are_private() {
    local runtime_dir log_file

    runtime_dir="$(mktemp -d)"
    log_file="$(
        OPENCLAW_CODEX_RUNTIME_DIR="$runtime_dir" \
            PATH="/usr/bin:/bin" bash -lc "source '$ROOT_DIR/hooks/hook_common.sh'; hook_prepare_log_file notify-route"
    )"

    case "$log_file" in
        "$runtime_dir"/logs/*) ;;
        *)
            echo "ASSERT failed: log file not created under runtime dir: $log_file" >&2
            exit 1
            ;;
    esac

    assert_file_mode "600" "$log_file"
    rm -rf "$runtime_dir"
}

test_hook_wake_uses_explicit_session_id() {
    local fake_bin_dir log_file runtime_dir args_file

    fake_bin_dir="$(mktemp -d)"
    runtime_dir="$(mktemp -d)"
    log_file="$(mktemp)"
    args_file="$(mktemp)"

    printf '%s\n' \
        '#!/bin/bash' \
        "printf '%s\n' \"\$*\" > '$args_file'" \
        'exit 0' > "$fake_bin_dir/openclaw"
    chmod +x "$fake_bin_dir/openclaw"

    OPENCLAW_CODEX_RUNTIME_DIR="$runtime_dir" \
        PATH="$fake_bin_dir:$PATH" bash -lc \
        "source '$ROOT_DIR/hooks/hook_common.sh'; hook_wake_openclaw '$log_file' route-check openclaw main telegram 'wake route'" >/dev/null

    sleep 2

    assert_contains "--session-id codex-agent-route-check" "$args_file"
    assert_contains "--agent main" "$args_file"

    rm -f "$log_file" "$args_file"
    rm -rf "$fake_bin_dir" "$runtime_dir"
}

test_pane_state_detects_known_states() {
    local out

    out="$(bash -lc "source '$ROOT_DIR/hooks/pane_state.sh'; pane_state_classify \$'Update available! 0.111.0 -> 0.116.0\nPress enter to continue'")"
    assert_eq "startup_update" "$out" "should detect update prompt"

    out="$(bash -lc "source '$ROOT_DIR/hooks/pane_state.sh'; pane_state_classify \$'> You are in /tmp\nDo you trust the contents of this directory?\nPress enter to continue'")"
    assert_eq "startup_trust" "$out" "should detect trust prompt"

    out="$(bash -lc "source '$ROOT_DIR/hooks/pane_state.sh'; pane_state_classify \$'Would you like to run this command?\n  \$ git status'")"
    assert_eq "approval" "$out" "should detect approval prompt"
}

test_start_codex_records_session_and_env() {
    local fake_bin_dir runtime_dir env_file session_name

    fake_bin_dir="$(mktemp -d)"
    runtime_dir="$(mktemp -d)"
    env_file="$(mktemp)"
    session_name="codex-agent-regression-$$"

    printf '%s\n' \
        '#!/bin/bash' \
        "printf 'SESSION_KEY=%s\n' \"\$CODEX_AGENT_SESSION_KEY\" > '$env_file'" \
        "printf 'OC_SESSION=%s\n' \"\$CODEX_AGENT_OPENCLAW_SESSION_ID\" >> '$env_file'" \
        "parent_cmd=\$(ps -o command= -p \"\$PPID\" | sed 's/^[[:space:]]*//')" \
        "printf 'PARENT_CMD=%s\n' \"\$parent_cmd\" >> '$env_file'" \
        'sleep 30' > "$fake_bin_dir/codex"
    chmod +x "$fake_bin_dir/codex"

    OPENCLAW_CODEX_RUNTIME_DIR="$runtime_dir" \
        PATH="$fake_bin_dir:$PATH" \
        CODEX_AGENT_CHAT_ID="123" \
        CODEX_AGENT_CHANNEL="discord" \
        CODEX_AGENT_NAME="ops" \
        bash "$ROOT_DIR/hooks/start_codex.sh" "$session_name" "$ROOT_DIR" --full-auto >/dev/null

    wait_for_contains "SESSION_KEY=$session_name" "$env_file"
    OPENCLAW_CODEX_RUNTIME_DIR="$runtime_dir" bash "$ROOT_DIR/runtime/session_status.sh" "$session_name" >/dev/null

    assert_contains "SESSION_KEY=$session_name" "$env_file"
    assert_contains "OC_SESSION=codex-agent-$session_name" "$env_file"
    assert_contains "--noprofile --norc -lc" "$env_file"
    assert_eq "discord" "$(jq -r '.channel' "$runtime_dir/sessions/$session_name.json")" "session should preserve channel"
    assert_eq "ops" "$(jq -r '.agent_name' "$runtime_dir/sessions/$session_name.json")" "session should preserve agent name"
    assert_eq "running" "$(jq -r '.status' "$runtime_dir/sessions/$session_name.json")" "interactive session should stay running while codex is active"
    assert_eq "codex" "$(jq -r '.current_command' "$runtime_dir/sessions/$session_name.json")" "bootstrapped session should still resolve the active codex process"
    assert_contains "$runtime_dir/pids/pane-monitor-$session_name.pid" "$runtime_dir/sessions/$session_name.json"
    assert_file_mode "600" "$runtime_dir/pids/pane-monitor-$session_name.pid"

    bash "$ROOT_DIR/hooks/stop_codex.sh" "$session_name" >/dev/null
    tmux kill-session -t "$session_name" >/dev/null 2>&1 || true
    rm -f "$env_file"
    rm -rf "$fake_bin_dir" "$runtime_dir"
}

test_start_codex_fails_fast_on_bootstrap_errors() {
    local fake_bin_dir runtime_dir session_name output_file

    fake_bin_dir="$(mktemp -d)"
    runtime_dir="$(mktemp -d)"
    output_file="$(mktemp)"
    session_name="codex-agent-launchfail-$$"

    printf '%s\n' \
        '#!/bin/bash' \
        "printf '%s\n' 'Traceback (most recent call last):' 'IndexError: boom'" \
        'exit 23' > "$fake_bin_dir/codex"
    chmod +x "$fake_bin_dir/codex"

    if OPENCLAW_CODEX_RUNTIME_DIR="$runtime_dir" PATH="$fake_bin_dir:$PATH" \
        bash "$ROOT_DIR/hooks/start_codex.sh" "$session_name" "$ROOT_DIR" --full-auto >"$output_file" 2>&1; then
        echo "ASSERT failed: start_codex.sh should have reported bootstrap failure" >&2
        exit 1
    fi

    assert_contains "Codex failed before the TUI became ready" "$output_file"
    assert_eq "launch_failed" "$(jq -r '.last_event' "$runtime_dir/sessions/$session_name.json")" "session should record launch failure"

    bash "$ROOT_DIR/hooks/stop_codex.sh" "$session_name" >/dev/null 2>&1 || true
    tmux kill-session -t "$session_name" >/dev/null 2>&1 || true
    rm -f "$output_file"
    rm -rf "$fake_bin_dir" "$runtime_dir"
}

test_on_complete_redacts_summary_and_keeps_explicit_route() {
    local fake_bin_dir runtime_dir calls_file notification_json raw_key

    fake_bin_dir="$(mktemp -d)"
    runtime_dir="$(mktemp -d)"
    calls_file="$(mktemp)"
    raw_key="sk-supersecret1234567890"

    printf '%s\n' \
        '#!/bin/bash' \
        "printf '%s\n' \"\$*\" >> '$calls_file'" \
        'exit 0' > "$fake_bin_dir/openclaw"
    chmod +x "$fake_bin_dir/openclaw"

    notification_json="$(
        python3 - <<'PY'
import json
print(json.dumps({
    "type": "agent-turn-complete",
    "cwd": "/Users/abel/project/codex-agent",
    "thread-id": "thread-123",
    "last-assistant-message": "done API_KEY=sk-supersecret1234567890 ```python\nprint(123)\n``` final"
}))
PY
    )"

    PATH="$fake_bin_dir:$PATH" \
        OPENCLAW_CODEX_RUNTIME_DIR="$runtime_dir" \
        CODEX_AGENT_CHAT_ID="123" \
        CODEX_AGENT_CHANNEL="telegram" \
        CODEX_AGENT_NAME="ops" \
        CODEX_AGENT_SESSION_KEY="notify-test" \
        CODEX_AGENT_OPENCLAW_SESSION_ID="codex-agent-notify-test" \
        python3 "$ROOT_DIR/hooks/on_complete.py" "$notification_json" >/dev/null

    wait_for_contains "--session-id codex-agent-notify-test" "$calls_file"
    assert_contains "--target 123" "$calls_file"
    assert_contains "[redacted]" "$calls_file"
    assert_not_contains "$raw_key" "$calls_file"
    assert_contains "[redacted]" "$runtime_dir/sessions/notify-test.json"
    assert_not_contains "$raw_key" "$runtime_dir/sessions/notify-test.json"

    rm -f "$calls_file"
    rm -rf "$fake_bin_dir" "$runtime_dir"
}

main() {
    test_hook_logs_are_private
    test_hook_wake_uses_explicit_session_id
    test_pane_state_detects_known_states
    test_start_codex_records_session_and_env
    test_start_codex_fails_fast_on_bootstrap_errors
    test_on_complete_redacts_summary_and_keeps_explicit_route
}

main "$@"
