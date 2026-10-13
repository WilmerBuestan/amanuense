"""Configuración por variables de entorno (archivo .env)."""
import os
from pathlib import Path

try:
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
except ImportError:
    pass


def _env(name: str, default: str) -> str:
    return os.getenv(name, default).strip()


# Modelo Whisper: tiny | base | small | medium | large-v3 | large-v3-turbo
WHISPER_MODEL = _env("WHISPER_MODEL", "small")
# auto | cpu | cuda
WHISPER_DEVICE = _env("WHISPER_DEVICE", "auto")
# int8 (CPU) | float16 (GPU) | int8_float16 (GPU con poca VRAM) | auto
WHISPER_COMPUTE = _env("WHISPER_COMPUTE", "auto")
LANGUAGE = _env("LANGUAGE", "es")

# Si se define, se exige el header X-API-Key en /transcribe*
API_KEY = _env("API_KEY", "")

MAX_UPLOAD_MB = int(_env("MAX_UPLOAD_MB", "200"))

# "fake" solo para pruebas sin descargar modelo
ENGINE = _env("ENGINE", "whisper")
