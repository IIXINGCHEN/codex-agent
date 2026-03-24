# Changelog

## 2026-03-24

### Runtime and routing

- Added a managed runtime registry under `~/.openclaw/runtime/codex-agent`
- Added session helpers:
  - [`runtime/session_store.sh`](/Users/abel/project/codex-agent/runtime/session_store.sh)
  - [`runtime/list_sessions.sh`](/Users/abel/project/codex-agent/runtime/list_sessions.sh)
  - [`runtime/session_status.sh`](/Users/abel/project/codex-agent/runtime/session_status.sh)
- Added one-shot execution entrypoint: [`hooks/run_codex.sh`](/Users/abel/project/codex-agent/hooks/run_codex.sh)
- Switched OpenClaw wakeups to explicit `--session-id`
- Added wake dedupe and private runtime logging helpers in [`hooks/hook_common.sh`](/Users/abel/project/codex-agent/hooks/hook_common.sh)

### Bug fixes

- Fixed startup false-positive by teaching the monitor to detect:
  - Codex self-update prompt
  - Codex directory trust prompt
- Fixed interactive startup to launch Codex through a clean non-profile shell inside tmux, so broken shell init or conda activation no longer blocks the TUI before Codex starts
- Fixed approval detection drift with a dedicated pane classifier in [`hooks/pane_state.sh`](/Users/abel/project/codex-agent/hooks/pane_state.sh)
- Fixed monitor PID handling by moving PID files out of `/tmp` and into the private runtime directory
- Fixed notification routing and session merging in [`hooks/on_complete.py`](/Users/abel/project/codex-agent/hooks/on_complete.py)
- Reduced external data leakage by sanitizing completion previews before sending them to chat channels or agent wake messages

### Documentation refresh

- Rebased the project docs on:
  - local `codex` CLI `0.116.0-alpha.10`
  - local `openclaw` CLI `2026.3.11`
  - current OpenAI Codex docs
  - current OpenClaw docs
- Removed outdated assumptions about:
  - `gpt-5.2` being the default model
  - `steer`, `collaboration_modes`, and `sqlite` being active Codex features
  - “daily 4am” OpenClaw session resets
- Documented the current OpenClaw docs-vs-local-CLI mismatch around skills installation

### Validation

- Added/updated [`tests/regression.sh`](/Users/abel/project/codex-agent/tests/regression.sh)
- Verified with:
  - `bash -n` on shell scripts
  - `python3 -m py_compile hooks/on_complete.py`
  - `bash tests/regression.sh`
