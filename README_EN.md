# Codex Agent

A managed runtime layer that lets OpenClaw operate Codex CLI reliably instead of depending on ad-hoc tmux automation.

## Validated baseline

- Validation date: `2026-03-24`
- Local Codex: `codex-cli 0.116.0-alpha.10`
- Local OpenClaw: `OpenClaw 2026.3.11`
- Local Codex defaults: `gpt-5.4`, `xhigh` reasoning, `web_search = "live"`

## What this project now provides

- Managed interactive Codex sessions via [`hooks/start_codex.sh`](/Users/abel/project/codex-agent/hooks/start_codex.sh)
- Managed one-shot `codex exec` runs via [`hooks/run_codex.sh`](/Users/abel/project/codex-agent/hooks/run_codex.sh)
- A runtime registry under `~/.openclaw/runtime/codex-agent`
- Explicit OpenClaw routing with stable `--session-id`
- Detection of modern Codex startup blockers:
  - self-update prompt
  - directory trust prompt
- Private logs and private monitor PID files
- Sanitized completion previews in external notifications

## Why the refresh was necessary

The repository had drifted badly:

- `state/version.txt` was still on `0.104.0`
- docs still treated `gpt-5.2` as the default model
- removed Codex flags such as `steer`, `collaboration_modes`, and `sqlite` were still documented as current
- OpenClaw session reset behavior was described incorrectly
- startup monitoring did not recognize the current Codex update/trust blockers

## Design stance

This repo learned from `/Users/abel/project/claude-code-agent`, but does not copy Claude-specific control flow.

Borrowed ideas:

- stable `session_key`
- stable `openclaw_session_id`
- runtime session registry
- explicit status/list tooling
- wake dedupe

Not copied blindly:

- Claude hook lifecycle
- Claude permission callback model
- Claude-specific handoff semantics

## Main entry points

- [`hooks/start_codex.sh`](/Users/abel/project/codex-agent/hooks/start_codex.sh)
- [`hooks/run_codex.sh`](/Users/abel/project/codex-agent/hooks/run_codex.sh)
- [`hooks/pane_monitor.sh`](/Users/abel/project/codex-agent/hooks/pane_monitor.sh)
- [`hooks/on_complete.py`](/Users/abel/project/codex-agent/hooks/on_complete.py)
- [`runtime/list_sessions.sh`](/Users/abel/project/codex-agent/runtime/list_sessions.sh)
- [`runtime/session_status.sh`](/Users/abel/project/codex-agent/runtime/session_status.sh)
- [`tests/regression.sh`](/Users/abel/project/codex-agent/tests/regression.sh)

## Recommended workflows

### Interactive long-running work

```bash
bash hooks/start_codex.sh codex-agent-demo /absolute/workdir --full-auto
```

Inspect or attach:

```bash
bash runtime/list_sessions.sh
bash runtime/session_status.sh codex-agent-demo
tmux attach -t codex-agent-demo
```

Stop:

```bash
bash hooks/stop_codex.sh codex-agent-demo
```

### Non-interactive automation

```bash
bash hooks/run_codex.sh /absolute/workdir --full-auto "Summarize the repository state."
```

## Important upstream mismatch

OpenClaw’s latest docs describe a richer skills/ClawHub workflow, but the local `openclaw skills` command on this machine still exposes only `list`, `info`, and `check`.

This repo therefore documents two truths at once:

- official docs for product direction
- local CLI output for what is actually runnable today

When those disagree, installation and operational docs prefer the locally verified path.

## Setup

See [INSTALL.md](https://github.com/dztabel-happy/codex-agent/blob/main/INSTALL.md).

The three quickest verification commands are:

```bash
codex --version
openclaw --version
bash tests/regression.sh
```

## Primary references

- [Codex CLI features](https://developers.openai.com/codex/cli/features)
- [Codex CLI reference](https://developers.openai.com/codex/cli/reference)
- [Codex config reference](https://developers.openai.com/codex/config-reference)
- [OpenAI latest model guide](https://developers.openai.com/api/docs/guides/latest-model)
- [OpenClaw configuration reference](https://docs.openclaw.ai/gateway/configuration-reference)
- [OpenClaw agent CLI](https://docs.openclaw.ai/cli/agent)
- [OpenClaw skills CLI](https://docs.openclaw.ai/cli/skills)
- [OpenClaw onboard CLI](https://docs.openclaw.ai/cli/onboard)
