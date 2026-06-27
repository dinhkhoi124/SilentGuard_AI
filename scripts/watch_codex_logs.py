#!/usr/bin/env python3
"""
Watch Codex session transcripts and append new user prompts to .ai-log/session.jsonl.

This is a lightweight fallback for environments where hook delivery is flaky.
It polls the local Codex transcript directory and backfills any unseen prompt
entries into the live AI log file.
"""
from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path

VN_TZ = timezone(timedelta(hours=7))
POLL_SECONDS = 5


def git(args: list[str]) -> str:
    try:
        return subprocess.check_output(
            ["git", *args],
            shell=False,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return ""


def _codex_sessions_root() -> Path:
    env_home = os.environ.get("CODEX_HOME")
    if env_home:
        return Path(env_home).expanduser() / "sessions"
    return Path.home() / ".codex" / "sessions"


def _repo_name() -> str:
    origin = git(["remote", "get-url", "origin"])
    if not origin:
        return Path.cwd().name
    repo = origin.rstrip("/").split("/")[-1]
    return repo[:-4] if repo.endswith(".git") else repo


def _load_logged_ids(log_file: Path) -> set[str]:
    logged: set[str] = set()
    if not log_file.exists():
        return logged
    with open(log_file, encoding="utf-8-sig") as f:
        for line in f:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            entry_id = entry.get("entry_id")
            if entry_id:
                logged.add(entry_id)
    return logged


def _to_vn_iso(value: str) -> str:
    if not value:
        return datetime.now(VN_TZ).isoformat()
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return datetime.now(VN_TZ).isoformat()
    return dt.astimezone(VN_TZ).isoformat()


def _extract_prompt_from_event(entry: dict) -> str:
    payload = entry.get("payload") or {}
    if entry.get("type") == "event_msg" and payload.get("type") in (
        "user_message",
        "user_prompt",
    ):
        for key in ("message", "prompt", "content", "text"):
            value = (payload.get(key) or "").strip()
            if value:
                return value[:1000]
    for key in ("prompt", "message", "content", "text"):
        value = (entry.get(key) or "").strip()
        if value:
            return value[:1000]
    return ""


def _iter_transcript_prompts(transcript: Path):
    session_id = transcript.stem
    turn_id = ""
    with open(transcript, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            payload = entry.get("payload") or {}
            if entry.get("type") == "session_meta":
                session_id = payload.get("session_id") or payload.get("id") or session_id
                continue
            if entry.get("type") == "turn_context":
                turn_id = payload.get("turn_id") or turn_id
                continue
            if entry.get("type") != "event_msg" or payload.get("type") != "user_message":
                continue

            prompt = _extract_prompt_from_event(entry)
            if not prompt:
                continue

            ts = entry.get("timestamp") or ""
            if not turn_id:
                turn_id = entry.get("turn_id") or ""
            yield {
                "ts": _to_vn_iso(ts),
                "session_id": session_id,
                "turn_id": turn_id,
                "prompt": prompt,
                "transcript_path": str(transcript),
                "model": payload.get("model") or entry.get("model") or "",
            }


def _entry_id(session_id: str, turn_id: str, index: int) -> str:
    suffix = turn_id or f"{index:05d}"
    return f"codex-{session_id}-{suffix}"


def _append_entries(log_file: Path, entries: list[dict]) -> None:
    if not entries:
        return
    log_file.parent.mkdir(parents=True, exist_ok=True)
    repo = _repo_name()
    branch = git(["rev-parse", "--abbrev-ref", "HEAD"])
    commit = git(["rev-parse", "--short", "HEAD"])
    student = git(["config", "user.email"]) or os.environ.get(
        "USERNAME", os.environ.get("USER", "unknown")
    )
    with open(log_file, "a", encoding="utf-8") as f:
        for item in entries:
            payload = {
                "ts": item["ts"],
                "tool": "codex",
                "event": "UserPromptSubmit",
                "entry_id": item["entry_id"],
                "session_id": item["session_id"],
                "model": item["model"],
                "repo": repo,
                "branch": branch,
                "commit": commit,
                "student": student,
                "prompt": item["prompt"],
                "response_summary": "",
                "turn_id": item["turn_id"],
                "transcript_path": item["transcript_path"],
                "source": "codex-transcript-watch",
            }
            f.write(json.dumps(payload, ensure_ascii=False) + "\n")


def main() -> None:
    sessions_root = _codex_sessions_root()
    if not sessions_root.exists():
        print(f"[codex-watch] no sessions dir: {sessions_root}", file=sys.stderr)
        sys.exit(0)

    log_dir = Path(os.environ.get("AI_LOG_DIR", ".ai-log"))
    log_file = log_dir / "session.jsonl"
    seen = _load_logged_ids(log_file)

    print(f"[codex-watch] watching {sessions_root}", file=sys.stderr)

    while True:
        new_entries: list[dict] = []
        for transcript in sorted(sessions_root.rglob("*.jsonl")):
            prompt_index = 0
            try:
                for item in _iter_transcript_prompts(transcript):
                    prompt_index += 1
                    entry_id = _entry_id(item["session_id"], item["turn_id"], prompt_index)
                    if entry_id in seen:
                        continue
                    item["entry_id"] = entry_id
                    seen.add(entry_id)
                    new_entries.append(item)
            except Exception:
                continue

        if new_entries:
            _append_entries(log_file, new_entries)
            print(f"[codex-watch] logged {len(new_entries)} prompt(s)", file=sys.stderr)

        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
