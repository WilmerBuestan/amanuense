"""Pruebas de la API con motor falso (no descarga modelo).
Ejecutar:  ENGINE=fake pytest -q
"""
import os

os.environ["ENGINE"] = "fake"

import pytest
from fastapi.testclient import TestClient

from app import config
from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200 and r.json()["status"] == "ok"


def test_transcribe_json(client):
    r = client.post("/transcribe", files={"audio": ("a.wav", b"RIFF....", "audio/wav")})
    assert r.status_code == 200
    body = r.json()
    assert "prueba" in body["text"] and len(body["segments"]) == 2


def test_transcribe_md(client):
    r = client.post(
        "/transcribe/md",
        files={"audio": ("clase.m4a", b"xxxx", "audio/mp4")},
        data={"title": "Clase de Ñandú & SOA"},
    )
    assert r.status_code == 200
    assert "clase-de-nandu-soa.md" in r.headers["content-disposition"]
    assert r.text.startswith("---") and "## Transcripción" in r.text and "**[00:00]**" in r.text


def test_empty_file(client):
    r = client.post("/transcribe", files={"audio": ("a.wav", b"", "audio/wav")})
    assert r.status_code == 400


def test_api_key(client, monkeypatch):
    monkeypatch.setattr(config, "API_KEY", "secreto")
    f = {"audio": ("a.wav", b"x", "audio/wav")}
    assert client.post("/transcribe", files=f).status_code == 401
    assert client.post("/transcribe", files=f, headers={"X-API-Key": "secreto"}).status_code == 200


def test_index(client):
    html = client.get("/").text
    assert "Amanuense" in html and "{{BANNER}}" not in html


def test_md_materia_y_favoritos(client):
    r = client.post(
        "/transcribe/md",
        files={"audio": ("clase.m4a", b"xxxx", "audio/mp4")},
        data={"title": "Clase", "materia": "SOA", "marcas": "3.5,x", "vocabulario": "SOA, WSDL"},
    )
    assert r.status_code == 200
    assert 'materia: "SOA"' in r.text and "tags: [amanuense, transcripcion, soa]" in r.text
    assert "## ⭐ Momentos importantes" in r.text and "**[00:03]**" in r.text
    assert "⭐ **[00:00]**" in r.text and "📚 [[SOA]]" in r.text and "tipo: transcripcion" in r.text


def test_prompt_vocabulario():
    from app.main import _prompt

    assert _prompt("SOA, WSDL\nREST") == "Vocabulario: SOA, WSDL, REST."
    assert _prompt("  ") is None
