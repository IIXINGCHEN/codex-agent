#!/usr/bin/env python3
"""
Codex notify hook — Codex 完成 turn 时：
1. 给用户发 Telegram 通知（看到 Codex 干了什么）
2. 唤醒 OpenClaw agent（去检查输出）

配置：通过环境变量或修改下方默认值
  CODEX_AGENT_CHAT_ID   — Chat ID (Telegram/Discord/WhatsApp etc.)
  CODEX_AGENT_NAME      — OpenClaw agent 名称（默认 main）
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

CHAT_ID = os.environ.get("CODEX_AGENT_CHAT_ID", "YOUR_CHAT_ID")
CHANNEL = os.environ.get("CODEX_AGENT_CHANNEL", "telegram")
AGENT_NAME = os.environ.get("CODEX_AGENT_NAME", "main")
SESSION_KEY = os.environ.get("CODEX_AGENT_SESSION_KEY", "")
OPENCLAW_SESSION_ID = os.environ.get("CODEX_AGENT_OPENCLAW_SESSION_ID", "")
RUNTIME_DIR = Path(os.environ.get("OPENCLAW_CODEX_RUNTIME_DIR", str(Path.home() / ".openclaw" / "runtime" / "codex-agent")))
SESSIONS_DIR = RUNTIME_DIR / "sessions"
LOGS_DIR = RUNTIME_DIR / "logs"


def slugify(text: str) -> str:
    cleaned = []
    previous_dash = False
    for char in text.lower():
        if char.isalnum() or char in "._-":
            cleaned.append(char)
            previous_dash = False
        else:
            if not previous_dash:
                cleaned.append("-")
            previous_dash = True
    result = "".join(cleaned).strip("-")
    return result or "session"


def effective_session_key(notification: dict) -> str:
    if SESSION_KEY:
        return SESSION_KEY
    thread_id = notification.get("thread-id") or notification.get("thread_id")
    cwd = notification.get("cwd", "")
    if thread_id:
        return slugify(f"codex-thread-{thread_id[:16]}")
    if cwd:
        return slugify(Path(cwd).name)
    return "notify-standalone"


def effective_openclaw_session_id(session_key: str) -> str:
    if OPENCLAW_SESSION_ID:
        return OPENCLAW_SESSION_ID
    return slugify(f"codex-agent-{session_key}")


def ensure_runtime_dirs() -> None:
    for path in (RUNTIME_DIR, SESSIONS_DIR, LOGS_DIR):
        path.mkdir(parents=True, exist_ok=True)
        try:
            path.chmod(0o700)
        except OSError:
            pass


def current_log_file(notification: dict) -> Path:
    ensure_runtime_dirs()
    return LOGS_DIR / f"notify-{effective_session_key(notification)}.log"


def append_private_file(path: Path, content: str) -> None:
    if path.is_symlink():
        raise RuntimeError(f"refusing to write symlink: {path}")
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    try:
        os.write(fd, content.encode("utf-8", errors="replace"))
    finally:
        os.close(fd)


def log(msg: str, notification: dict | None = None):
    try:
        path = current_log_file(notification or {})
        append_private_file(path, f"[{datetime.now().strftime('%H:%M:%S')}] {msg}\n")
    except Exception:
        pass  # 日志写入失败不应影响主流程


def session_file(session_key: str) -> Path:
    ensure_runtime_dirs()
    return SESSIONS_DIR / f"{session_key}.json"


def merge_session(session_key: str, patch: dict) -> None:
    path = session_file(session_key)
    lock_dir = path.with_suffix(".lock")

    for _ in range(200):
        try:
            os.mkdir(lock_dir)
            break
        except FileExistsError:
            time.sleep(0.05)
    else:
        raise RuntimeError(f"failed to lock session file: {path}")

    try:
        current: dict = {}
        if path.exists():
            current = json.loads(path.read_text(encoding="utf-8"))
        current.update(patch)
        with tempfile.NamedTemporaryFile("w", delete=False, dir=SESSIONS_DIR, encoding="utf-8") as tmp:
            json.dump(current, tmp, ensure_ascii=False, indent=2)
            tmp.write("\n")
            tmp_name = tmp.name
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, path)
        try:
            path.chmod(0o600)
        except OSError:
            pass
    finally:
        try:
            os.rmdir(lock_dir)
        except OSError:
            pass


def summarize_for_chat(summary: str) -> str:
    preview = summary.strip()
    if not preview:
        return "Turn Complete!"

    preview = re.sub(r"```[\s\S]*?```", "[code omitted]", preview)
    preview = re.sub(
        r"(?i)\b(api[_-]?key|token|secret|password|passwd|authorization|bearer)\b\s*[:=]\s*([\"']?)[^\s,;]+",
        r"\1=[redacted]",
        preview,
    )
    preview = re.sub(r"\bsk-[A-Za-z0-9_-]{12,}\b", "[redacted-key]", preview)
    preview = re.sub(r"\bgh[pousr]_[A-Za-z0-9_]{12,}\b", "[redacted-key]", preview)
    preview = re.sub(r"\bAIza[0-9A-Za-z\\-_]{16,}\b", "[redacted-key]", preview)
    preview = re.sub(r"\bxox[baprs]-[A-Za-z0-9-]{12,}\b", "[redacted-key]", preview)
    preview = re.sub(r"\btvly-[A-Za-z0-9_-]{12,}\b", "[redacted-key]", preview)
    preview = re.sub(r"\b(?:[A-Fa-f0-9]{32,}|[A-Za-z0-9+/]{40,}={0,2})\b", "[redacted-token]", preview)
    preview = re.sub(r"\s+", " ", preview).strip()

    if len(preview) <= 240:
        return preview
    return preview[:237] + "..."


def notify_user(msg: str, notification: dict) -> bool:
    """发送 Telegram 通知，返回是否成功启动进程"""
    try:
        proc = subprocess.Popen(
            [
                "openclaw", "message", "send",
                "--channel", CHANNEL,
                "--target", CHAT_ID,
                "--message", msg,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        # 等待最多 10 秒，检查是否成功
        try:
            _, stderr = proc.communicate(timeout=10)
            if proc.returncode != 0:
                log(f"channel notify failed (exit {proc.returncode}): {stderr.decode()[:200]}", notification)
                return False
        except subprocess.TimeoutExpired:
            log("channel notify timeout (10s), process still running", notification)
        log("channel notify sent", notification)
        return True
    except Exception as e:
        log(f"channel notify error: {e}", notification)
        return False


def wake_agent(msg: str, session_id: str, notification: dict) -> bool:
    """唤醒 OpenClaw agent，返回是否成功启动进程"""
    try:
        proc = subprocess.Popen(
            [
                "openclaw", "agent",
                "--agent", AGENT_NAME,
                "--session-id", session_id,
                "--message", msg,
                "--deliver",
                "--channel", CHANNEL,
                "--timeout", "120",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        log(f"agent wake fired (pid {proc.pid})", notification)
        return True
    except Exception as e:
        log(f"agent wake error: {e}", notification)
        return False


def main() -> int:
    if len(sys.argv) < 2:
        return 0

    try:
        notification = json.loads(sys.argv[1])
    except json.JSONDecodeError as e:
        log(f"JSON parse error: {e}", {})
        return 1

    if notification.get("type") != "agent-turn-complete":
        return 0

    summary = notification.get("last-assistant-message", "Turn Complete!")
    cwd = notification.get("cwd", "unknown")
    thread_id = notification.get("thread-id", "unknown")
    session_key = effective_session_key(notification)
    session_id = effective_openclaw_session_id(session_key)
    chat_summary = summarize_for_chat(summary)

    log(f"Codex turn complete: thread={thread_id}, cwd={cwd}", notification)
    log(f"Summary preview: {chat_summary}", notification)
    try:
        merge_session(
            session_key,
            {
                "session_key": session_key,
                "project_label": slugify(Path(cwd).name if cwd != "unknown" else session_key),
                "cwd": cwd,
                "controller": "openclaw",
                "launch_mode": "interactive",
                "status": "running",
                "chat_id": CHAT_ID,
                "channel": CHANNEL,
                "agent_name": AGENT_NAME,
                "openclaw_session_id": session_id,
                "codex_thread_id": thread_id,
                "last_summary": chat_summary,
                "last_event": "agent_turn_complete",
                "last_activity_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "notify_log": str(current_log_file(notification)),
            },
        )
    except Exception as e:
        log(f"session merge failed: {e}", notification)

    # ⚠️ 注意：summary 可能包含代码片段、路径、密钥等敏感信息
    # 发送到 Telegram 前用户应评估风险（私人仓库/私聊通常可接受）
    msg = (
        f"🔔 Codex 任务回复\n"
        f"📁 {cwd}\n"
        f"💬 {chat_summary}"
    )

    # 1. 给用户发 Telegram 通知
    tg_ok = notify_user(msg, notification)

    # 2. 唤醒 agent（fire-and-forget）
    agent_msg = (
        f"[Codex Hook] 任务完成，请检查输出并汇报。\n"
        f"session_key: {session_key}\n"
        f"cwd: {cwd}\n"
        f"thread: {thread_id}\n"
        f"summary: {chat_summary}"
    )
    agent_ok = wake_agent(agent_msg, session_id, notification)

    if not tg_ok and not agent_ok:
        log("⚠️ Both channel notify and agent wake failed!", notification)

    return 0


if __name__ == "__main__":
    sys.exit(main())
