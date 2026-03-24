#!/bin/bash
# Parse Codex TUI pane output into coarse states.

pane_state_classify() {
    local output="${1:-}"

    if printf '%s' "$output" | grep -Eq 'Update available! .* -> '; then
        printf '%s\n' "startup_update"
        return 0
    fi

    if printf '%s' "$output" | grep -Eq 'Do you trust the contents of this directory\?'; then
        printf '%s\n' "startup_trust"
        return 0
    fi

    if printf '%s' "$output" | grep -Eq 'Would you like to run|Press enter to confirm|approve this|allow this'; then
        printf '%s\n' "approval"
        return 0
    fi

    if printf '%s' "$output" | grep -Eq 'Updating Codex via|esc to interrupt|Thinking|Creating|Editing|Running|Compacting'; then
        printf '%s\n' "working"
        return 0
    fi

    printf '%s\n' "unknown"
}

pane_extract_approval_command() {
    local output="${1:-}"
    local command_line=""

    command_line="$(printf '%s\n' "$output" | grep '^[[:space:]]*\$' | tail -1 | sed 's/^[[:space:]]*\$ //')"
    if [ -n "$command_line" ]; then
        printf '%s\n' "$command_line"
        return 0
    fi

    command_line="$(printf '%s\n' "$output" | sed -n 's/.*runs `\([^`]*\)`.*/\1/p' | tail -1)"
    if [ -n "$command_line" ]; then
        printf '%s\n' "$command_line"
        return 0
    fi

    printf '%s\n' "unknown"
}
