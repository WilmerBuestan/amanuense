"""Amanuense — Server transcriptor (F0). by wilo"""
from __future__ import annotations

import os
import secrets
import tempfile
from contextlib import asynccontextmanager
from dataclasses import asdict
from datetime import datetime
from pathlib import Path

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import HTMLResponse, Response

from . import branding, config, markdown
from .engine import build_engine

STATIC = Path(__file__).resolve().parent.parent / "static"
state: dict = {}


@asynccontextmanager
async def lifespan(_: FastAPI):
    print(f"\n{branding.BANNER}\n{branding.FIRMA}\n", flush=True)
    state["engine"] = await run_in_threadpool(build_engine)
    print(f"{branding.NAME} listo · modelo {config.WHISPER_MODEL}", flush=True)
    yield
    state.clear()


app = FastAPI(title="Amanuense - Transcriptor", version="0.1.0", lifespan=lifespan)


def check_key(x_api_key: str | None = Header(default=None)) -> None:
    if config.API_KEY and not secrets.compare_digest(x_api_key or "", config.API_KEY):
        raise HTTPException(401, "API key inválida")


async def _save_upload(audio: UploadFile) -> str:
    suffix = Path(audio.filename or "").suffix or ".wav"
    limit = config.MAX_UPLOAD_MB * 1024 * 1024
    size = 0
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        while chunk := await audio.read(1024 * 1024):
            size += len(chunk)
            if size > limit:
                tmp.close()
                os.remove(tmp.name)
                raise HTTPException(413, f"Archivo supera {config.MAX_UPLOAD_MB} MB")
            tmp.write(chunk)
    if size == 0:
        os.remove(tmp.name)
        raise HTTPException(400, "Archivo vacío")
    return tmp.name


async def _run(audio: UploadFile, language: str | None):
    path = await _save_upload(audio)
    try:
        return await run_in_threadpool(state["engine"].transcribe, path, language)
    except HTTPException:
        raise
    except Exception as e:  # audio corrupto, formato raro, etc.
        raise HTTPException(422, f"No se pudo transcribir: {e}") from e
    finally:
        os.remove(path)


@app.get("/")
def index():
    html = (STATIC / "index.html").read_text(encoding="utf-8")
    return HTMLResponse(html.replace("{{BANNER}}", branding.BANNER).replace("{{FIRMA}}", branding.FIRMA))


@app.get("/health")
def health():
    eng = state.get("engine")
    return {
        "status": "ok" if eng else "loading",
        "engine": getattr(eng, "name", None),
        "model": config.WHISPER_MODEL,
        "device": getattr(eng, "device", None),
        "compute": getattr(eng, "compute", None),
        "auth": bool(config.API_KEY),
    }


@app.post("/transcribe", dependencies=[Depends(check_key)])
async def transcribe(audio: UploadFile = File(...), language: str | None = Form(None)):
    """JSON con texto y segmentos. Lo usará la app Flutter."""
    return asdict(await _run(audio, language))


@app.post("/transcribe/md", dependencies=[Depends(check_key)])
async def transcribe_md(
    audio: UploadFile = File(...),
    title: str | None = Form(None),
    language: str | None = Form(None),
):
    """Devuelve directamente la nota .md descargable."""
    result = await _run(audio, language)
    now = datetime.now()
    title = (title or "").strip() or Path(audio.filename or "nota").stem
    md = markdown.build(result, title, now, source=audio.filename or "")
    name = markdown.filename(title, now)
    return Response(
        md,
        media_type="text/markdown; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{name}"'},
    )
