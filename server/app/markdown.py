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


def _excerpt(result: Result, sec: float, words: int = 25) -> str:
    """Lo que se decía justo antes de marcar ⭐ (uno marca después de oír algo importante)."""
    near = [x.text for x in result.segments if x.end >= sec - 15 and x.start <= sec + 2]
    text = " ".join(near).split()
    return " ".join(text[-words:]) if text else "…"


def build(
    result: Result,
    title: str,
    when: datetime,
    source: str = "",
    materia: str = "",
    marcas: list[float] | None = None,
) -> str:
    marcas = sorted(marcas or [])
    tags = ["amanuense", "transcripcion"] + ([slugify(materia)] if materia else [])
    lines = [
        "---",
        "tipo: transcripcion",
        f'titulo: "{title}"',
        f"creado: {when:%Y-%m-%d}",
        f"fecha: {when:%Y-%m-%d %H:%M}",
        f"duracion: {_ts(result.duration)}",
        f"idioma: {result.language}",
        f"origen: {source or 'grabacion'}",
        *([f'materia: "{materia}"'] if materia else []),
        f"tags: [{', '.join(tags)}]",
        *([f"favoritos: {len(marcas)}"] if marcas else []),
        "estado: literal",
        "---",
        "",
        f"# {title}",
        "",
        *([f"📚 [[{materia}]]", ""] if materia else []),
    ]
    if marcas:
        lines += ["## ⭐ Momentos importantes", ""]
        lines += [f"- **[{_ts(m)}]** {_excerpt(result, m)}" for m in marcas]
        lines += [""]
    lines += ["## Transcripción", ""]

    # Agrupa segmentos en párrafos de ~60 s para que se lea bien; ⭐ si tiene una marca
    def flush(para: list[str], start: float, end: float) -> None:
        star = "⭐ " if any(start <= m <= end + 2 for m in marcas) else ""
        lines.extend([f"{star}**[{_ts(start)}]** " + " ".join(para), ""])

    para, para_start = [], None
    for s in result.segments:
        if para_start is None:
            para_start = s.start
        para.append(s.text)
        if s.end - para_start >= 60:
            flush(para, para_start, s.end)
            para, para_start = [], None
    if para:
        flush(para, para_start or 0, result.segments[-1].end)
    if not result.segments:
        lines += ["_(No se detectó voz)_", ""]
    lines += ["---", f"_Transcrito con {branding.NAME} · by wilo ({branding.AUTHOR})_", ""]
    return "\n".join(lines)
