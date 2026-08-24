from unittest.mock import MagicMock, patch

from app import tts


def _fake_synthesize_wav(text, wav_file):
    # A real PiperVoice.synthesize_wav writes real WAV frames via the
    # wave.Wave_write object it's handed; the wave module raises on close
    # if nothing ever configured the header (channels/sample width/frame
    # rate), so the mock must set those up too, not just no-op.
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(22050)
    wav_file.writeframes(b"\x00\x00")


def _mock_piper_voice():
    instance = MagicMock()
    instance.synthesize_wav.side_effect = _fake_synthesize_wav
    return instance


def test_default_voice_resolves_to_the_lessac_model_path():
    tts._voice_cache.clear()
    with patch("app.tts.PiperVoice") as mock_cls:
        mock_cls.load.return_value = _mock_piper_voice()
        tts.synthesize("hello", "en")
        loaded_path = mock_cls.load.call_args[0][0]
        assert "lessac" in loaded_path


def test_female1_voice_resolves_to_the_same_model_as_default():
    # Regression: every existing caller (Nghe chép, etc.) never sends
    # `voice`, so the default path must resolve to the exact same model
    # file as before this change.
    tts._voice_cache.clear()
    with patch("app.tts.PiperVoice") as mock_cls:
        mock_cls.load.return_value = _mock_piper_voice()
        tts.synthesize("hello", "en", voice="female1")
        loaded_path = mock_cls.load.call_args[0][0]
        assert "lessac" in loaded_path


def test_all_four_named_voices_resolve_to_four_distinct_model_paths():
    resolved = {}
    for voice in ("male1", "male2", "female1", "female2"):
        tts._voice_cache.clear()
        with patch("app.tts.PiperVoice") as mock_cls:
            mock_cls.load.return_value = _mock_piper_voice()
            tts.synthesize("hello", "en", voice=voice)
            resolved[voice] = mock_cls.load.call_args[0][0]
    assert len(set(resolved.values())) == 4


def test_unsupported_english_voice_raises():
    tts._voice_cache.clear()
    try:
        tts.synthesize("hello", "en", voice="not-a-real-voice")
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_vietnamese_ignores_voice_param_and_falls_back_to_the_vi_model():
    # Vietnamese only ever has one voice ("default") — a "voice" value is
    # meaningless for "vi" and must not raise, just fall back.
    tts._voice_cache.clear()
    with patch("app.tts.PiperVoice") as mock_cls:
        mock_cls.load.return_value = _mock_piper_voice()
        tts.synthesize("xin chào", "vi", voice="male1")
        loaded_path = mock_cls.load.call_args[0][0]
        assert "vais1000" in loaded_path


def test_synthesize_returns_bytes():
    tts._voice_cache.clear()
    with patch("app.tts.PiperVoice") as mock_cls:
        mock_cls.load.return_value = _mock_piper_voice()
        result = tts.synthesize("hello", "en")
        assert isinstance(result, bytes)
        assert len(result) > 0
