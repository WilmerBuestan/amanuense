#!/usr/bin/env bash
# Arranca el server. Lee HOST/PORT de .env
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && . ./.env; set +a

# Si hay librerías CUDA instaladas por pip, las agrega al path
NV=$(.venv/bin/python - <<'PY' 2>/dev/null || true
import os, importlib.util
paths=[]
for m in ("nvidia.cublas.lib","nvidia.cudnn.lib"):
    try:
        s=importlib.util.find_spec(m)
        if s and s.submodule_search_locations: paths+=list(s.submodule_search_locations)
    except Exception: pass
print(":".join(paths))
PY
)
[ -n "$NV" ] && export LD_LIBRARY_PATH="$NV:${LD_LIBRARY_PATH:-}"

exec .venv/bin/uvicorn app.main:app --host "${HOST:-0.0.0.0}" --port "${PORT:-8000}"
