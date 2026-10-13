"""Genera la nota .md (texto literal + marcas de tiempo)."""
from __future__ import annotations

import re
import unicodedata
from datetime import datetime

from . import branding
from .engine import Result


def _ts(sec: float) -> str:
    sec = int(sec)
    h, rem = divmod(sec, 3600)
    m, s = divmod(rem, 60)
    return f"{h:d}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


def slugify(text: str, max_len: int = 50) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    text = re.sub(r"[^\w\s-]", "", text).strip().lower()
    return re.sub(r"[\s_-]+", "-", text)[:max_len].strip("-") or "nota"


def filename(title: str, when: datetime) -> str:
    return f"{when:%Y-%m-%d_%H%M}_{slugify(title)}.md"


def build(result: Result, title: str, when: datetime, source: str = "") -> str:
    lines = [
        "---",
        f'titulo: "{title}"',
        f"fecha: {when:%Y-%m-%d %H:%M}",
        f"duracion: {_ts(result.duration)}",
        f"idioma: {result.language}",
        f"origen: {source or 'grabacion'}",
        "tags: [amanuense, transcripcion]",
        "estado: literal",
        "---",
        "",
        f"# {title}",
        "",
        "## Transcripción",
        "",
    ]
    # Agrupa segmentos en párrafos de ~60 s para que se lea bien
    para, para_start = [], None
    for s in result.segments:
        if para_start is None:
            para_start = s.start
        para.append(s.text)
        if s.end - para_start >= 60:
            lines += [f"**[{_ts(para_start)}]** " + " ".join(para), ""]
            para, para_start = [], None
    if para:
        lines += [f"**[{_ts(para_start or 0)}]** " + " ".join(para), ""]
    if not result.segments:
        lines += ["_(No se detectó voz)_", ""]
    lines += ["---", f"_Transcrito con {branding.NAME} · by wilo ({branding.AUTHOR})_", ""]
    return "\n".join(lines)
