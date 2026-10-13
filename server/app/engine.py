"""Motor de transcripción. Pieza intercambiable: hoy faster-whisper en el server,
mañana en el dispositivo o en la nube (modo invitado) con la misma interfaz."""
from __future__ import annotations

import threading
import time
from dataclasses import dataclass, field

from . import config


@dataclass
class Segment:
    start: float
    end: float
    text: str


@dataclass
class Result:
    text: str
    language: str
    duration: float
    processing_s: float
    segments: list[Segment] = field(default_factory=list)


class Engine:
    name = "base"

    def transcribe(self, path: str, language: str | None = None) -> Result:  # pragma: no cover
        raise NotImplementedError


class WhisperEngine(Engine):
    name = "faster-whisper"

    def __init__(self) -> None:
        from faster_whisper import WhisperModel

        device = config.WHISPER_DEVICE
        if device == "auto":
            device = "cuda" if _cuda_available() else "cpu"
        compute = config.WHISPER_COMPUTE
        if compute == "auto":
            compute = "float16" if device == "cuda" else "int8"

        self.device, self.compute = device, compute
        self.model = WhisperModel(config.WHISPER_MODEL, device=device, compute_type=compute)
        # Un solo modelo en memoria: serializamos para no reventar RAM/VRAM
        self._lock = threading.Lock()

    def transcribe(self, path: str, language: str | None = None) -> Result:
        t0 = time.perf_counter()
        with self._lock:
            segs, info = self.model.transcribe(
                path,
                language=language or config.LANGUAGE or None,
                vad_filter=True,  # salta silencios
                beam_size=5,
            )
            segments = [Segment(round(s.start, 2), round(s.end, 2), s.text.strip()) for s in segs]
        return Result(
            text=" ".join(s.text for s in segments).strip(),
            language=info.language,
            duration=round(info.duration, 1),
            processing_s=round(time.perf_counter() - t0, 1),
            segments=segments,
        )


class FakeEngine(Engine):
    """Para probar la API sin modelo."""

    name = "fake"
    device = compute = "none"

    def transcribe(self, path: str, language: str | None = None) -> Result:
        segs = [Segment(0.0, 2.5, "Hola, esta es una prueba."), Segment(2.5, 5.0, "Segunda frase.")]
        return Result(" ".join(s.text for s in segs), language or "es", 5.0, 0.0, segs)


def _cuda_available() -> bool:
    try:
        import ctranslate2

        return ctranslate2.get_cuda_device_count() > 0
    except Exception:
        return False


def build_engine() -> Engine:
    return FakeEngine() if config.ENGINE == "fake" else WhisperEngine()
