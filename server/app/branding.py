"""Marca Amanuense: banner y firma de Wilo (archivos banner.txt y firma.txt)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = "Amanuense"
AUTHOR = "Wilmer Buestan"


def _read(name: str) -> str:
    try:
        return (ROOT / name).read_text(encoding="utf-8").rstrip("\n")
    except OSError:
        return ""


BANNER = _read("banner.txt")
FIRMA = _read("firma.txt")
