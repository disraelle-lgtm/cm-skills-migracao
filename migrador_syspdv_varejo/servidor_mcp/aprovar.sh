#!/usr/bin/env bash
cd "$(dirname "$0")"
PY=../.venv/bin/python; [ -x "$PY" ] || PY=python3
exec "$PY" aprovar_migracao.py "$@"
