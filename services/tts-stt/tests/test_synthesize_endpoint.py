from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app import tts
from app.main import app

client = TestClient(app)


def _fake_synthesize_wav(text, wav_file):
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(22050)
    wav_file.writeframes(b"\x00\x00")


def _mock_piper_voice():
    instance = MagicMock()
    instance.synthesize_wav.side_effect = _fake_synthesize_wav
    return instance


def test_synthesize_without_voice_field_still_works():
    tts._voice_cache.clear()
    with patch("app.tts.PiperVoice") as mock_cls:
        mock_cls.load.return_value = _mock_piper_voice()
        response = client.post("/synthesize", json={"text": "hello", "language": "en"})
    assert response.status_code == 200
    assert response.headers["content-type"] == "audio/wav"


def test_synthesize_with_valid_voice_field():
    tts._voice_cache.clear()
    with patch("app.tts.PiperVoice") as mock_cls:
        mock_cls.load.return_value = _mock_piper_voice()
        response = client.post(
            "/synthesize", json={"text": "hello", "language": "en", "voice": "male1"}
        )
    assert response.status_code == 200


def test_synthesize_with_invalid_voice_field_rejected():
    # No PiperVoice mocking needed — the endpoint must reject this before
    # ever calling tts.synthesize.
    response = client.post(
        "/synthesize", json={"text": "hello", "language": "en", "voice": "bogus"}
    )
    assert response.status_code == 400
