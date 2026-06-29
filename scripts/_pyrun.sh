#!/usr/bin/env bash
# Cross-platform Python launcher for AI log hooks.
# Designed to be called as:
#   bash scripts/_pyrun.sh <script> [args...]
#
# Exits 0 silently if no usable Python is found so hooks never block the AI tool.
set -u

PY=""

# Prefer the project's virtual environment.
if [ -x ".venv/Scripts/python.exe" ]; then
  PY=".venv/Scripts/python.exe"
elif [ -x ".venv/bin/python" ]; then
  PY=".venv/bin/python"
elif command -v python >/dev/null 2>&1; then
  PY="python"
elif command -v py >/dev/null 2>&1; then
  PY="py -3"
elif command -v python3 >/dev/null 2>&1; then
  # On Windows, python3 may be a Microsoft Store alias.
  if python3 --version >/dev/null 2>&1; then
    PY="python3"
  fi
fi

if [ -z "$PY" ]; then
  shopt -s nullglob 2>/dev/null || true

  for cand in \
    /c/Users/*/AppData/Local/Programs/Python/Python*/python.exe \
    "/c/Program Files/Python"*/python.exe \
    "/c/Program Files (x86)/Python"*/python.exe \
    /c/Python*/python.exe; do
    if [ -x "$cand" ]; then
      PY="$cand"
      break
    fi
  done

  shopt -u nullglob 2>/dev/null || true
fi

[ -n "$PY" ] || exit 0

# shellcheck disable=SC2086
exec $PY "$@"