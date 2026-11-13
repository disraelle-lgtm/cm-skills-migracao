#!/usr/bin/env bash
cd "$(dirname "$0")"
PY=../.venv/bin/python; [ -x "$PY" ] || { echo "Instale o migrador primeiro (linux/instalar.sh)."; exit 1; }
"$PY" -m pip install -r ../requirements.txt -r requirements.txt && { [ -f conexoes.json ] || cp conexoes.exemplo.json conexoes.json; echo "Pronto. Veja LEIA-ME-MCP.md."; }
