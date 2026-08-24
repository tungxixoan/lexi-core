import io
import wave
from pathlib import Path

from piper import PiperVoice

VOICE_DIR = Path(__file__).resolve().parent.parent / "voices"

VOICE_MODELS: dict[str, dict[str, str]] = {
    "vi": {"default": "vi_VN-vais1000-medium.onnx"},
    "en": {
        "default": "en_US-lessac-medium.onnx",
        "female1": "en_US-lessac-medium.onnx",
        "female2": "en_US-hfc_female-medium.onnx",
        "male1": "en_US-hfc_male-medium.onnx",
        "male2": "en_US-norman-medium.onnx",
    },
}

_voice_cache: dict[tuple[str, str], PiperVoice] = {}


def _load_voice(language: str, voice: str) -> PiperVoice:
    if language not in VOICE_MODELS:
        raise ValueError(f"Unsupported language: {language}")
    models_for_language = VOICE_MODELS[language]
    if voice not in models_for_language:
        if len(models_for_language) == 1:
            # This language only has "default" — a caller passing an
            # English-style voice id (e.g. "vi" + voice="male1") is
            # harmless, not a bug; fall back rather than raise.
            voice = "default"
        else:
            raise ValueError(f"Unsupported voice '{voice}' for language '{language}'.")
    cache_key = (language, voice)
    if cache_key not in _voice_cache:
        model_path = VOICE_DIR / models_for_language[voice]
        _voice_cache[cache_key] = PiperVoice.load(str(model_path))
    return _voice_cache[cache_key]


def synthesize(text: str, language: str, voice: str = "default") -> bytes:
    piper_voice = _load_voice(language, voice)
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        piper_voice.synthesize_wav(text, wav_file)
    return buffer.getvalue()
