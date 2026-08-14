import io
import wave
from pathlib import Path

from piper import PiperVoice

VOICE_DIR = Path(__file__).resolve().parent.parent / "voices"

VOICE_MODELS: dict[str, str] = {
    "vi": "vi_VN-vais1000-medium.onnx",
    "en": "en_US-lessac-medium.onnx",
}

_voice_cache: dict[str, PiperVoice] = {}


def _load_voice(language: str) -> PiperVoice:
    if language not in VOICE_MODELS:
        raise ValueError(f"Unsupported language: {language}")
    if language not in _voice_cache:
        model_path = VOICE_DIR / VOICE_MODELS[language]
        _voice_cache[language] = PiperVoice.load(str(model_path))
    return _voice_cache[language]


def synthesize(text: str, language: str) -> bytes:
    voice = _load_voice(language)
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        voice.synthesize_wav(text, wav_file)
    return buffer.getvalue()
