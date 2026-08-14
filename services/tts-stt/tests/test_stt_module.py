import os
from unittest.mock import patch

from app import stt


class _FakeSegment:
    def __init__(self, text: str) -> None:
        self.text = text


class _FakeModel:
    def __init__(self) -> None:
        self.seen_path: str | None = None

    def transcribe(self, path: str, language=None, beam_size=5):
        self.seen_path = path
        # The temp file must exist and be readable at call time.
        assert os.path.exists(path)
        with open(path, "rb") as f:
            assert f.read() == b"fake-wav-bytes"
        return [_FakeSegment("xin"), _FakeSegment("chao")], None


def test_transcribe_writes_then_cleans_up_temp_file():
    fake_model = _FakeModel()
    with patch("app.stt._load_model", return_value=fake_model):
        result = stt.transcribe(b"fake-wav-bytes", "vi")

    assert result == "xin chao"
    assert fake_model.seen_path is not None
    # Temp file must be deleted after transcribe() returns.
    assert not os.path.exists(fake_model.seen_path)


def test_transcribe_cleans_up_temp_file_even_if_model_raises():
    class _RaisingModel:
        def __init__(self) -> None:
            self.seen_path: str | None = None

        def transcribe(self, path: str, language=None, beam_size=5):
            self.seen_path = path
            raise RuntimeError("model failure")

    raising_model = _RaisingModel()
    with patch("app.stt._load_model", return_value=raising_model):
        try:
            stt.transcribe(b"fake-wav-bytes", "vi")
            raise AssertionError("expected RuntimeError to propagate")
        except RuntimeError:
            pass

    assert raising_model.seen_path is not None
    assert not os.path.exists(raising_model.seen_path)
