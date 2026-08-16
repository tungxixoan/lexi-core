# STT/TTS Service (Piper + faster-whisper on Cloud Run) — React Web Plan 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Task 9 is deployment/live-infra work and must NOT be dispatched to a subagent** — do it directly with the user, mirroring React Web Plan 1's Task 08 Steps 4-8.

**Goal:** Stand up a self-hosted TTS (Piper) + STT (faster-whisper) Docker service on Cloud Run, plus three Cloud Functions `onCall` proxies (`getPronunciation` cached, `synthesizeSpeech` live/uncached, `transcribeAudio`) and the Firebase Storage pronunciation cache — the backend groundwork React Web Plan 3 (React frontend build-out) depends on for any screen that plays pronunciation or listening audio.

**Architecture:** A new top-level `services/tts-stt/` directory holds a small Python FastAPI app that wraps Piper (TTS) and faster-whisper (STT), packaged into one Docker image and deployed to Cloud Run with no public ingress (private, invoked only by Cloud Functions via same-project IAM ID-token auth). `functions/src/` gains a `services/cloudRunClient.ts` helper (mints an ID token and calls the Cloud Run service, or talks to `localhost` directly for local dev) and three new `onCall` functions reusing Plan 1's auth pattern. `getPronunciation` additionally checks/writes a content-addressable cache in Firebase Storage (`tts-cache/{word|sentence}/{language}/{voiceId}/{sha256}.wav`) before falling back to Cloud Run — this is the first Cloud Function to touch Storage (via `firebase-admin`, scoped to Storage only; Firestore stays client-only per spec §3.3, unchanged).

**Tech Stack:** Python 3.11, FastAPI, Piper (`piper-tts` pip package), faster-whisper, Docker, Google Cloud Run, Cloud Functions for Firebase 2nd gen (TypeScript, existing `functions/` codebase), `google-auth-library`, `firebase-admin` (Storage only), Firebase Storage, Vitest (TS tests), pytest (Python tests).

## Global Constraints

- **Region: `asia-southeast1`** for the Cloud Run service and every new `onCall` function — matches every existing function (`ping`, `generateContent`) and the App Hosting backend. Never default to `us-central1`.
- **Node runtime: 22** for `functions/` (already bumped post-Plan-1) — new files must not reintroduce Node 20-only syntax.
- **Auth requirement:** every new `onCall` function must check `request.auth` and throw `HttpsError("unauthenticated", ...)` first, exactly like `ping.ts`/`generateContent.ts` — no exceptions.
- **BYOK boundary is untouched by this plan** — TTS/STT are self-hosted, no third-party API key involved anywhere in this plan.
- **Firestore stays client-only.** This plan adds `firebase-admin` to `functions/` for the first time, but only for `firebase-admin/storage` — never import `firebase-admin/firestore` in any file this plan creates.
- **Cloud Run service has no public ingress** — deployed with `--no-allow-unauthenticated`; the only caller is the Cloud Functions runtime service account via a minted ID token.
- **Voices:** Vietnamese = `vi_VN-vais1000-medium`, English = `en_US-lessac-medium` (Piper, from `rhasspy/piper-voices` on Hugging Face). **STT checkpoint:** faster-whisper `base`, `device="cpu"`, `compute_type="int8"`.
- **Cache path scheme (verbatim from spec §3.4):** `tts-cache/word/{language}/{voiceId}/{hash}.wav` (no expiry) and `tts-cache/sentence/{language}/{voiceId}/{hash}.wav` (90-day Storage lifecycle rule, not covered by this plan's tasks — logged as a Console follow-up in Task 8). `hash = sha256(text.trim().normalize("NFC") + language + voiceId)`.
- **Nghe (Listening) audio is never cached** — `synthesizeSpeech` always calls Cloud Run live and never touches Storage.
- Every new TS file exports its handler function separately from the `onCall(...)` wrapper (see `ping.ts`/`generateContent.ts`) so it's testable without the Functions test SDK — follow this convention exactly.
- Every `onCall` options object sets `region`, `maxInstances`, and `timeoutSeconds` explicitly (no defaults) — same convention as `ping`/`generateContent`.

---

### Task 1: Cloud Run service skeleton (FastAPI + Docker)

**Files:**
- Create: `services/tts-stt/app/__init__.py`
- Create: `services/tts-stt/app/main.py`
- Create: `services/tts-stt/requirements.txt`
- Create: `services/tts-stt/Dockerfile`
- Create: `services/tts-stt/tests/__init__.py`
- Create: `services/tts-stt/tests/test_health.py`

**Interfaces:**
- Produces: `app.main.app` (a `FastAPI` instance), `GET /health` → `{"status": "ok"}`. Tasks 2/3 add routes to this same `app`.

- [ ] **Step 1: Write the failing test**

`services/tts-stt/tests/__init__.py` — empty file.

`services/tts-stt/tests/test_health.py`:
```python
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

- [ ] **Step 2: Set up the Python environment and run the test to verify it fails**

```bash
cd services/tts-stt
python -m venv .venv
source .venv/Scripts/activate
pip install fastapi httpx pytest
pytest tests/test_health.py -v
```
Expected: FAIL / ImportError — `app.main` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

`services/tts-stt/app/__init__.py` — empty file.

`services/tts-stt/app/main.py`:
```python
from fastapi import FastAPI

app = FastAPI(title="LexiCore TTS/STT Service")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
```

`services/tts-stt/requirements.txt`:
```
fastapi>=0.115
uvicorn[standard]>=0.32
httpx>=0.27
pytest>=8.3
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
pip install -r requirements.txt
pytest tests/test_health.py -v
```
Expected: PASS.

- [ ] **Step 5: Write the Dockerfile and smoke-test it**

`services/tts-stt/Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
```

```bash
docker build -t tts-stt:local .
docker run --rm -d -p 8080:8080 --name tts-stt-smoke tts-stt:local
curl --retry 5 --retry-delay 1 --retry-connrefused http://localhost:8080/health
docker stop tts-stt-smoke
```
Expected: `{"status":"ok"}` from curl.

- [ ] **Step 6: Commit**

```bash
git add services/tts-stt
git commit -m "feat(tts-stt): scaffold FastAPI service with health check"
```

---

### Task 2: TTS synthesis (Piper) + `/synthesize` endpoint

**Files:**
- Create: `services/tts-stt/app/tts.py`
- Modify: `services/tts-stt/app/main.py`
- Modify: `services/tts-stt/requirements.txt`
- Modify: `services/tts-stt/Dockerfile`
- Create: `services/tts-stt/tests/test_synthesize.py`

**Interfaces:**
- Consumes: `app.main.app` (Task 1).
- Produces: `app.tts.synthesize(text: str, language: str) -> bytes` (WAV bytes) — Task 9's E2E verification calls this indirectly via `POST /synthesize`. `POST /synthesize` request body `{"text": str, "language": "vi"|"en"}` → `audio/wav` bytes.

- [ ] **Step 1: Write the failing tests**

`services/tts-stt/tests/test_synthesize.py`:
```python
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
    mock_synthesize.assert_called_once_with("xin chao", "vi")


def test_synthesize_rejects_empty_text():
    response = client.post("/synthesize", json={"text": "   ", "language": "vi"})
    assert response.status_code == 400


def test_synthesize_rejects_unsupported_language():
    response = client.post("/synthesize", json={"text": "hello", "language": "fr"})
    assert response.status_code == 400
```

- [ ] **Step 2: Run to verify it fails**

```bash
pytest tests/test_synthesize.py -v
```
Expected: FAIL — `/synthesize` route does not exist (404) / `app.tts` not importable.

- [ ] **Step 3: Write the minimal implementation**

`services/tts-stt/app/tts.py`:
```python
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
```

`services/tts-stt/app/main.py` (full file):
```python
from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel

from app import tts

app = FastAPI(title="LexiCore TTS/STT Service")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


class SynthesizeRequest(BaseModel):
    text: str
    language: str


@app.post("/synthesize")
def synthesize_endpoint(request: SynthesizeRequest) -> Response:
    if not request.text.strip():
        raise HTTPException(status_code=400, detail="text must not be empty.")
    if request.language not in ("vi", "en"):
        raise HTTPException(status_code=400, detail="language must be 'vi' or 'en'.")
    audio = tts.synthesize(request.text, request.language)
    return Response(content=audio, media_type="audio/wav")
```

`services/tts-stt/requirements.txt` — add one line:
```
piper-tts>=1.3
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
pip install -r requirements.txt
pytest tests/test_synthesize.py -v
```
Expected: PASS (mocked — no real Piper model is loaded by this test run).

- [ ] **Step 5: Update the Dockerfile to download the voice models and smoke-test real synthesis**

`services/tts-stt/Dockerfile` (full file):
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p voices && \
    apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -fsSL -o voices/vi_VN-vais1000-medium.onnx \
      https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/vi_VN-vais1000-medium.onnx && \
    curl -fsSL -o voices/vi_VN-vais1000-medium.onnx.json \
      https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/vi_VN-vais1000-medium.onnx.json && \
    curl -fsSL -o voices/en_US-lessac-medium.onnx \
      https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx && \
    curl -fsSL -o voices/en_US-lessac-medium.onnx.json \
      https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json && \
    apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

COPY app ./app

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
```

```bash
docker build -t tts-stt:local .
docker run --rm -d -p 8080:8080 --name tts-stt-smoke tts-stt:local
curl --retry 5 --retry-delay 1 --retry-connrefused -X POST http://localhost:8080/synthesize \
  -H "Content-Type: application/json" -d '{"text":"xin chao ban","language":"vi"}' \
  -o /tmp/test.wav
file /tmp/test.wav
docker stop tts-stt-smoke
```
Expected: `file` reports a valid RIFF/WAVE audio file (not an error JSON body). This is the only place real Piper inference is exercised before Task 9's full deploy — listen to `/tmp/test.wav` manually if possible to confirm it's intelligible Vietnamese speech, not just a well-formed empty WAV.

- [ ] **Step 6: Commit**

```bash
git add services/tts-stt
git commit -m "feat(tts-stt): add Piper TTS synthesis and /synthesize endpoint"
```

---

### Task 3: STT transcription (faster-whisper) + `/transcribe` endpoint

**Files:**
- Create: `services/tts-stt/app/stt.py`
- Modify: `services/tts-stt/app/main.py`
- Modify: `services/tts-stt/requirements.txt`
- Modify: `services/tts-stt/Dockerfile`
- Create: `services/tts-stt/tests/test_transcribe.py`

**Interfaces:**
- Consumes: `app.main.app` (Task 1).
- Produces: `app.stt.transcribe(audio_bytes: bytes, language: str | None) -> str`. `POST /transcribe?language=vi|en` (optional query param), body = raw WAV bytes, `Content-Type: audio/wav` → `{"text": str, "language": str}`.

- [ ] **Step 1: Write the failing tests**

`services/tts-stt/tests/test_transcribe.py`:
```python
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_transcribe_returns_text():
    fake_audio = b"RIFF....fake-wav-bytes"
    with patch("app.main.stt.transcribe", return_value="xin chao ban") as mock_transcribe:
        response = client.post(
            "/transcribe?language=vi",
            content=fake_audio,
            headers={"Content-Type": "audio/wav"},
        )

    assert response.status_code == 200
    assert response.json() == {"text": "xin chao ban", "language": "vi"}
    mock_transcribe.assert_called_once_with(fake_audio, "vi")


def test_transcribe_rejects_empty_body():
    response = client.post("/transcribe", content=b"", headers={"Content-Type": "audio/wav"})
    assert response.status_code == 400


def test_transcribe_rejects_unsupported_language():
    response = client.post(
        "/transcribe?language=fr",
        content=b"fake",
        headers={"Content-Type": "audio/wav"},
    )
    assert response.status_code == 400


def test_transcribe_language_is_optional():
    with patch("app.main.stt.transcribe", return_value="hello") as mock_transcribe:
        response = client.post(
            "/transcribe",
            content=b"fake-wav-bytes",
            headers={"Content-Type": "audio/wav"},
        )

    assert response.status_code == 200
    assert response.json() == {"text": "hello", "language": "auto"}
    mock_transcribe.assert_called_once_with(b"fake-wav-bytes", None)
```

- [ ] **Step 2: Run to verify it fails**

```bash
pytest tests/test_transcribe.py -v
```
Expected: FAIL — `/transcribe` route does not exist (404).

- [ ] **Step 3: Write the minimal implementation**

`services/tts-stt/app/stt.py`:
```python
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
```

`services/tts-stt/app/main.py` (full file):
```python
from fastapi import FastAPI, HTTPException, Request, Response
from pydantic import BaseModel

from app import stt, tts

app = FastAPI(title="LexiCore TTS/STT Service")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


class SynthesizeRequest(BaseModel):
    text: str
    language: str


@app.post("/synthesize")
def synthesize_endpoint(request: SynthesizeRequest) -> Response:
    if not request.text.strip():
        raise HTTPException(status_code=400, detail="text must not be empty.")
    if request.language not in ("vi", "en"):
        raise HTTPException(status_code=400, detail="language must be 'vi' or 'en'.")
    audio = tts.synthesize(request.text, request.language)
    return Response(content=audio, media_type="audio/wav")


@app.post("/transcribe")
async def transcribe_endpoint(request: Request, language: str | None = None) -> dict[str, str]:
    if language is not None and language not in ("vi", "en"):
        raise HTTPException(status_code=400, detail="language must be 'vi' or 'en'.")
    audio_bytes = await request.body()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Request body must contain WAV audio bytes.")
    text = stt.transcribe(audio_bytes, language)
    return {"text": text, "language": language or "auto"}
```

`services/tts-stt/requirements.txt` — add one line:
```
faster-whisper>=1.1
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
pip install -r requirements.txt
pytest tests/test_transcribe.py -v
```
Expected: PASS (mocked — no real faster-whisper model is loaded by this test run).

- [ ] **Step 5: Update the Dockerfile to pre-bake the whisper model and smoke-test real transcription**

`services/tts-stt/Dockerfile` — insert this `RUN` after `COPY app ./app` and before `ENV PORT=8080`:
```dockerfile
COPY app ./app

RUN python -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cpu', compute_type='int8', download_root='models/whisper')"

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
```
(Baking the model into the image at build time means no network download happens on Cloud Run cold start.)

```bash
docker build -t tts-stt:local .
docker run --rm -d -p 8080:8080 --name tts-stt-smoke tts-stt:local
curl --retry 5 --retry-delay 1 --retry-connrefused -X POST "http://localhost:8080/transcribe?language=vi" \
  -H "Content-Type: audio/wav" --data-binary @/tmp/test.wav
docker stop tts-stt-smoke
```
(Reuses `/tmp/test.wav` produced by Task 2 Step 5's smoke test — transcribing Piper's own output is a reasonable end-to-end sanity check even before real STT audio is available.)
Expected: JSON body `{"text": "...", "language": "vi"}` with non-empty `text` roughly matching "xin chao ban".

- [ ] **Step 6: Commit**

```bash
git add services/tts-stt
git commit -m "feat(tts-stt): add faster-whisper STT and /transcribe endpoint"
```

---

### Task 4: Cloud Functions — `cloudRunClient.ts` (IAM-authenticated Cloud Run caller)

**Files:**
- Create: `functions/src/services/cloudRunClient.ts`
- Create: `functions/src/services/cloudRunClient.test.ts`
- Modify: `functions/package.json`

**Interfaces:**
- Produces: `synthesizeViaCloudRun(serviceUrl: string, text: string, language: "vi"|"en"): Promise<Buffer>`, `transcribeViaCloudRun(serviceUrl: string, audio: Buffer, language?: string): Promise<{text: string; language: string}>`, `class CloudRunCallError extends Error { status?: number }`, `toHttpsError(err: unknown, fallbackMessage: string): HttpsError`. Tasks 5/6/7 consume all four.

- [ ] **Step 1: Add dependencies**

```bash
cd functions
npm install google-auth-library
```

- [ ] **Step 2: Write the failing tests**

`functions/src/services/cloudRunClient.test.ts`:
```ts
import { afterEach, describe, expect, it, vi } from "vitest";
import { HttpsError } from "firebase-functions/v2/https";

const getIdTokenClientMock = vi.fn();

vi.mock("google-auth-library", () => ({
  GoogleAuth: vi.fn().mockImplementation(() => ({
    getIdTokenClient: getIdTokenClientMock,
  })),
}));

import {
  CloudRunCallError,
  synthesizeViaCloudRun,
  transcribeViaCloudRun,
  toHttpsError,
} from "./cloudRunClient";

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("synthesizeViaCloudRun", () => {
  it("mints an ID token and returns audio bytes for an https service URL", async () => {
    const requestMock = vi.fn().mockResolvedValue({ data: Buffer.from("wav-bytes") });
    getIdTokenClientMock.mockResolvedValue({ request: requestMock });

    const result = await synthesizeViaCloudRun("https://tts-stt-abc.a.run.app", "xin chao", "vi");

    expect(getIdTokenClientMock).toHaveBeenCalledWith("https://tts-stt-abc.a.run.app");
    expect(requestMock).toHaveBeenCalledWith(
      expect.objectContaining({
        url: "https://tts-stt-abc.a.run.app/synthesize",
        method: "POST",
        responseType: "arraybuffer",
      })
    );
    expect(result).toEqual(Buffer.from("wav-bytes"));
  });

  it("skips IAM auth for a local http service URL", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => new TextEncoder().encode("wav-bytes").buffer,
    });
    vi.stubGlobal("fetch", fetchMock);

    const result = await synthesizeViaCloudRun("http://localhost:8080", "xin chao", "vi");

    expect(getIdTokenClientMock).not.toHaveBeenCalled();
    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:8080/synthesize",
      expect.objectContaining({ method: "POST" })
    );
    expect(Buffer.from(result).toString()).toBe("wav-bytes");
  });

  it("wraps a non-2xx response as CloudRunCallError with status", async () => {
    const requestMock = vi.fn().mockRejectedValue({
      response: { status: 503 },
      message: "Service Unavailable",
    });
    getIdTokenClientMock.mockResolvedValue({ request: requestMock });

    await expect(
      synthesizeViaCloudRun("https://tts-stt-abc.a.run.app", "xin chao", "vi")
    ).rejects.toMatchObject({ status: 503 });
  });
});

describe("transcribeViaCloudRun", () => {
  it("posts audio bytes and returns the transcript JSON", async () => {
    const requestMock = vi.fn().mockResolvedValue({ data: { text: "xin chao", language: "vi" } });
    getIdTokenClientMock.mockResolvedValue({ request: requestMock });

    const result = await transcribeViaCloudRun(
      "https://tts-stt-abc.a.run.app",
      Buffer.from("wav-bytes"),
      "vi"
    );

    expect(requestMock).toHaveBeenCalledWith(
      expect.objectContaining({
        url: "https://tts-stt-abc.a.run.app/transcribe?language=vi",
        method: "POST",
      })
    );
    expect(result).toEqual({ text: "xin chao", language: "vi" });
  });
});

describe("toHttpsError", () => {
  it("passes an existing HttpsError through unchanged", () => {
    const original = new HttpsError("invalid-argument", "bad input");
    expect(toHttpsError(original, "fallback")).toBe(original);
  });

  it("maps a 503/504 CloudRunCallError to 'unavailable'", () => {
    const mapped = toHttpsError(new CloudRunCallError("boom", 503), "fallback");
    expect(mapped.code).toBe("unavailable");
  });

  it("maps any other error to 'internal' with the fallback message", () => {
    const mapped = toHttpsError(new Error("boom"), "fallback message");
    expect(mapped.code).toBe("internal");
    expect(mapped.message).toBe("fallback message");
  });
});
```

- [ ] **Step 3: Run to verify it fails**

```bash
npm test -- cloudRunClient
```
Expected: FAIL — `./cloudRunClient` does not exist.

- [ ] **Step 4: Write the minimal implementation**

`functions/src/services/cloudRunClient.ts`:
```ts
import { GoogleAuth } from "google-auth-library";
import { HttpsError } from "firebase-functions/v2/https";

const auth = new GoogleAuth();

export class CloudRunCallError extends Error {
  constructor(
    message: string,
    readonly status?: number
  ) {
    super(message);
    this.name = "CloudRunCallError";
  }
}

interface CloudRunRequestOptions {
  path: string;
  body: BodyInit | Record<string, unknown>;
  headers: Record<string, string>;
  responseType: "json" | "arraybuffer";
}

async function callCloudRun<T>(serviceUrl: string, options: CloudRunRequestOptions): Promise<T> {
  const url = `${serviceUrl}${options.path}`;
  try {
    if (serviceUrl.startsWith("http://")) {
      // Local dev against `uvicorn app.main:app` — no IAM identity token available there.
      const res = await fetch(url, {
        method: "POST",
        headers: options.headers,
        body: options.body as BodyInit,
      });
      if (!res.ok) {
        throw new CloudRunCallError(`Cloud Run service returned ${res.status}`, res.status);
      }
      return options.responseType === "arraybuffer"
        ? (Buffer.from(await res.arrayBuffer()) as unknown as T)
        : ((await res.json()) as T);
    }

    const client = await auth.getIdTokenClient(serviceUrl);
    const res = await client.request<T>({
      url,
      method: "POST",
      data: options.body,
      headers: options.headers,
      responseType: options.responseType,
    });
    return res.data;
  } catch (err) {
    if (err instanceof CloudRunCallError) {
      throw err;
    }
    const status = (err as { response?: { status?: number } })?.response?.status;
    throw new CloudRunCallError(err instanceof Error ? err.message : String(err), status);
  }
}

export async function synthesizeViaCloudRun(
  serviceUrl: string,
  text: string,
  language: "vi" | "en"
): Promise<Buffer> {
  const data = await callCloudRun<ArrayBuffer | Buffer>(serviceUrl, {
    path: "/synthesize",
    body: JSON.stringify({ text, language }),
    headers: { "Content-Type": "application/json" },
    responseType: "arraybuffer",
  });
  return Buffer.isBuffer(data) ? data : Buffer.from(data);
}

export async function transcribeViaCloudRun(
  serviceUrl: string,
  audio: Buffer,
  language?: string
): Promise<{ text: string; language: string }> {
  const query = language ? `?language=${encodeURIComponent(language)}` : "";
  return callCloudRun<{ text: string; language: string }>(serviceUrl, {
    path: `/transcribe${query}`,
    body: audio,
    headers: { "Content-Type": "audio/wav" },
    responseType: "json",
  });
}

export function toHttpsError(err: unknown, fallbackMessage: string): HttpsError {
  if (err instanceof HttpsError) {
    return err;
  }
  if (err instanceof CloudRunCallError && (err.status === 503 || err.status === 504)) {
    return new HttpsError(
      "unavailable",
      "TTS/STT service is warming up or busy. Try again in a moment."
    );
  }
  return new HttpsError("internal", fallbackMessage);
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
npm test -- cloudRunClient
```
Expected: PASS, all 6 tests.

- [ ] **Step 6: Typecheck and commit**

```bash
npm run typecheck
git add functions/src/services/cloudRunClient.ts functions/src/services/cloudRunClient.test.ts functions/package.json functions/package-lock.json
git commit -m "feat(functions): add IAM-authenticated Cloud Run client for TTS/STT"
```

---

### Task 5: Cloud Functions — `getPronunciation` (cached TTS)

**Files:**
- Create: `functions/src/services/pronunciationCache.ts`
- Create: `functions/src/services/pronunciationCache.test.ts`
- Create: `functions/src/getPronunciation.ts`
- Create: `functions/src/getPronunciation.test.ts`
- Modify: `functions/src/index.ts`
- Modify: `functions/package.json`

**Interfaces:**
- Consumes: `synthesizeViaCloudRun`, `toHttpsError` (Task 4).
- Produces: `getPronunciationHandler(request: CallableRequest<unknown>): Promise<{url: string}>`, exported `getPronunciation` onCall function. `cachePath(key): string`, `publicDownloadUrl(bucketName, path): string`, `getOrCreatePronunciation(bucket, serviceUrl, key): Promise<string>` — for reference only, not consumed by later tasks.

- [ ] **Step 1: Add dependencies**

```bash
cd functions
npm install firebase-admin
```

- [ ] **Step 2: Write the failing tests for `pronunciationCache.ts`**

`functions/src/services/pronunciationCache.test.ts`:
```ts
import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("./cloudRunClient", () => ({
  synthesizeViaCloudRun: vi.fn(),
}));

import { synthesizeViaCloudRun } from "./cloudRunClient";
import {
  cachePath,
  getOrCreatePronunciation,
  publicDownloadUrl,
  type MinimalCacheBucket,
} from "./pronunciationCache";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("cachePath", () => {
  it("is deterministic for identical text/language/voice", () => {
    const key = {
      tier: "word" as const,
      language: "vi" as const,
      voiceId: "vi_VN-vais1000-medium",
      text: "xin chào",
    };
    expect(cachePath(key)).toBe(cachePath({ ...key }));
  });

  it("differs when the text differs", () => {
    const base = {
      tier: "word" as const,
      language: "vi" as const,
      voiceId: "vi_VN-vais1000-medium",
    };
    expect(cachePath({ ...base, text: "xin chào" })).not.toBe(
      cachePath({ ...base, text: "tạm biệt" })
    );
  });

  it("ignores surrounding whitespace differences", () => {
    const base = { tier: "sentence" as const, language: "en" as const, voiceId: "en_US-lessac-medium" };
    expect(cachePath({ ...base, text: "hello world" })).toBe(
      cachePath({ ...base, text: "  hello world  " })
    );
  });

  it("nests under tier/language/voiceId", () => {
    const path = cachePath({
      tier: "word",
      language: "vi",
      voiceId: "vi_VN-vais1000-medium",
      text: "chào",
    });
    expect(path).toMatch(/^tts-cache\/word\/vi\/vi_VN-vais1000-medium\/[0-9a-f]{64}\.wav$/);
  });
});

describe("publicDownloadUrl", () => {
  it("builds a Firebase Storage download URL with an encoded path", () => {
    const url = publicDownloadUrl("lexi-core.appspot.com", "tts-cache/word/vi/x/abc.wav");
    expect(url).toBe(
      "https://firebasestorage.googleapis.com/v0/b/lexi-core.appspot.com/o/tts-cache%2Fword%2Fvi%2Fx%2Fabc.wav?alt=media"
    );
  });
});

function fakeBucket(exists: boolean) {
  const save = vi.fn().mockResolvedValue(undefined);
  const file = vi.fn().mockReturnValue({
    exists: vi.fn().mockResolvedValue([exists]),
    save,
  });
  const bucket: MinimalCacheBucket = { name: "lexi-core.appspot.com", file };
  return { bucket, file, save };
}

describe("getOrCreatePronunciation", () => {
  it("returns the cached URL without calling Cloud Run on a hit", async () => {
    const { bucket, save } = fakeBucket(true);

    const url = await getOrCreatePronunciation(bucket, "https://tts-stt.a.run.app", {
      tier: "word",
      language: "vi",
      voiceId: "vi_VN-vais1000-medium",
      text: "chào",
    });

    expect(synthesizeViaCloudRun).not.toHaveBeenCalled();
    expect(save).not.toHaveBeenCalled();
    expect(url).toContain("alt=media");
  });

  it("synthesizes and uploads on a miss", async () => {
    const { bucket, save } = fakeBucket(false);
    vi.mocked(synthesizeViaCloudRun).mockResolvedValue(Buffer.from("wav-bytes"));

    await getOrCreatePronunciation(bucket, "https://tts-stt.a.run.app", {
      tier: "sentence",
      language: "en",
      voiceId: "en_US-lessac-medium",
      text: "hello",
    });

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith("https://tts-stt.a.run.app", "hello", "en");
    expect(save).toHaveBeenCalledWith(Buffer.from("wav-bytes"), {
      metadata: { contentType: "audio/wav" },
    });
  });
});
```

- [ ] **Step 3: Run to verify it fails**

```bash
npm test -- pronunciationCache
```
Expected: FAIL — `./pronunciationCache` does not exist.

- [ ] **Step 4: Write `pronunciationCache.ts`**

`functions/src/services/pronunciationCache.ts`:
```ts
import { createHash } from "node:crypto";
import { synthesizeViaCloudRun } from "./cloudRunClient";

export type PronunciationTier = "word" | "sentence";

export interface PronunciationCacheKey {
  tier: PronunciationTier;
  language: "vi" | "en";
  voiceId: string;
  text: string;
}

export interface MinimalCacheFile {
  exists(): Promise<[boolean]>;
  save(data: Buffer, options: { metadata: { contentType: string } }): Promise<void>;
}

export interface MinimalCacheBucket {
  name: string;
  file(path: string): MinimalCacheFile;
}

function normalize(text: string): string {
  return text.trim().normalize("NFC");
}

export function cachePath({ tier, language, voiceId, text }: PronunciationCacheKey): string {
  const hash = createHash("sha256")
    .update(normalize(text) + language + voiceId)
    .digest("hex");
  return `tts-cache/${tier}/${language}/${voiceId}/${hash}.wav`;
}

export function publicDownloadUrl(bucketName: string, path: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(path)}?alt=media`;
}

export async function getOrCreatePronunciation(
  bucket: MinimalCacheBucket,
  serviceUrl: string,
  key: PronunciationCacheKey
): Promise<string> {
  const path = cachePath(key);
  const file = bucket.file(path);
  const [exists] = await file.exists();
  if (!exists) {
    const audio = await synthesizeViaCloudRun(serviceUrl, key.text, key.language);
    await file.save(audio, { metadata: { contentType: "audio/wav" } });
  }
  return publicDownloadUrl(bucket.name, path);
}
```

- [ ] **Step 5: Run to verify `pronunciationCache.ts` tests pass**

```bash
npm test -- pronunciationCache
```
Expected: PASS, all 7 tests.

- [ ] **Step 6: Write the failing tests for `getPronunciation.ts`**

`functions/src/getPronunciation.test.ts`:
```ts
import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";

vi.mock("firebase-admin/app", () => ({ getApps: () => [{}], initializeApp: vi.fn() }));
vi.mock("firebase-admin/storage", () => ({
  getStorage: vi.fn().mockReturnValue({ bucket: () => ({ name: "lexi-core.appspot.com" }) }),
}));
vi.mock("./services/pronunciationCache", () => ({
  getOrCreatePronunciation: vi.fn(),
}));

import { getOrCreatePronunciation } from "./services/pronunciationCache";
import { getPronunciationHandler } from "./getPronunciation";

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
});

function makeRequest(data: unknown, authed = true): CallableRequest<unknown> {
  return {
    auth: authed ? { uid: "user-123" } : undefined,
    data,
  } as CallableRequest<unknown>;
}

describe("getPronunciationHandler", () => {
  it("throws unauthenticated when there is no auth context", async () => {
    await expect(
      getPronunciationHandler(makeRequest({ text: "a", language: "vi", tier: "word" }, false))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("throws invalid-argument for a malformed payload", async () => {
    await expect(
      getPronunciationHandler(makeRequest({ text: "", language: "vi", tier: "word" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws failed-precondition when TTS_STT_SERVICE_URL is unset", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "");
    await expect(
      getPronunciationHandler(makeRequest({ text: "chào", language: "vi", tier: "word" }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("returns the cache URL for a valid request", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(getOrCreatePronunciation).mockResolvedValue(
      "https://firebasestorage.googleapis.com/x?alt=media"
    );

    const result = await getPronunciationHandler(
      makeRequest({ text: "chào", language: "vi", tier: "word" })
    );

    expect(getOrCreatePronunciation).toHaveBeenCalledWith(
      { name: "lexi-core.appspot.com" },
      "https://tts-stt.a.run.app",
      { tier: "word", language: "vi", voiceId: "vi_VN-vais1000-medium", text: "chào" }
    );
    expect(result).toEqual({ url: "https://firebasestorage.googleapis.com/x?alt=media" });
  });
});
```

- [ ] **Step 7: Run to verify it fails**

```bash
npm test -- getPronunciation
```
Expected: FAIL — `./getPronunciation` does not exist.

- [ ] **Step 8: Write `getPronunciation.ts`**

`functions/src/getPronunciation.ts`:
```ts
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { getApps, initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { toHttpsError } from "./services/cloudRunClient";
import { getOrCreatePronunciation, type PronunciationTier } from "./services/pronunciationCache";

if (getApps().length === 0) {
  initializeApp();
}

const VOICE_IDS: Record<"vi" | "en", string> = {
  vi: "vi_VN-vais1000-medium",
  en: "en_US-lessac-medium",
};

export interface GetPronunciationRequest {
  text: string;
  language: "vi" | "en";
  tier: PronunciationTier;
}

function isGetPronunciationRequest(data: unknown): data is GetPronunciationRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    typeof d.text === "string" &&
    d.text.trim().length > 0 &&
    (d.language === "vi" || d.language === "en") &&
    (d.tier === "word" || d.tier === "sentence")
  );
}

export async function getPronunciationHandler(
  request: CallableRequest<unknown>
): Promise<{ url: string }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isGetPronunciationRequest(request.data)) {
    throw new HttpsError(
      "invalid-argument",
      "Expected { text, language: 'vi'|'en', tier: 'word'|'sentence' }."
    );
  }
  const serviceUrl = process.env.TTS_STT_SERVICE_URL ?? "";
  if (!serviceUrl) {
    throw new HttpsError("failed-precondition", "TTS/STT service URL is not configured.");
  }

  const { text, language, tier } = request.data;

  try {
    const url = await getOrCreatePronunciation(getStorage().bucket(), serviceUrl, {
      tier,
      language,
      voiceId: VOICE_IDS[language],
      text,
    });
    return { url };
  } catch (err) {
    throw toHttpsError(err, "Pronunciation generation failed. Please try again.");
  }
}

export const getPronunciation = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 30 },
  getPronunciationHandler
);
```

- [ ] **Step 9: Run to verify it passes, wire the export, typecheck**

```bash
npm test -- getPronunciation
```
Expected: PASS, all 4 tests.

`functions/src/index.ts` (full file):
```ts
export { ping } from "./ping";
export { generateContent } from "./generateContent";
export { getPronunciation } from "./getPronunciation";
```

```bash
npm run typecheck
```

- [ ] **Step 10: Commit**

```bash
git add functions/src/services/pronunciationCache.ts functions/src/services/pronunciationCache.test.ts functions/src/getPronunciation.ts functions/src/getPronunciation.test.ts functions/src/index.ts functions/package.json functions/package-lock.json
git commit -m "feat(functions): add getPronunciation onCall with Firebase Storage TTS cache"
```

---

### Task 6: Cloud Functions — `synthesizeSpeech` (live, uncached TTS)

**Files:**
- Create: `functions/src/synthesizeSpeech.ts`
- Create: `functions/src/synthesizeSpeech.test.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: `synthesizeViaCloudRun`, `toHttpsError` (Task 4).
- Produces: `synthesizeSpeechHandler(request): Promise<{audioBase64: string}>`, exported `synthesizeSpeech` onCall function.

- [ ] **Step 1: Write the failing tests**

`functions/src/synthesizeSpeech.test.ts`:
```ts
import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";

vi.mock("./services/cloudRunClient", async () => {
  const actual = await vi.importActual<typeof import("./services/cloudRunClient")>(
    "./services/cloudRunClient"
  );
  return { ...actual, synthesizeViaCloudRun: vi.fn() };
});

import { synthesizeViaCloudRun } from "./services/cloudRunClient";
import { synthesizeSpeechHandler } from "./synthesizeSpeech";

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
});

function makeRequest(data: unknown, authed = true): CallableRequest<unknown> {
  return {
    auth: authed ? { uid: "user-123" } : undefined,
    data,
  } as CallableRequest<unknown>;
}

describe("synthesizeSpeechHandler", () => {
  it("throws unauthenticated when there is no auth context", async () => {
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }, false))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("throws invalid-argument for a malformed payload", async () => {
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "", language: "vi" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws failed-precondition when TTS_STT_SERVICE_URL is unset", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "");
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("returns base64 audio for a valid request", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockResolvedValue(Buffer.from("wav-bytes"));

    const result = await synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }));

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith("https://tts-stt.a.run.app", "hi", "vi");
    expect(result).toEqual({ audioBase64: Buffer.from("wav-bytes").toString("base64") });
  });

  it("maps a Cloud Run failure to HttpsError", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockRejectedValue(new Error("boom"));

    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }))
    ).rejects.toMatchObject({ code: "internal" });
  });
});
```

- [ ] **Step 2: Run to verify it fails**

```bash
npm test -- synthesizeSpeech
```
Expected: FAIL — `./synthesizeSpeech` does not exist.

- [ ] **Step 3: Write the implementation**

`functions/src/synthesizeSpeech.ts`:
```ts
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { synthesizeViaCloudRun, toHttpsError } from "./services/cloudRunClient";

export interface SynthesizeSpeechRequest {
  text: string;
  language: "vi" | "en";
}

function isSynthesizeSpeechRequest(data: unknown): data is SynthesizeSpeechRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    typeof d.text === "string" &&
    d.text.trim().length > 0 &&
    (d.language === "vi" || d.language === "en")
  );
}

export async function synthesizeSpeechHandler(
  request: CallableRequest<unknown>
): Promise<{ audioBase64: string }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isSynthesizeSpeechRequest(request.data)) {
    throw new HttpsError("invalid-argument", "Expected { text, language: 'vi'|'en' }.");
  }
  const serviceUrl = process.env.TTS_STT_SERVICE_URL ?? "";
  if (!serviceUrl) {
    throw new HttpsError("failed-precondition", "TTS/STT service URL is not configured.");
  }

  try {
    const audio = await synthesizeViaCloudRun(serviceUrl, request.data.text, request.data.language);
    return { audioBase64: audio.toString("base64") };
  } catch (err) {
    throw toHttpsError(err, "Speech synthesis failed. Please try again.");
  }
}

export const synthesizeSpeech = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 60 },
  synthesizeSpeechHandler
);
```

- [ ] **Step 4: Run to verify it passes, wire the export, typecheck**

```bash
npm test -- synthesizeSpeech
```
Expected: PASS, all 5 tests.

`functions/src/index.ts` (full file):
```ts
export { ping } from "./ping";
export { generateContent } from "./generateContent";
export { getPronunciation } from "./getPronunciation";
export { synthesizeSpeech } from "./synthesizeSpeech";
```

```bash
npm run typecheck
```

- [ ] **Step 5: Commit**

```bash
git add functions/src/synthesizeSpeech.ts functions/src/synthesizeSpeech.test.ts functions/src/index.ts
git commit -m "feat(functions): add synthesizeSpeech onCall for live uncached TTS"
```

---

### Task 7: Cloud Functions — `transcribeAudio` (STT)

**Files:**
- Create: `functions/src/transcribeAudio.ts`
- Create: `functions/src/transcribeAudio.test.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: `transcribeViaCloudRun`, `toHttpsError` (Task 4).
- Produces: `transcribeAudioHandler(request): Promise<{text: string; language: string}>`, exported `transcribeAudio` onCall function.

- [ ] **Step 1: Write the failing tests**

`functions/src/transcribeAudio.test.ts`:
```ts
import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";

vi.mock("./services/cloudRunClient", async () => {
  const actual = await vi.importActual<typeof import("./services/cloudRunClient")>(
    "./services/cloudRunClient"
  );
  return { ...actual, transcribeViaCloudRun: vi.fn() };
});

import { transcribeViaCloudRun } from "./services/cloudRunClient";
import { transcribeAudioHandler } from "./transcribeAudio";

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
});

function makeRequest(data: unknown, authed = true): CallableRequest<unknown> {
  return {
    auth: authed ? { uid: "user-123" } : undefined,
    data,
  } as CallableRequest<unknown>;
}

describe("transcribeAudioHandler", () => {
  it("throws unauthenticated when there is no auth context", async () => {
    await expect(
      transcribeAudioHandler(makeRequest({ audioBase64: "aGVsbG8=" }, false))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("throws invalid-argument for a malformed payload", async () => {
    await expect(transcribeAudioHandler(makeRequest({ audioBase64: "" }))).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  it("throws invalid-argument for an unsupported language", async () => {
    await expect(
      transcribeAudioHandler(makeRequest({ audioBase64: "aGVsbG8=", language: "fr" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("throws failed-precondition when TTS_STT_SERVICE_URL is unset", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "");
    await expect(
      transcribeAudioHandler(makeRequest({ audioBase64: "aGVsbG8=" }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("decodes base64 audio and returns the transcript for a valid request", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(transcribeViaCloudRun).mockResolvedValue({ text: "xin chao", language: "vi" });

    const result = await transcribeAudioHandler(
      makeRequest({ audioBase64: Buffer.from("wav-bytes").toString("base64"), language: "vi" })
    );

    expect(transcribeViaCloudRun).toHaveBeenCalledWith(
      "https://tts-stt.a.run.app",
      Buffer.from("wav-bytes"),
      "vi"
    );
    expect(result).toEqual({ text: "xin chao", language: "vi" });
  });
});
```

- [ ] **Step 2: Run to verify it fails**

```bash
npm test -- transcribeAudio
```
Expected: FAIL — `./transcribeAudio` does not exist.

- [ ] **Step 3: Write the implementation**

`functions/src/transcribeAudio.ts`:
```ts
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { transcribeViaCloudRun, toHttpsError } from "./services/cloudRunClient";

export interface TranscribeAudioRequest {
  audioBase64: string;
  language?: "vi" | "en";
}

function isTranscribeAudioRequest(data: unknown): data is TranscribeAudioRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    typeof d.audioBase64 === "string" &&
    d.audioBase64.length > 0 &&
    (d.language === undefined || d.language === "vi" || d.language === "en")
  );
}

export async function transcribeAudioHandler(
  request: CallableRequest<unknown>
): Promise<{ text: string; language: string }> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!isTranscribeAudioRequest(request.data)) {
    throw new HttpsError(
      "invalid-argument",
      "Expected { audioBase64: string, language?: 'vi'|'en' }."
    );
  }
  const serviceUrl = process.env.TTS_STT_SERVICE_URL ?? "";
  if (!serviceUrl) {
    throw new HttpsError("failed-precondition", "TTS/STT service URL is not configured.");
  }

  try {
    const audio = Buffer.from(request.data.audioBase64, "base64");
    return await transcribeViaCloudRun(serviceUrl, audio, request.data.language);
  } catch (err) {
    throw toHttpsError(err, "Transcription failed. Please try again.");
  }
}

export const transcribeAudio = onCall(
  { region: "asia-southeast1", maxInstances: 10, timeoutSeconds: 60 },
  transcribeAudioHandler
);
```

- [ ] **Step 4: Run to verify it passes, wire the export, typecheck**

```bash
npm test -- transcribeAudio
```
Expected: PASS, all 5 tests.

`functions/src/index.ts` (full file):
```ts
export { ping } from "./ping";
export { generateContent } from "./generateContent";
export { getPronunciation } from "./getPronunciation";
export { synthesizeSpeech } from "./synthesizeSpeech";
export { transcribeAudio } from "./transcribeAudio";
```

```bash
npm run typecheck
npm test
```
Expected: full `functions/` suite passes (all prior + these new tests).

- [ ] **Step 5: Commit**

```bash
git add functions/src/transcribeAudio.ts functions/src/transcribeAudio.test.ts functions/src/index.ts
git commit -m "feat(functions): add transcribeAudio onCall STT proxy"
```

---

### Task 8: Firebase Storage rules + local-dev env wiring

**Files:**
- Create: `storage.rules`
- Modify: `firebase.json`
- Create: `functions/.env.example`
- Modify: `functions/.gitignore`
- Modify: `CLAUDE.md`

**Interfaces:**
- Produces: deployable Storage rules (deployed in Task 9), `functions/.env.local` convention documented for local emulator testing against `http://localhost:8080`.

- [ ] **Step 1: Write Storage security rules**

`storage.rules`:
```
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    match /tts-cache/{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```
(`tts-cache/**` is non-sensitive, shared, cached audio — safe to read publicly. Writes only ever happen server-side via `firebase-admin`, which bypasses these rules entirely, so `allow write: if false` correctly blocks direct client writes without blocking the Cloud Function.)

- [ ] **Step 2: Wire Storage into `firebase.json`**

Add this top-level key to `firebase.json` (alongside the existing `"hosting"`, `"functions"`, `"apphosting"` keys):
```json
"storage": {
  "rules": "storage.rules"
}
```

- [ ] **Step 3: Document the required env var and add local-dev gitignore entry**

`functions/.env.example`:
```
# Base URL of the deployed Cloud Run TTS/STT service (services/tts-stt/).
# Production value lives in the committed functions/.env (non-secret, just a URL).
# For local emulator testing against `uvicorn app.main:app` running on port 8080,
# copy this to functions/.env.local (gitignored) and set:
# TTS_STT_SERVICE_URL=http://localhost:8080
TTS_STT_SERVICE_URL=
```

`functions/.gitignore` (full file):
```
lib/
node_modules/
.env.local
```

- [ ] **Step 4: Update CLAUDE.md's Deploy gotchas section**

Add this bullet to the existing "## Deploy gotchas" list in `CLAUDE.md`:
```markdown
- **The Cloud Run TTS/STT service (`services/tts-stt/`) is a separate deployable unit from `functions/`** — it's built/pushed as a Docker image and deployed with `gcloud run deploy`, not `firebase deploy`. After redeploying it, the Cloud Functions runtime service account needs `roles/run.invoker` re-granted only if the service was recreated (not needed for a plain image update to an existing service). `functions/.env`'s `TTS_STT_SERVICE_URL` must match the current Cloud Run service URL — Cloud Run URLs are stable across image updates but change if the service is deleted and recreated.
```

- [ ] **Step 5: Commit**

```bash
git add storage.rules firebase.json functions/.env.example functions/.gitignore CLAUDE.md
git commit -m "chore(functions): add Storage rules for tts-cache and local-dev env wiring"
```

---

### Task 9: Deploy Cloud Run service, wire production env, verify end-to-end

**This task requires live infrastructure changes and human interaction (gcloud/Firebase CLI auth, IAM grants, real deployed URLs) — do NOT dispatch this task to a subagent. Work through it directly with the user, the same way React Web Plan 1's Task 08 Steps 4-8 were done.**

**Files:**
- Create: `functions/.env` (committed, non-secret — the deployed Cloud Run URL)
- Create: `functions/scripts/verify-onCall.mjs` (throwaway-reusable manual verification script)

- [ ] **Step 1: One-time Artifact Registry repo + Cloud Storage bucket check**

```bash
gcloud artifacts repositories create tts-stt \
  --repository-format=docker --location=asia-southeast1 --project=lexi-core
gcloud auth configure-docker asia-southeast1-docker.pkg.dev
```
Also confirm the project's default Cloud Storage bucket exists (Firebase Console → Storage → if never opened before, click "Get started" once to provision the default bucket — this project has never used Storage before this plan).

- [ ] **Step 2: Build and push the Docker image**

```bash
docker build -t asia-southeast1-docker.pkg.dev/lexi-core/tts-stt/tts-stt:latest services/tts-stt
docker push asia-southeast1-docker.pkg.dev/lexi-core/tts-stt/tts-stt:latest
```

- [ ] **Step 3: Deploy to Cloud Run, private (no public ingress)**

```bash
gcloud run deploy tts-stt \
  --image=asia-southeast1-docker.pkg.dev/lexi-core/tts-stt/tts-stt:latest \
  --region=asia-southeast1 \
  --project=lexi-core \
  --no-allow-unauthenticated \
  --memory=2Gi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=2 \
  --timeout=60s
```

- [ ] **Step 4: Grant the Cloud Functions runtime service account permission to invoke it**

First confirm the actual runtime service account in the Console (IAM & Admin → usually `lexi-core@appspot.gserviceaccount.com` for 2nd-gen functions unless a custom one was configured), then:
```bash
gcloud run services add-iam-policy-binding tts-stt \
  --region=asia-southeast1 \
  --project=lexi-core \
  --member="serviceAccount:lexi-core@appspot.gserviceaccount.com" \
  --role="roles/run.invoker"
```

- [ ] **Step 5: Wire the deployed URL into `functions/.env` and deploy Storage rules + functions**

```bash
gcloud run services describe tts-stt --region=asia-southeast1 --project=lexi-core --format='value(status.url)'
```
Create `functions/.env` (commit this — it's a URL, not a secret):
```
TTS_STT_SERVICE_URL=<the URL printed above>
```
```bash
firebase deploy --only storage
firebase deploy --only functions
git add functions/.env
git commit -m "chore(functions): wire production TTS_STT_SERVICE_URL"
```

- [ ] **Step 6: Local emulator E2E test (real models, real endpoints)**

In one terminal, run the real Cloud Run service locally:
```bash
cd services/tts-stt
docker run --rm -p 8080:8080 asia-southeast1-docker.pkg.dev/lexi-core/tts-stt/tts-stt:latest
```
In another terminal, point the emulator at it and start it:
```bash
cd functions
cp .env.example .env.local
# edit .env.local: TTS_STT_SERVICE_URL=http://localhost:8080
firebase emulators:start
```
Use the emulator UI (or the verification script from Step 7, pointed at the emulator's callable HTTP endpoint) to call `getPronunciation`, `synthesizeSpeech`, and `transcribeAudio`, confirming real Piper/faster-whisper output — this is the first point in the plan where the real (non-mocked) models are exercised through the full Function→Cloud-Run round trip.

- [ ] **Step 7: Production end-to-end verification**

There's no frontend yet to click through (React Web Plan 3 hasn't been built), so verify by directly invoking the deployed callable functions' HTTPS endpoints with a real Firebase Auth ID token.

`functions/scripts/verify-onCall.mjs`:
```js
// Manual verification script for onCall functions with no frontend yet.
// Usage: node scripts/verify-onCall.mjs <functionName> '<jsonData>'
// Requires: GOOGLE_APPLICATION_CREDENTIALS pointed at a service account key,
// and FIREBASE_WEB_API_KEY set to the Web API key from Firebase Console > Project settings.
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const [, , functionName, jsonData] = process.argv;
const app = initializeApp({ credential: cert(process.env.GOOGLE_APPLICATION_CREDENTIALS) });

const customToken = await getAuth(app).createCustomToken("verify-script-uid");

const signInRes = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${process.env.FIREBASE_WEB_API_KEY}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  }
);
const { idToken } = await signInRes.json();

const callableRes = await fetch(
  `https://asia-southeast1-lexi-core.cloudfunctions.net/${functionName}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ data: JSON.parse(jsonData) }),
  }
);
console.log(await callableRes.json());
```

```bash
node functions/scripts/verify-onCall.mjs getPronunciation '{"text":"xin chào","language":"vi","tier":"word"}'
node functions/scripts/verify-onCall.mjs getPronunciation '{"text":"xin chào","language":"vi","tier":"word"}'
node functions/scripts/verify-onCall.mjs synthesizeSpeech '{"text":"hello world","language":"en"}'
node functions/scripts/verify-onCall.mjs transcribeAudio '{"audioBase64":"<base64 of /tmp/test.wav from Task 2>"}'
```
Expected: the first `getPronunciation` call returns a `result.url` and is a cache miss (Cloud Run cold-start latency visible); the second, identical call returns the same URL near-instantly (cache hit, confirmed by checking Cloud Run logs show no new request); `synthesizeSpeech` returns `result.audioBase64` decodable to valid WAV; `transcribeAudio` returns `result.text` roughly matching the original synthesized text.

```bash
git add functions/scripts/verify-onCall.mjs
git commit -m "chore(functions): add manual onCall verification script (no frontend yet)"
```

- [ ] **Step 8: Set the 90-day lifecycle rule on the `tts-cache/sentence/**` tier**

This is a bucket-level config (spec §3.4), not a Cloud Functions code change — there's no `sentence`-vs-`word` distinction available to a bucket-wide lifecycle rule by path prefix alone in the simple case, so scope it with a `matchesPrefix` condition:

```bash
cat > /tmp/lifecycle.json <<'EOF'
{
  "rule": [
    {
      "action": { "type": "Delete" },
      "condition": { "age": 90, "matchesPrefix": ["tts-cache/sentence/"] }
    }
  ]
}
EOF
gcloud storage buckets update gs://lexi-core.firebasestorage.app --lifecycle-file=/tmp/lifecycle.json
gcloud storage buckets describe gs://lexi-core.firebasestorage.app --format='default(lifecycle_config)'
```
Expected: the describe command echoes back the rule just set, confirming `tts-cache/word/**` is unaffected (no rule targets it — matches spec's "no lifecycle/expiry" for that tier).

- [ ] **Step 9: Record the outcome**

Once all three functions are verified working in production, update `.superpowers/sdd/progress.md` with the React Web Plan 2 ledger entry (task-by-task, mirroring the React Web Plan 1 entry's format) and note the final test counts (`services/tts-stt`: pytest count; `functions/`: vitest count).

---

## Self-Review Notes

- **Spec coverage:** §3.4's Piper/faster-whisper choice (Task 2/3), Cloud Run private hosting via same-project IAM (Task 4, Task 9 Steps 3-4), content-addressable cache with `sha256(normalize(text)+language+voiceId)` and the exact two-tier path scheme (Task 5, Global Constraints), "Nghe audio never cached" (Task 6 has no Storage import at all), STT proxy for a future feature (Task 7) — all covered. The 90-day lifecycle rule on `tts-cache/sentence/**` (spec §3.4) is a bucket-level Console/`gcloud storage buckets update --lifecycle-file` config, not a Cloud Functions code change — explicitly logged as a Task 8 follow-up rather than silently dropped, since no task above sets it.
- **Type consistency checked:** `PronunciationTier`, `MinimalCacheBucket`/`MinimalCacheFile`, `CloudRunCallError`, `toHttpsError` signatures match between their Task 4/5 definitions and every later consumer (Tasks 5-7 handler files, all test files).
- **No placeholders:** every step has complete, runnable code — no "add error handling" or "similar to Task N" shorthand.
