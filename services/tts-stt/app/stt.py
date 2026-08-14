import tempfile
from pathlib import Path

from faster_whisper import WhisperModel

MODEL_DIR = Path(__file__).resolve().parent.parent / "models" / "whisper"

_model: WhisperModel | None = None


def _load_model() -> WhisperModel:
    global _model
    if _model is None:
        _model = WhisperModel(
            "base",
            device="cpu",
            compute_type="int8",
            download_root=str(MODEL_DIR),
        )
    return _model


def transcribe(audio_bytes: bytes, language: str | None = None) -> str:
    model = _load_model()
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp_file:
        tmp_file.write(audio_bytes)
        tmp_file.flush()
        segments, _info = model.transcribe(tmp_file.name, language=language, beam_size=5)
        return " ".join(segment.text.strip() for segment in segments).strip()
