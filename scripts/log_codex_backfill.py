#!/usr/bin/env python3
"""
Backfill Codex user prompts from ~/.codex/sessions into .ai-log/session.jsonl.

Useful when the live Codex hook was not running but Codex local transcripts
still exist.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

VN_TZ = timezone(timedelta(hours=7))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


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


def _normalize_path(path: str) -> str:
    return path.strip().lower().replace("/", "\\").rstrip("\\")


def _matches_repo(path: str, repo_root: str) -> bool:
    path_n = _normalize_path(path)
    repo_n = _normalize_path(repo_root)
    if not path_n or not repo_n:
        return False
    return (
        path_n == repo_n
        or path_n.startswith(repo_n + "\\")
        or repo_n.startswith(path_n + "\\")
    )


def _parse_time(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _to_vn_iso(value: str) -> str:
    dt = _parse_time(value)
    if not dt:
        return datetime.now(VN_TZ).isoformat()
    return dt.astimezone(VN_TZ).isoformat()


def _parse_since(value: str) -> datetime:
    dt = _parse_time(value)
    if dt:
        return dt if dt.tzinfo else dt.replace(tzinfo=VN_TZ)
    try:
        return datetime.strptime(value, "%Y-%m-%d").replace(tzinfo=VN_TZ)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            "Use YYYY-MM-DD or an ISO datetime for --since."
        ) from exc


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


def _codex_sessions_root(arg: str | None) -> Path:
    if arg:
        return Path(arg).expanduser()
    env_home = os.environ.get("CODEX_HOME")
    if env_home:
        return Path(env_home).expanduser() / "sessions"
    return Path.home() / ".codex" / "sessions"


def _iter_jsonl(path: Path):
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def _entry_id(session_id: str, turn_id: str, index: int) -> str:
    suffix = turn_id or f"{index:05d}"
    return f"codex-{session_id}-{suffix}"


def _iter_codex_prompts(
    sessions_root: Path,
    cutoff: datetime | None,
    repo_root: str,
    use_repo_filter: bool,
):
    for path in sorted(sessions_root.rglob("*.jsonl")):
        session_id = ""
        session_cwd = ""
        thread_source = ""
        current_turn_id = ""
        current_model = ""
        prompt_index = 0
        session_allowed: bool | None = None

        for entry in _iter_jsonl(path):
            entry_type = entry.get("type")
            payload: dict[str, Any] = entry.get("payload") or {}

            if entry_type == "session_meta":
                session_id = (
                    payload.get("session_id")
                    or payload.get("id")
                    or session_id
                )
                session_cwd = payload.get("cwd") or session_cwd
                thread_source = payload.get("thread_source") or thread_source
                is_user_thread = thread_source in ("", "user")
                repo_ok = (
                    True
                    if not use_repo_filter
                    else _matches_repo(session_cwd, repo_root)
                )
                session_allowed = is_user_thread and repo_ok
                continue

            if entry_type == "turn_context":
                current_turn_id = payload.get("turn_id") or current_turn_id
                current_model = payload.get("model") or current_model
                if not session_cwd:
                    session_cwd = payload.get("cwd") or ""
                continue

            if (
                entry_type != "event_msg"
                or payload.get("type") != "user_message"
            ):
                continue

            if session_allowed is False:
                continue

            ts = entry.get("timestamp") or ""
            ts_dt = _parse_time(ts)
            if cutoff and ts_dt and ts_dt < cutoff:
                continue

            prompt = (payload.get("message") or "").strip()
            if len(prompt) < 2:
                continue

            prompt_index += 1
            yield {
                "timestamp": ts,
                "session_id": session_id or path.stem,
                "turn_id": current_turn_id,
                "model": current_model,
                "prompt": prompt,
                "entry_id": _entry_id(session_id or path.stem, current_turn_id, prompt_index),
                "transcript_path": str(path),
            }


def build_entry(msg: dict[str, str], repo: str, branch: str, commit: str,
                student: str) -> dict[str, str]:
    return {
        "ts": _to_vn_iso(msg["timestamp"]),
        "tool": "codex",
        "event": "UserPromptSubmit",
        "entry_id": msg["entry_id"],
        "session_id": msg["session_id"],
        "model": msg["model"],
        "repo": repo,
        "branch": branch,
        "commit": commit,
        "student": student,
        "prompt": msg["prompt"][:1000],
        "response_summary": "",
        "turn_id": msg["turn_id"],
        "transcript_path": msg["transcript_path"],
        "source": "codex-session-backfill",
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Backfill Codex prompts into .ai-log/session.jsonl."
    )
    parser.add_argument("--since", type=_parse_since,
                        help="Only include prompts since YYYY-MM-DD/ISO time.")
    parser.add_argument("--hours", type=int, default=24,
                        help="Window in hours when --since/--all are omitted.")
    parser.add_argument("--all", action="store_true",
                        help="Ignore the time window.")
    parser.add_argument("--codex-sessions",
                        help="Path to Codex sessions directory.")
    parser.add_argument("--no-repo-filter", action="store_true",
                        help="Don't filter sessions by current repo cwd.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be logged, don't write.")
    args = parser.parse_args()

    sessions_root = _codex_sessions_root(args.codex_sessions)
    if not sessions_root.exists():
        print(f"[codex-backfill] No sessions directory: {sessions_root}",
              file=sys.stderr)
        sys.exit(0)

    cutoff = None
    if args.since:
        cutoff = args.since
    elif not args.all:
        cutoff = datetime.now(VN_TZ) - timedelta(hours=args.hours)

    log_dir = Path(os.environ.get("AI_LOG_DIR", ".ai-log"))
    log_dir.mkdir(exist_ok=True)
    log_file = log_dir / "session.jsonl"
    logged_ids = _load_logged_ids(log_file)

    repo = _repo_name()
    branch = git(["rev-parse", "--abbrev-ref", "HEAD"])
    commit = git(["rev-parse", "--short", "HEAD"])
    student = git(["config", "user.email"]) or os.environ.get(
        "USERNAME", os.environ.get("USER", "unknown")
    )

    new_entries = []
    for msg in _iter_codex_prompts(
        sessions_root,
        cutoff,
        str(Path.cwd()),
        not args.no_repo_filter,
    ):
        entry = build_entry(msg, repo, branch, commit, student)
        if entry["entry_id"] in logged_ids:
            continue
        logged_ids.add(entry["entry_id"])
        new_entries.append(entry)

    if args.dry_run:
        print(f"[codex-backfill] DRY RUN: {len(new_entries)} new prompt(s)")
        for entry in new_entries[:30]:
            preview = entry["prompt"].replace("\n", " ")[:100]
            print(f"  [{entry['ts'][:19]}] {preview}")
        if len(new_entries) > 30:
            print(f"  ... {len(new_entries) - 30} more")
        return

    if not new_entries:
        print("[codex-backfill] No new prompts.", file=sys.stderr)
        return

    with open(log_file, "a", encoding="utf-8") as f:
        for entry in new_entries:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    print(f"[codex-backfill] Logged {len(new_entries)} prompt(s).",
          file=sys.stderr)


if __name__ == "__main__":
    main()
