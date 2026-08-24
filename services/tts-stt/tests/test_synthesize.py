from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_synthesize_returns_wav_audio():
    fake_audio = b"RIFF....WAVEfake"
    with patch("app.main.tts.synthesize", return_value=fake_audio) as mock_synthesize:
        response = client.post("/synthesize", json={"text": "xin chao", "language": "vi"})

    assert response.status_code == 200
    assert response.headers["content-type"] == "audio/wav"
    assert response.content == fake_audio
    mock_synthesize.assert_called_once_with("xin chao", "vi", "default")


def test_synthesize_rejects_empty_text():
    response = client.post("/synthesize", json={"text": "   ", "language": "vi"})
    assert response.status_code == 400


def test_synthesize_rejects_unsupported_language():
    response = client.post("/synthesize", json={"text": "hello", "language": "fr"})
    assert response.status_code == 400


def test_synthesize_rejects_text_over_500_characters():
    response = client.post("/synthesize", json={"text": "a" * 501, "language": "vi"})
    assert response.status_code == 400
