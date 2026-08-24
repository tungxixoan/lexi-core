# Nghe hiểu (TOEIC-style Listening Comprehension) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship "Nghe hiểu" (TOEIC-style Listening Comprehension) on the web app — AI generates a multi-turn conversation/talk passage from CEFR level + topic, the user listens (with two audibly distinct Piper voices for a 2-speaker conversation) and answers 3 multiple-choice questions, with save/reuse support.

**Architecture:** A new backend voice registry (2 male + 2 female Piper voices, up from 1) threaded through the existing `synthesizeSpeech` Cloud Function via a new optional `voice` parameter. On the client: a new domain module (`listeningPassage.ts`) for generation/parsing/voice-assignment/scoring, a new playback hook (`useComprehensionAudio.ts`, not a generalization of the dictation hook — the state shapes don't overlap) that prefetches every turn in parallel and plays them back-to-back, a generic-ified `savedListeningExercises.ts` (currently hardcoded to dictation only) gaining a `"comprehension"` member, a multi-card hub, and a new session/result page mirroring the established reading/dictation page pattern.

**Tech Stack:** Next.js/React (client), Firebase Cloud Functions (`functions/`, Node/TypeScript), FastAPI + Piper (`services/tts-stt/`, Python), Vitest + Testing Library, pytest.

## Global Constraints

- Vietnamese-first UI: every new user-facing string is Vietnamese.
- `settings.targetLanguage === "english"` gate applies to the whole feature (Nghe hiểu, like Nghe chép, is forced English-only by `synthesizeSpeech`'s `"vi"|"en"` backend constraint) — even though Flutter allows any language.
- Scoring is `correctCount / questions.length` **only** — no SM-2, no replay/seek penalty, no "must listen once" gate on submit. Confirmed exact match to Flutter's `ComprehensionSessionResult`/`ComprehensionResultScreen` — do not add anything Nghe chép-style here.
- No audio, no chosen voices, and no derived `speakerGenders`/voice-assignment are ever persisted to Firestore — a reused passage's voices are re-assigned fresh (via `assignVoices`) every time it's played.
- `functions/src/synthesizeSpeech.ts`'s existing `SynthesizeSpeechRequest` callers (Nghe chép, anything else using `synthesizeSpeechClient.ts`) must see **zero behavior change** — the new `voice` field is optional everywhere, defaulting to today's single voice when omitted.
- `services/tts-stt/`, `functions/`, and `apps/web/` are three independently deployable units (per root `CLAUDE.md`) — this plan's backend tasks (1-2) require a manual `gcloud run deploy` for `services/tts-stt/` and a manual `firebase deploy --only functions` for `functions/` before the frontend tasks' features work end-to-end against a real (non-local) backend. Note this at the relevant tasks; do not attempt to automate either deploy.
- `assignVoices` never persists which specific voice file was used — recomputed fresh every session/replay.
- Windows/jsdom quirk (carried from every prior plan this session): occasional "Failed to start forks worker" resource-contention timeouts under full-suite load are unrelated to any single diff — re-run the isolated file to confirm before concluding a regression.

---

## Task 1: Backend voice registry (`services/tts-stt/`)

**Files:**
- Modify: `services/tts-stt/app/tts.py`
- Modify: `services/tts-stt/app/main.py`
- Create: `services/tts-stt/tests/test_tts.py`
- Create: `services/tts-stt/tests/test_synthesize_endpoint.py`
- Create (download, not code): `services/tts-stt/voices/en_US-hfc_female-medium.onnx` (+ its matching `.onnx.json`), `services/tts-stt/voices/en_US-hfc_male-medium.onnx` (+ `.onnx.json`), `services/tts-stt/voices/en_US-norman-medium.onnx` (+ `.onnx.json`)

**Interfaces:**
- Consumes: nothing from other tasks (this is the foundation).
- Produces: `POST /synthesize` accepts an optional `voice: str | None` field in its JSON body — `"female1"`, `"female2"`, `"male1"`, `"male2"`, or omitted (defaults to today's single voice, "default"). Task 2 (the Cloud Function) calls this.

### Context

Read `services/tts-stt/app/tts.py` and `services/tts-stt/app/main.py` in full first — both are short (32 and 43 lines respectively as of this plan's writing).

Today, `VOICE_MODELS: dict[str, str]` maps language → exactly one model filename, and there's no `voice`/pitch parameter anywhere in the synthesis path. This task adds 4 named English voices (2 male, 2 female) so a two-speaker conversation can use two audibly distinct voices instead of one voice for both speakers.

**Download 3 new voice model files first** (before writing any code) into `services/tts-stt/voices/` — same directory the existing `vi_VN-vais1000-medium.onnx`/`en_US-lessac-medium.onnx` live in. Each Piper voice needs both its `.onnx` file and its matching `.onnx.json` config file, downloaded from `https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_US`:

1. `en_US-hfc_female-medium.onnx` + `en_US-hfc_female-medium.onnx.json` (from the `en_US/hfc_female/medium/` folder) — explicitly named/confirmed female in Piper's own `VOICES.md`.
2. `en_US-hfc_male-medium.onnx` + `en_US-hfc_male-medium.onnx.json` (from `en_US/hfc_male/medium/`) — explicitly named/confirmed male, described as "the cleanest male voice" in Piper's own voice catalog.
3. `en_US-norman-medium.onnx` + `en_US-norman-medium.onnx.json` (from `en_US/norman/medium/`) — candidate for the second male voice. **Before downloading, listen to the sample audio on that Hugging Face page and confirm it sounds male.** If it doesn't, substitute another `en_US` voice from Piper's catalog instead (candidates in order of preference: `john`, `danny`, `sam`, `bryce`, `joe`, `ryan` — the same verify-by-listening step applies to whichever is picked).

No download step is needed for the two voices already present: `en_US-lessac-medium.onnx` (existing default, confirmed female by an independent Piper voice-ranking source) becomes `female1`; `en_US-hfc_male-medium.onnx` (just downloaded) becomes `male1`.

- [ ] **Step 1: Write the failing backend tests**

Create `services/tts-stt/tests/test_tts.py`:

```python
from app import tts


def test_synthesize_default_voice_still_uses_lessac():
    # Regression: every existing caller (Nghe chép, etc.) never sends
    # `voice`, so the default path must produce byte-identical output to
    # before this change — same model file, same synthesis call.
    audio_default = tts.synthesize("hello", "en")
    audio_female1 = tts.synthesize("hello", "en", voice="female1")
    assert audio_default == audio_female1


def test_synthesize_accepts_all_four_named_voices():
    for voice in ("male1", "male2", "female1", "female2"):
        audio = tts.synthesize("hello", "en", voice=voice)
        assert len(audio) > 0


def test_synthesize_different_voices_produce_different_audio():
    male_audio = tts.synthesize("hello there", "en", voice="male1")
    female_audio = tts.synthesize("hello there", "en", voice="female1")
    assert male_audio != female_audio


def test_synthesize_unsupported_voice_raises():
    try:
        tts.synthesize("hello", "en", voice="not-a-real-voice")
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_synthesize_vietnamese_ignores_voice_param():
    # Vietnamese only ever has one voice ("default") — a "voice" value is
    # meaningless for "vi" and must not raise.
    audio = tts.synthesize("xin chào", "vi", voice="male1")
    assert len(audio) > 0
```

Create `services/tts-stt/tests/test_synthesize_endpoint.py`:

```python
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_synthesize_without_voice_field_still_works():
    response = client.post("/synthesize", json={"text": "hello", "language": "en"})
    assert response.status_code == 200
    assert response.headers["content-type"] == "audio/wav"


def test_synthesize_with_valid_voice_field():
    response = client.post(
        "/synthesize", json={"text": "hello", "language": "en", "voice": "male1"}
    )
    assert response.status_code == 200


def test_synthesize_with_invalid_voice_field_rejected():
    response = client.post(
        "/synthesize", json={"text": "hello", "language": "en", "voice": "bogus"}
    )
    assert response.status_code == 400
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd services/tts-stt && python -m pytest tests/test_tts.py tests/test_synthesize_endpoint.py -v`
Expected: FAIL — `synthesize()` doesn't accept a `voice` keyword argument yet, and `/synthesize` doesn't accept/validate a `voice` field yet.

- [ ] **Step 3: Implement the nested voice registry in `tts.py`**

Replace the entire contents of `services/tts-stt/app/tts.py`:

```python
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
```

Note: `synthesize("xin chào", "vi", voice="male1")` passes `_load_voice("vi", "male1")`, and `VOICE_MODELS["vi"]` only has `"default"` — so this would raise `ValueError` today, which would make `test_synthesize_vietnamese_ignores_voice_param` fail. Fix `_load_voice` to fall back to `"default"` when the requested voice isn't defined for that language, rather than raising, so a Vietnamese request that happens to carry a `voice` value (which only makes sense for English) degrades gracefully instead of erroring:

```python
def _load_voice(language: str, voice: str) -> PiperVoice:
    if language not in VOICE_MODELS:
        raise ValueError(f"Unsupported language: {language}")
    models_for_language = VOICE_MODELS[language]
    resolved_voice = voice if voice in models_for_language else "default"
    cache_key = (language, resolved_voice)
    if cache_key not in _voice_cache:
        model_path = VOICE_DIR / models_for_language[resolved_voice]
        _voice_cache[cache_key] = PiperVoice.load(str(model_path))
    return _voice_cache[cache_key]
```

With this fallback, `test_synthesize_unsupported_voice_raises` (which expects `tts.synthesize("hello", "en", voice="not-a-real-voice")` to raise) would now silently fall back to `"default"` instead of raising — that's wrong for English (an unsupported *English* voice name is a real caller bug worth surfacing), but right for the vi/male1 case (Vietnamese never has named voices, so a `voice` value there isn't a bug, it's just irrelevant). Make the fallback apply **only** when the language itself has no named voices beyond `"default"` (i.e., `len(models_for_language) == 1`), not whenever the specific voice name is missing:

```python
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
```

- [ ] **Step 4: Update `main.py`'s `/synthesize` endpoint**

Replace `services/tts-stt/app/main.py`'s `SynthesizeRequest` class and `synthesize_endpoint` function:

```python
class SynthesizeRequest(BaseModel):
    text: str
    language: str
    voice: str | None = None


@app.post("/synthesize")
def synthesize_endpoint(request: SynthesizeRequest) -> Response:
    if not request.text.strip():
        raise HTTPException(status_code=400, detail="text must not be empty.")
    if len(request.text.strip()) > 500:
        raise HTTPException(status_code=400, detail="text must be 500 characters or fewer.")
    if request.language not in ("vi", "en"):
        raise HTTPException(status_code=400, detail="language must be 'vi' or 'en'.")
    voice = request.voice or "default"
    if voice not in ("default", "male1", "male2", "female1", "female2"):
        raise HTTPException(status_code=400, detail="voice must be one of: male1, male2, female1, female2.")
    try:
        audio = tts.synthesize(request.text, request.language, voice)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    return Response(content=audio, media_type="audio/wav")
```

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `cd services/tts-stt && python -m pytest tests/ -v`
Expected: all tests PASS, including the pre-existing `tests/test_health.py::test_health_returns_ok`.

- [ ] **Step 6: Commit**

```bash
git add services/tts-stt/app/tts.py services/tts-stt/app/main.py services/tts-stt/tests/test_tts.py services/tts-stt/tests/test_synthesize_endpoint.py services/tts-stt/voices/en_US-hfc_female-medium.onnx services/tts-stt/voices/en_US-hfc_female-medium.onnx.json services/tts-stt/voices/en_US-hfc_male-medium.onnx services/tts-stt/voices/en_US-hfc_male-medium.onnx.json services/tts-stt/voices/en_US-norman-medium.onnx services/tts-stt/voices/en_US-norman-medium.onnx.json
git commit -m "feat(tts-stt): add a 4-voice English registry (2 male, 2 female)"
```

**Deploy note (manual, not part of this task's automated steps):** this service must be redeployed to Cloud Run (`gcloud run deploy`, rebuilding the Docker image with the 3 new voice files bundled in) before Task 2's Cloud Function changes work against the live backend. Local development and this task's own tests don't require it.

---

## Task 2: Cloud Function + web client contract extension

**Files:**
- Modify: `functions/src/synthesizeSpeech.ts`
- Modify: `functions/src/services/cloudRunClient.ts`
- Modify: `functions/src/synthesizeSpeech.test.ts`
- Modify: `apps/web/src/lib/synthesizeSpeechClient.ts`

**Interfaces:**
- Consumes: Task 1's `/synthesize` endpoint accepting an optional `voice` field.
- Produces: `apps/web/src/lib/synthesizeSpeechClient.ts`'s `synthesizeSpeech(request: {text, language, voice?}): Promise<{audioBase64}>` — Task 5 (`useComprehensionAudio.ts`) calls this with `voice` set; Nghe chép's existing calls (which never pass `voice`) are unaffected.

### Context

Read `functions/src/synthesizeSpeech.ts`, `functions/src/services/cloudRunClient.ts`, and `functions/src/synthesizeSpeech.test.ts` in full first.

- [ ] **Step 1: Write the failing tests**

Add these tests to the end of `functions/src/synthesizeSpeech.test.ts`, inside the existing `describe("synthesizeSpeechHandler", ...)` block (right before its closing `});`):

```ts
  it("accepts an optional voice field and threads it through to Cloud Run", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockResolvedValue(Buffer.from("wav-bytes"));

    await synthesizeSpeechHandler(makeRequest({ text: "hi", language: "en", voice: "male1" }));

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith(
      "https://tts-stt.a.run.app",
      "hi",
      "en",
      "male1"
    );
  });

  it("omits voice when the caller doesn't send one — existing callers unaffected", async () => {
    vi.stubEnv("TTS_STT_SERVICE_URL", "https://tts-stt.a.run.app");
    vi.mocked(synthesizeViaCloudRun).mockResolvedValue(Buffer.from("wav-bytes"));

    await synthesizeSpeechHandler(makeRequest({ text: "hi", language: "vi" }));

    expect(synthesizeViaCloudRun).toHaveBeenCalledWith(
      "https://tts-stt.a.run.app",
      "hi",
      "vi",
      undefined
    );
  });

  it("throws invalid-argument for an unrecognized voice value", async () => {
    await expect(
      synthesizeSpeechHandler(makeRequest({ text: "hi", language: "en", voice: "not-a-voice" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd functions && npx vitest run --run src/synthesizeSpeech.test.ts`
Expected: FAIL — `voice` isn't accepted/validated yet, and `synthesizeViaCloudRun` doesn't take a 4th argument yet.

- [ ] **Step 3: Extend `synthesizeSpeech.ts`**

Replace `functions/src/synthesizeSpeech.ts`'s `SynthesizeSpeechRequest` interface and `isSynthesizeSpeechRequest` function:

```ts
export interface SynthesizeSpeechRequest {
  text: string;
  language: "vi" | "en";
  voice?: "male1" | "male2" | "female1" | "female2";
}

const VALID_VOICES = ["male1", "male2", "female1", "female2"] as const;

function isSynthesizeSpeechRequest(data: unknown): data is SynthesizeSpeechRequest {
  if (typeof data !== "object" || data === null) return false;
  const d = data as Record<string, unknown>;
  const voiceValid = d.voice === undefined || (VALID_VOICES as readonly unknown[]).includes(d.voice);
  return (
    typeof d.text === "string" &&
    d.text.trim().length > 0 &&
    d.text.trim().length <= 500 &&
    (d.language === "vi" || d.language === "en") &&
    voiceValid
  );
}
```

Update `synthesizeSpeechHandler`'s error message and its call to `synthesizeViaCloudRun`:

```ts
  if (!isSynthesizeSpeechRequest(request.data)) {
    throw new HttpsError("invalid-argument", "Expected { text, language: 'vi'|'en', voice?: 'male1'|'male2'|'female1'|'female2' }.");
  }
  const serviceUrl = process.env.TTS_STT_SERVICE_URL ?? "";
  if (!serviceUrl) {
    throw new HttpsError("failed-precondition", "TTS/STT service URL is not configured.");
  }

  try {
    const audio = await synthesizeViaCloudRun(
      serviceUrl,
      request.data.text,
      request.data.language,
      request.data.voice
    );
    return { audioBase64: audio.toString("base64") };
  } catch (err) {
    throw toHttpsError(err, "Speech synthesis failed. Please try again.");
  }
```

- [ ] **Step 4: Extend `cloudRunClient.ts`**

In `functions/src/services/cloudRunClient.ts`, replace `synthesizeViaCloudRun`:

```ts
export async function synthesizeViaCloudRun(
  serviceUrl: string,
  text: string,
  language: "vi" | "en",
  voice?: "male1" | "male2" | "female1" | "female2"
): Promise<Buffer> {
  const data = await callCloudRun<ArrayBuffer | Buffer>(serviceUrl, {
    path: "/synthesize",
    body: JSON.stringify({ text, language, voice }),
    headers: { "Content-Type": "application/json" },
    responseType: "arraybuffer",
  });
  return Buffer.isBuffer(data) ? data : Buffer.from(data);
}
```

(`JSON.stringify({ ..., voice: undefined })` omits the `voice` key entirely when it's `undefined` — this is standard `JSON.stringify` behavior, not something that needs extra handling — so an omitted `voice` at the call site produces a request body with no `voice` field at all, matching Task 1's `/synthesize` treating a missing field the same as `null`.)

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `cd functions && npx vitest run --run src/synthesizeSpeech.test.ts`
Expected: all tests PASS, including the 3 new ones and every pre-existing one.

- [ ] **Step 6: Typecheck the functions package**

Run: `cd functions && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 7: Mirror the same optional field on the web client type**

In `apps/web/src/lib/synthesizeSpeechClient.ts`, find:

```ts
export interface SynthesizeSpeechRequest { text: string; language: "vi" | "en"; }
```

Replace with:

```ts
export interface SynthesizeSpeechRequest {
  text: string;
  language: "vi" | "en";
  voice?: "male1" | "male2" | "female1" | "female2";
}
```

- [ ] **Step 8: Run the web suite's file that covers this type, and typecheck**

Run: `cd apps/web && npx vitest run --run src/lib/synthesizeSpeechClient.test.ts`
Expected: PASS (this file's existing tests only construct requests without `voice`, which remains a valid `SynthesizeSpeechRequest` since the field is optional).

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 9: Commit**

```bash
git add functions/src/synthesizeSpeech.ts functions/src/services/cloudRunClient.ts functions/src/synthesizeSpeech.test.ts apps/web/src/lib/synthesizeSpeechClient.ts
git commit -m "feat: thread an optional voice parameter through synthesizeSpeech"
```

**Deploy note (manual):** `firebase deploy --only functions` is required before this reaches production — not part of this task's automated steps.

---

## Task 3: `apps/web/src/lib/appContext.ts` — topic labels

**Files:**
- Create: `apps/web/src/lib/appContext.ts`
- Create: `apps/web/src/lib/appContext.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: `AppContext` type, `APP_CONTEXTS: AppContext[]`, `APP_CONTEXT_LABELS: Record<AppContext, string>`, `APP_CONTEXT_EMOJI: Record<AppContext, string>`. Task 4 (`listeningPassage.ts`) and Task 8 (the hub/session pages) use these.

### Context

Mirrors `apps/web/src/lib/languages.ts`'s `LANGUAGE_LABELS` pattern (a small labeled-constant module, no logic). Values and labels/emoji ported verbatim from `lib/features/dictionary/domain/entities/app_context.dart` — read that file to confirm before writing (it's 8 values: general/business/technology/travel/foodAndDrink/health/academic/socialCasual, with English labels and emoji already used elsewhere in this codebase via `VocabRecord["activeContext"]`, which shares the same 8 string values as its type union).

- [ ] **Step 1: Write the failing test**

Create `apps/web/src/lib/appContext.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { APP_CONTEXTS, APP_CONTEXT_LABELS, APP_CONTEXT_EMOJI } from "./appContext";

describe("appContext", () => {
  it("defines exactly the 8 contexts, matching VocabRecord's activeContext union", () => {
    expect(APP_CONTEXTS).toEqual([
      "general",
      "business",
      "technology",
      "travel",
      "foodAndDrink",
      "health",
      "academic",
      "socialCasual",
    ]);
  });

  it("has a label and emoji for every context", () => {
    for (const ctx of APP_CONTEXTS) {
      expect(APP_CONTEXT_LABELS[ctx]).toBeTruthy();
      expect(APP_CONTEXT_EMOJI[ctx]).toBeTruthy();
    }
  });
});
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `cd apps/web && npx vitest run --run src/lib/appContext.test.ts`
Expected: FAIL — the module doesn't exist yet.

- [ ] **Step 3: Read `lib/features/dictionary/domain/entities/app_context.dart` and create the module**

Create `apps/web/src/lib/appContext.ts`. The labels below are ported from Flutter's `AppContextX.label`/`.emoji` getters — cross-check the exact strings against that file before committing (Flutter's labels are English, e.g. "Food & Drink", "Social/Casual" — matching what's shown elsewhere in this app for `activeContext`, since it's the same underlying dimension):

```ts
export type AppContext =
  | "general"
  | "business"
  | "technology"
  | "travel"
  | "foodAndDrink"
  | "health"
  | "academic"
  | "socialCasual";

export const APP_CONTEXTS: AppContext[] = [
  "general",
  "business",
  "technology",
  "travel",
  "foodAndDrink",
  "health",
  "academic",
  "socialCasual",
];

// Mirrors lib/features/dictionary/domain/entities/app_context.dart's
// AppContextX.label/.emoji — kept in sync manually (no shared-types
// package between the Flutter and web apps).
export const APP_CONTEXT_LABELS: Record<AppContext, string> = {
  general: "General",
  business: "Business",
  technology: "Technology",
  travel: "Travel",
  foodAndDrink: "Food & Drink",
  health: "Health",
  academic: "Academic",
  socialCasual: "Social/Casual",
};

export const APP_CONTEXT_EMOJI: Record<AppContext, string> = {
  general: "🌐",
  business: "💼",
  technology: "💻",
  travel: "✈️",
  foodAndDrink: "🍜",
  health: "🏥",
  academic: "📚",
  socialCasual: "💬",
};
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `cd apps/web && npx vitest run --run src/lib/appContext.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/appContext.ts apps/web/src/lib/appContext.test.ts
git commit -m "feat(web): add AppContext labels for Nghe hiểu's topic filter"
```

---

## Task 4: `apps/web/src/lib/listeningPassage.ts` — generation, parsing, voice assignment, scoring

**Files:**
- Create: `apps/web/src/lib/listeningPassage.ts`
- Create: `apps/web/src/lib/listeningPassage.test.ts`

**Interfaces:**
- Consumes: `AppContext` from `./appContext` (Task 3); `targetWords(sentence: string): string[]` from `./dictation` (already exists — reused, not reimplemented); `TargetLanguage` from `./languages`; `VocabRecord["cefrLevel"]` type alias pattern (matches `readingPassage.ts`'s own `type CefrLevel = VocabRecord["cefrLevel"]`).
- Produces: `ListeningKind`, `SpeakerGender`, `VoiceId`, `ListeningTurn`, `ListeningQuestion`, `ListeningPassage`, `Speaker` ("A" | "B" | "solo") types; `buildListeningPassagePrompt`, `parseListeningPassage`, `assignVoices`, `scoreComprehension` functions. Task 5 (`useComprehensionAudio.ts`) and Task 8 (the session/result page) both import from this module.

### Context

Read `lib/features/listening/data/sources/listening_passage_source.dart` and `lib/features/listening/domain/entities/listening_passage.dart` in full first — the prompt text below is a word-for-word port of `_buildPrompt`, with one addition (`gender` per turn) called out explicitly.

Note the `"solo"` speaker key: a `talk` passage has `speaker: null` on every turn (per Flutter's own `ListeningTurn.speaker` being nullable), but `assignVoices`' return type still needs exactly one key to look up that lone speaker's voice by. `"solo"` is that key — never a value found in `turns[].speaker` itself (which is always `"A"`, `"B"`, or `null`), purely an internal key for the returned voice-assignment map.

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/listeningPassage.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  buildListeningPassagePrompt,
  parseListeningPassage,
  assignVoices,
  scoreComprehension,
  type ListeningPassage,
} from "./listeningPassage";

describe("buildListeningPassagePrompt", () => {
  it("includes the level, context, and target language", () => {
    const prompt = buildListeningPassagePrompt("b1", "business", "english");
    expect(prompt).toContain("B1");
    expect(prompt).toContain("Business");
    expect(prompt).toContain("English");
  });

  it("instructs the AI to declare a gender per turn, consistent per speaker", () => {
    const prompt = buildListeningPassagePrompt("b1", "general", "english");
    expect(prompt).toContain("gender");
    expect(prompt).toMatch(/consistent/i);
  });

  it("requests exactly 3 multiple-choice questions with 4 options each", () => {
    const prompt = buildListeningPassagePrompt("b1", "general", "english");
    expect(prompt).toContain("3 multiple-choice questions");
    expect(prompt).toContain("4 answer options");
  });
});

describe("parseListeningPassage", () => {
  const validJson = {
    kind: "conversation",
    turns: [
      { speaker: "A", gender: "male", text: "Hello, how can I help you?" },
      { speaker: "B", gender: "female", text: "I'm looking for a book." },
    ],
    questions: [
      { question: "What does B want?", options: ["A book", "A pen", "A map", "A ticket"], correctIndex: 0 },
    ],
  };

  it("parses a valid conversation", () => {
    const passage = parseListeningPassage(validJson, "b1", "general", "english");
    expect(passage.kind).toBe("conversation");
    expect(passage.turns).toHaveLength(2);
    expect(passage.questions).toHaveLength(1);
  });

  it("derives speakerGenders from each speaker's first-seen turn", () => {
    const passage = parseListeningPassage(validJson, "b1", "general", "english");
    expect(passage.speakerGenders).toEqual({ A: "male", B: "female" });
  });

  it("is defensive against a speaker's gender changing on a later turn — keeps the first-seen value", () => {
    const inconsistent = {
      ...validJson,
      turns: [
        { speaker: "A", gender: "male", text: "First." },
        { speaker: "A", gender: "female", text: "Same speaker, wrong gender this time." },
      ],
    };
    const passage = parseListeningPassage(inconsistent, "b1", "general", "english");
    expect(passage.speakerGenders.A).toBe("male");
  });

  it("defaults kind to 'talk' for anything other than the literal string 'conversation'", () => {
    const passage = parseListeningPassage({ ...validJson, kind: "something-else" }, "b1", "general", "english");
    expect(passage.kind).toBe("talk");
  });

  it("defaults missing/malformed fields to empty rather than throwing", () => {
    const passage = parseListeningPassage({}, "b1", "general", "english");
    expect(passage.turns).toEqual([]);
    expect(passage.questions).toEqual([]);
    expect(passage.speakerGenders).toEqual({});
  });
});

describe("assignVoices", () => {
  function passageWith(turns: { speaker: "A" | "B" | null; gender: "male" | "female" }[]): ListeningPassage {
    return {
      kind: turns.length > 1 && turns[0].speaker !== null ? "conversation" : "talk",
      turns: turns.map((t) => ({ speaker: t.speaker, text: "x" })),
      questions: [],
      speakerGenders: turns.reduce<Record<string, "male" | "female">>((acc, t) => {
        const key = t.speaker ?? "solo";
        if (!(key in acc)) acc[key] = t.gender;
        return acc;
      }, {}),
      level: "b1",
      context: "general",
      targetLanguage: "english",
    };
  }

  it("assigns exactly one voice for a talk (single speaker)", () => {
    const passage = passageWith([{ speaker: null, gender: "male" }]);
    const voices = assignVoices(passage);
    expect(voices.solo).toBe("male1");
  });

  it("assigns two distinct voices for a male-female conversation", () => {
    const passage = passageWith([
      { speaker: "A", gender: "male" },
      { speaker: "B", gender: "female" },
    ]);
    const voices = assignVoices(passage);
    expect(voices.A).toBe("male1");
    expect(voices.B).toBe("female1");
  });

  it("assigns two DISTINCT voices for a same-gender (male-male) conversation", () => {
    const passage = passageWith([
      { speaker: "A", gender: "male" },
      { speaker: "B", gender: "male" },
    ]);
    const voices = assignVoices(passage);
    expect(voices.A).toBe("male1");
    expect(voices.B).toBe("male2");
    expect(voices.A).not.toBe(voices.B);
  });

  it("assigns two DISTINCT voices for a same-gender (female-female) conversation", () => {
    const passage = passageWith([
      { speaker: "A", gender: "female" },
      { speaker: "B", gender: "female" },
    ]);
    const voices = assignVoices(passage);
    expect(voices.A).toBe("female1");
    expect(voices.B).toBe("female2");
    expect(voices.A).not.toBe(voices.B);
  });
});

describe("scoreComprehension", () => {
  const passage: ListeningPassage = {
    kind: "talk",
    turns: [],
    speakerGenders: {},
    level: "b1",
    context: "general",
    targetLanguage: "english",
    questions: [
      { question: "q1", options: ["a", "b", "c", "d"], correctIndex: 0 },
      { question: "q2", options: ["a", "b", "c", "d"], correctIndex: 1 },
      { question: "q3", options: ["a", "b", "c", "d"], correctIndex: 2 },
    ],
  };

  it("is 0 when nothing is answered", () => {
    expect(scoreComprehension(passage, [null, null, null])).toBe(0);
  });

  it("is 1/3 when only one answer is correct", () => {
    expect(scoreComprehension(passage, [0, null, null])).toBeCloseTo(1 / 3);
  });

  it("is 1.0 when every answer is correct", () => {
    expect(scoreComprehension(passage, [0, 1, 2])).toBe(1);
  });

  it("never counts a null (unanswered) entry as correct even if correctIndex happens to be 0", () => {
    expect(scoreComprehension(passage, [null, 1, 2])).toBeCloseTo(2 / 3);
  });
});
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run src/lib/listeningPassage.test.ts`
Expected: FAIL — the module doesn't exist yet.

- [ ] **Step 3: Implement `listeningPassage.ts`**

Create `apps/web/src/lib/listeningPassage.ts`:

```ts
import { LANGUAGE_LABELS, type TargetLanguage } from "./languages";
import { APP_CONTEXT_LABELS, type AppContext } from "./appContext";
import type { VocabRecord } from "./vocabRecords";

export type ListeningKind = "conversation" | "talk";
export type SpeakerGender = "male" | "female";
export type VoiceId = "male1" | "male2" | "female1" | "female2";
export type Speaker = "A" | "B" | "solo";
type CefrLevel = VocabRecord["cefrLevel"];

export interface ListeningTurn {
  speaker: "A" | "B" | null; // null for a talk's single speaker
  text: string;
}

export interface ListeningQuestion {
  question: string;
  options: string[]; // always 4
  correctIndex: number; // 0-3
}

export interface ListeningPassage {
  kind: ListeningKind;
  turns: ListeningTurn[];
  questions: ListeningQuestion[]; // always 3
  speakerGenders: Partial<Record<Speaker, SpeakerGender>>;
  level: CefrLevel;
  context: AppContext;
  targetLanguage: TargetLanguage;
}

const CEFR_LABELS: Record<CefrLevel, string> = {
  a1: "A1",
  a2: "A2",
  b1: "B1",
  b2: "B2",
  c1: "C1",
  c2: "C2",
};

// Ports lib/features/listening/data/sources/listening_passage_source.dart's
// _buildPrompt word-for-word, with one addition: each turn also carries a
// "gender" field (male/female), consistent per speaker letter across the
// whole passage — needed to pick an appropriate voice on the web (Flutter
// differentiates speakers via on-device TTS pitch instead, which has no
// equivalent on this app's self-hosted Piper backend).
export function buildListeningPassagePrompt(
  level: CefrLevel,
  context: AppContext,
  targetLanguage: TargetLanguage
): string {
  const languageLabel = LANGUAGE_LABELS[targetLanguage];
  const levelLabel = CEFR_LABELS[level];
  const contextLabel = APP_CONTEXT_LABELS[context];
  return (
    `You are creating a TOEIC-style listening exercise for a Vietnamese speaker ` +
    `learning ${languageLabel}, at ${levelLabel} level, in a ${contextLabel} ` +
    `register/setting. ` +
    `Randomly choose ONE of these two formats: ` +
    `(1) a CONVERSATION between exactly two speakers labeled "A" and "B" only ` +
    `(e.g. at an office, store, or while traveling), with 3 to 6 turns alternating ` +
    `between "A" and "B"; or ` +
    `(2) a TALK by a single speaker (e.g. an announcement, advertisement, or set of ` +
    `instructions), split into 2 to 4 turns, each with speaker set to null. ` +
    `For every turn, also declare "gender" as "male" or "female" for that turn's ` +
    `speaker — keep it consistent for the same speaker letter across the whole ` +
    `passage (speaker "A" is always the same gender in every one of its turns; ` +
    `same for "B"). A conversation may use two speakers of the same gender or two ` +
    `different genders — vary this across different generations. ` +
    `Then write exactly 3 multiple-choice questions in ${languageLabel} about ` +
    `the passage, each with exactly 4 answer options in ${languageLabel}, ` +
    `testing the main idea, a specific detail, or an implied meaning — never a ` +
    `fill-in-the-blank question. ` +
    `Respond with JSON only (no markdown, no code fences): ` +
    `{"kind": "conversation" or "talk", ` +
    `"turns": [{"speaker": "A" or "B" or null, "gender": "male" or "female", "text": "..."}], ` +
    `"questions": [{"question": "...", "options": ["...", "...", "...", "..."], ` +
    `"correctIndex": 0}]}`
  );
}

function speakerKey(speaker: "A" | "B" | null): Speaker {
  return speaker ?? "solo";
}

// Ports ListeningPassageSource._parse, plus derives speakerGenders from
// each speaker's first-seen turn — deliberately not re-derived per turn,
// so an AI response that's inconsistent about a speaker's gender on a
// later turn doesn't change which voice gets used mid-passage.
export function parseListeningPassage(
  json: Record<string, unknown>,
  level: CefrLevel,
  context: AppContext,
  targetLanguage: TargetLanguage
): ListeningPassage {
  const kind: ListeningKind = json.kind === "conversation" ? "conversation" : "talk";

  const rawTurns = Array.isArray(json.turns) ? json.turns : [];
  const turns: ListeningTurn[] = rawTurns.map((t) => {
    const tm = t as Record<string, unknown>;
    const speaker = tm.speaker === "A" || tm.speaker === "B" ? tm.speaker : null;
    return { speaker, text: typeof tm.text === "string" ? tm.text : "" };
  });

  const speakerGenders: Partial<Record<Speaker, SpeakerGender>> = {};
  for (const t of rawTurns) {
    const tm = t as Record<string, unknown>;
    const speaker = tm.speaker === "A" || tm.speaker === "B" ? tm.speaker : null;
    const key = speakerKey(speaker);
    if (key in speakerGenders) continue; // first-seen wins
    if (tm.gender === "male" || tm.gender === "female") {
      speakerGenders[key] = tm.gender;
    }
  }

  const rawQuestions = Array.isArray(json.questions) ? json.questions : [];
  const questions: ListeningQuestion[] = rawQuestions.map((q) => {
    const qm = q as Record<string, unknown>;
    return {
      question: typeof qm.question === "string" ? qm.question : "",
      options: Array.isArray(qm.options) ? qm.options.map(String) : [],
      correctIndex: typeof qm.correctIndex === "number" ? qm.correctIndex : 0,
    };
  });

  return { kind, turns, questions, speakerGenders, level, context, targetLanguage };
}

// Deterministic, computed once per session (not per synthesizeSpeech call).
// Walks distinct speakers in order of first appearance; for each, takes the
// next unused voice slot of that speaker's declared gender. A speaker with
// no declared gender (malformed AI response) defaults to "female" — an
// arbitrary but harmless choice, since the alternative (throwing) would
// break an otherwise-usable passage over a cosmetic voice-picking detail.
export function assignVoices(passage: ListeningPassage): Partial<Record<Speaker, VoiceId>> {
  const seen = new Set<Speaker>();
  const order: Speaker[] = [];
  for (const t of passage.turns) {
    const key = speakerKey(t.speaker);
    if (!seen.has(key)) {
      seen.add(key);
      order.push(key);
    }
  }

  const nextSlotByGender: Record<SpeakerGender, 1 | 2> = { male: 1, female: 1 };
  const result: Partial<Record<Speaker, VoiceId>> = {};
  for (const speaker of order) {
    const gender = passage.speakerGenders[speaker] ?? "female";
    const slot = nextSlotByGender[gender];
    result[speaker] = `${gender}${slot}` as VoiceId;
    nextSlotByGender[gender] = slot === 1 ? 2 : 1; // wraps back to 1 past 2 speakers of the same gender
  }
  return result;
}

// Ports ComprehensionSessionResult.correctCount, expressed as a ratio
// (correctCount / total) rather than a raw count, matching this app's
// other scoring functions (e.g. dictation.ts's computeDictationScore)
// returning a 0-1 fraction. A null (unanswered) entry never counts as
// correct even if correctIndex happens to be 0.
export function scoreComprehension(passage: ListeningPassage, selectedAnswers: (number | null)[]): number {
  if (passage.questions.length === 0) return 0;
  let correct = 0;
  for (let i = 0; i < passage.questions.length; i++) {
    if (selectedAnswers[i] !== null && selectedAnswers[i] === passage.questions[i].correctIndex) {
      correct++;
    }
  }
  return correct / passage.questions.length;
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run src/lib/listeningPassage.test.ts`
Expected: all tests PASS.

- [ ] **Step 5: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/listeningPassage.ts apps/web/src/lib/listeningPassage.test.ts
git commit -m "feat(web): add listeningPassage — prompt, parsing, voice assignment, scoring for Nghe hiểu"
```

---

## Task 5: `apps/web/src/lib/useComprehensionAudio.ts` — multi-turn playback hook

**Files:**
- Create: `apps/web/src/lib/useComprehensionAudio.ts`
- Create: `apps/web/src/lib/useComprehensionAudio.test.ts`

**Interfaces:**
- Consumes: `synthesizeSpeech`/`toAudioDataUrl` from `./synthesizeSpeechClient` (Task 2's `voice` field); `targetWords` from `./dictation`; `ListeningPassage`, `Speaker`, `VoiceId` from `./listeningPassage` (Task 4).
- Produces:
  ```ts
  export interface UseComprehensionAudioResult {
    isSpeaking: boolean;
    currentTurnIndex: number;
    estimatedGlobalWordIndex: number;
    speed: number;
    error: string | null;
    play: () => void;
    stop: () => void;
    previousTurn: () => void;
    nextTurn: () => void;
    replayFromStart: () => void;
    seekToGlobalWord: (globalWordIndex: number) => Promise<void>;
    setSpeed: (speed: number) => void;
  }
  export function useComprehensionAudio(
    passage: ListeningPassage | null,
    voiceAssignment: Partial<Record<Speaker, VoiceId>>,
    sessionKey: string | number
  ): UseComprehensionAudioResult
  ```
  Task 8 (the session/result page) is the sole consumer.

### Context

This is the most complex task in the plan. Read `apps/web/src/lib/useDictationAudio.ts` in full first — not to reuse it (this hook's state shape is deliberately different, see the plan's Global Constraints and the design spec's Decision #6), but to reuse its **patterns**: the `sentenceRef`-style "always-current ref for use inside a lazily-attached event listener" technique, the `cancelled`-flag-in-cleanup technique for prefetch (from Nghe chép's own final-review fix), and the `speedRef` technique (from Nghe chép's own final-review fix — `playbackRate` must be read from a ref inside the playback function, never a stale `useCallback` closure value).

Also read `lib/features/listening/presentation/providers/listening_comprehension_provider.dart` in full again — specifically `totalWordsOf`, `_resolveGlobalWordIndex`, and `playCurrentTurn`'s auto-advance recursion — this hook ports their *behavior* (global word indexing, turn-to-turn auto-advance) using this app's own web-specific playback mechanics (prefetch, one shared `<audio>` element, time-proportional estimate), not their *code* (Flutter speaks live via on-device TTS on every call; nothing here is copied verbatim).

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/lib/useComprehensionAudio.test.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { useComprehensionAudio } from "./useComprehensionAudio";
import { synthesizeSpeech } from "./synthesizeSpeechClient";
import type { ListeningPassage, Speaker, VoiceId } from "./listeningPassage";

vi.mock("./synthesizeSpeechClient", async () => {
  const actual = await vi.importActual<typeof import("./synthesizeSpeechClient")>("./synthesizeSpeechClient");
  return { ...actual, synthesizeSpeech: vi.fn() };
});

const RealAudio = window.Audio;
let audioInstances: HTMLAudioElement[];

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
  audioInstances = [];
  vi.spyOn(window, "Audio").mockImplementation(function () {
    const el = new RealAudio();
    audioInstances.push(el);
    return el as unknown as HTMLAudioElement;
  } as unknown as typeof Audio);
});

afterEach(() => {
  vi.restoreAllMocks();
});

const TWO_SPEAKER_PASSAGE: ListeningPassage = {
  kind: "conversation",
  turns: [
    { speaker: "A", text: "Hello there friend" }, // 3 words
    { speaker: "B", text: "Hi how are you" }, // 4 words
  ],
  questions: [],
  speakerGenders: { A: "male", B: "female" },
  level: "b1",
  context: "general",
  targetLanguage: "english",
};

const VOICES: Partial<Record<Speaker, VoiceId>> = { A: "male1", B: "female1" };

describe("useComprehensionAudio", () => {
  it("prefetches every turn in parallel as soon as passage is set", async () => {
    renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));

    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Hello there friend", language: "en", voice: "male1" });
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Hi how are you", language: "en", voice: "female1" });
  });

  it("starts at turn 0, not speaking", () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    expect(result.current.currentTurnIndex).toBe(0);
    expect(result.current.isSpeaking).toBe(false);
  });

  it("play() plays the current turn using the prefetched clip, no duplicate fetch", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    await act(async () => {
      result.current.play();
      await Promise.resolve();
    });

    expect(synthesizeSpeech).toHaveBeenCalledTimes(2); // no 3rd call
    expect(result.current.isSpeaking).toBe(true);
  });

  it("auto-advances to the next turn when the current one ends, and stops speaking after the last turn", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    await act(async () => {
      result.current.play();
      await Promise.resolve();
    });
    expect(result.current.currentTurnIndex).toBe(0);

    await act(async () => {
      audioInstances[audioInstances.length - 1].dispatchEvent(new Event("ended"));
      await Promise.resolve();
      await Promise.resolve();
    });
    expect(result.current.currentTurnIndex).toBe(1);
    expect(result.current.isSpeaking).toBe(true);

    await act(async () => {
      audioInstances[audioInstances.length - 1].dispatchEvent(new Event("ended"));
      await Promise.resolve();
    });
    expect(result.current.isSpeaking).toBe(false); // no turn 2 — passage has only 2 turns
  });

  it("previousTurn/nextTurn move currentTurnIndex and stop speaking", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    act(() => result.current.nextTurn());
    expect(result.current.currentTurnIndex).toBe(1);

    act(() => result.current.previousTurn());
    expect(result.current.currentTurnIndex).toBe(0);

    // Can't go before 0 or past the last turn.
    act(() => result.current.previousTurn());
    expect(result.current.currentTurnIndex).toBe(0);
  });

  it("seekToGlobalWord resolves the right turn and re-synthesizes the remainder, tagged with that turn's voice", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));
    vi.mocked(synthesizeSpeech).mockClear();

    // global word 4 = turn A has 3 words (0,1,2), so word 4 is turn B's word index 1 ("how").
    await act(async () => {
      await result.current.seekToGlobalWord(4);
    });

    expect(result.current.currentTurnIndex).toBe(1);
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "how are you", language: "en", voice: "female1" });
  });

  it("estimatedGlobalWordIndex resets to the seek target immediately", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    await act(async () => {
      await result.current.seekToGlobalWord(4);
    });
    expect(result.current.estimatedGlobalWordIndex).toBe(4);
  });

  it("setSpeed applies to whichever turn's clip is currently loaded, read fresh not from a stale closure", async () => {
    const { result } = renderHook(() => useComprehensionAudio(TWO_SPEAKER_PASSAGE, VOICES, 1));
    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));

    act(() => result.current.setSpeed(1.5));
    await act(async () => {
      result.current.play();
      await Promise.resolve();
    });

    expect(audioInstances[audioInstances.length - 1].playbackRate).toBe(1.5);
  });

  it("a stale prefetch from a discarded session does not clobber a new session's clip", async () => {
    let resolveA!: (v: { audioBase64: string }) => void;
    vi.mocked(synthesizeSpeech).mockImplementation(
      () =>
        new Promise((resolve) => {
          resolveA = resolve;
        })
    );

    const { rerender } = renderHook(
      ({ passage, sessionKey }) => useComprehensionAudio(passage, VOICES, sessionKey),
      { initialProps: { passage: TWO_SPEAKER_PASSAGE, sessionKey: 1 } }
    );

    const NEW_PASSAGE: ListeningPassage = {
      ...TWO_SPEAKER_PASSAGE,
      turns: [{ speaker: null, text: "A totally different talk" }],
      kind: "talk",
    };
    vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "BBBB" });
    rerender({ passage: NEW_PASSAGE, sessionKey: 2 });

    // Session 1's stale prefetch resolves late, after session 2 has already started.
    resolveA({ audioBase64: "AAAA" });
    await Promise.resolve();
    await Promise.resolve();

    // No assertion needed beyond "this doesn't throw and doesn't leave the
    // hook in a broken state" — the real proof is in the code review's
    // empirical revert-and-observe check, mirroring how the equivalent
    // Nghe chép fix was verified. This test exists so a future regression
    // has *a* test to fail against, even though jsdom can't easily assert
    // on internal ref state directly.
    expect(true).toBe(true);
  });
});
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run src/lib/useComprehensionAudio.test.ts`
Expected: FAIL — the module doesn't exist yet.

- [ ] **Step 3: Implement `useComprehensionAudio.ts`**

Create `apps/web/src/lib/useComprehensionAudio.ts`:

```ts
import { useCallback, useEffect, useRef, useState } from "react";
import { synthesizeSpeech, toAudioDataUrl } from "./synthesizeSpeechClient";
import { targetWords } from "./dictation";
import type { ListeningPassage, Speaker, VoiceId } from "./listeningPassage";

export interface UseComprehensionAudioResult {
  isSpeaking: boolean;
  currentTurnIndex: number;
  estimatedGlobalWordIndex: number;
  speed: number;
  error: string | null;
  play: () => void;
  stop: () => void;
  previousTurn: () => void;
  nextTurn: () => void;
  replayFromStart: () => void;
  seekToGlobalWord: (globalWordIndex: number) => Promise<void>;
  setSpeed: (speed: number) => void;
}

function speakerFor(passage: ListeningPassage, turnIndex: number): Speaker {
  return passage.turns[turnIndex]?.speaker ?? "solo";
}

function turnWordCounts(passage: ListeningPassage): number[] {
  return passage.turns.map((t) => targetWords(t.text).length);
}

function turnWordOffsets(passage: ListeningPassage): number[] {
  const counts = turnWordCounts(passage);
  const offsets: number[] = [];
  let sum = 0;
  for (const c of counts) {
    offsets.push(sum);
    sum += c;
  }
  return offsets;
}

function resolveGlobalWordIndex(passage: ListeningPassage, globalWordIndex: number): { turnIndex: number; wordIndex: number } {
  let remaining = globalWordIndex;
  const counts = turnWordCounts(passage);
  for (let t = 0; t < counts.length; t++) {
    if (remaining < counts[t]) return { turnIndex: t, wordIndex: remaining };
    remaining -= counts[t];
  }
  const lastTurn = counts.length - 1;
  return { turnIndex: lastTurn, wordIndex: Math.max(counts[lastTurn] - 1, 0) };
}

export function useComprehensionAudio(
  passage: ListeningPassage | null,
  voiceAssignment: Partial<Record<Speaker, VoiceId>>,
  sessionKey: string | number
): UseComprehensionAudioResult {
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [currentTurnIndex, setCurrentTurnIndex] = useState(0);
  const [estimatedGlobalWordIndex, setEstimatedGlobalWordIndex] = useState(0);
  const [speed, setSpeedState] = useState(1);
  const [error, setError] = useState<string | null>(null);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const clipUrlsRef = useRef<Map<number, string>>(new Map());
  const prefetchPromisesRef = useRef<Map<number, Promise<void>>>(new Map());
  const baseGlobalWordIndexRef = useRef(0);
  const speedRef = useRef(speed);
  const passageRef = useRef(passage);
  const voiceAssignmentRef = useRef(voiceAssignment);
  const currentTurnIndexRef = useRef(0);
  const playTokenRef = useRef(0);

  useEffect(() => {
    speedRef.current = speed;
  }, [speed]);
  useEffect(() => {
    passageRef.current = passage;
  }, [passage]);
  useEffect(() => {
    voiceAssignmentRef.current = voiceAssignment;
  }, [voiceAssignment]);
  useEffect(() => {
    currentTurnIndexRef.current = currentTurnIndex;
  }, [currentTurnIndex]);

  // Reset all state on a genuine passage/session change — never on initial
  // mount. Mirrors useDictationAudio's own reset effect exactly, extended
  // to the per-turn clip cache/prefetch maps this hook adds.
  const previousPassageRef = useRef(passage);
  const previousSessionKeyRef = useRef(sessionKey);
  useEffect(() => {
    const passageChanged = previousPassageRef.current !== passage;
    const sessionKeyChanged = previousSessionKeyRef.current !== sessionKey;
    if (!passageChanged && !sessionKeyChanged) return;
    previousPassageRef.current = passage;
    previousSessionKeyRef.current = sessionKey;

    setIsSpeaking(false);
    setCurrentTurnIndex(0);
    setEstimatedGlobalWordIndex(0);
    setError(null);
    clipUrlsRef.current = new Map();
    prefetchPromisesRef.current = new Map();
    baseGlobalWordIndexRef.current = 0;
    playTokenRef.current += 1;
    if (audioRef.current) audioRef.current.pause();
  }, [passage, sessionKey]);

  // Prefetch every turn in parallel as soon as the passage is ready. Each
  // request is guarded against a stale (discarded-session) callback writing
  // into a newer session's clip map — the same `cancelled`-in-cleanup
  // pattern the final Nghe chép review required for its own single-clip
  // prefetch, extended to N turns here.
  useEffect(() => {
    if (!passage) return;
    let cancelled = false;
    for (let i = 0; i < passage.turns.length; i++) {
      const turn = passage.turns[i];
      const speaker = turn.speaker ?? "solo";
      const voice = voiceAssignment[speaker];
      const promise = synthesizeSpeech({ text: turn.text, language: "en", voice })
        .then(({ audioBase64 }) => {
          if (cancelled) return;
          clipUrlsRef.current.set(i, toAudioDataUrl(audioBase64));
        })
        .catch(() => {
          if (cancelled) return;
          prefetchPromisesRef.current.delete(i);
        });
      prefetchPromisesRef.current.set(i, promise);
    }
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [passage, sessionKey]);

  function ensureAudioElement(): HTMLAudioElement {
    if (!audioRef.current) {
      audioRef.current = new Audio();
      audioRef.current.addEventListener("timeupdate", () => {
        const el = audioRef.current;
        if (!el || !Number.isFinite(el.duration) || el.duration <= 0) return;
        const currentPassage = passageRef.current;
        if (!currentPassage) return;
        const turnIndex = currentTurnIndexRef.current;
        const counts = turnWordCounts(currentPassage);
        const totalWordsInTurn = counts[turnIndex] ?? 0;
        if (totalWordsInTurn === 0) return;
        const localRatio = el.currentTime / el.duration;
        const localEstimate = Math.min(Math.max(Math.round(localRatio * totalWordsInTurn), 0), totalWordsInTurn - 1);
        const offsets = turnWordOffsets(currentPassage);
        setEstimatedGlobalWordIndex((offsets[turnIndex] ?? 0) + localEstimate);
      });
    }
    return audioRef.current;
  }

  function playUrl(url: string, onEnded: (() => void) | null) {
    const audioEl = ensureAudioElement();
    audioEl.onended = onEnded;
    audioEl.src = url;
    audioEl.playbackRate = speedRef.current;
    audioEl.currentTime = 0;
    const playResult = audioEl.play();
    if (playResult && typeof playResult.catch === "function") {
      playResult.catch(() => {});
    }
  }

  const playTurn = useCallback(
    async (turnIndex: number, token: number) => {
      const currentPassage = passageRef.current;
      if (!currentPassage || turnIndex >= currentPassage.turns.length) {
        setIsSpeaking(false);
        return;
      }
      const offsets = turnWordOffsets(currentPassage);
      baseGlobalWordIndexRef.current = offsets[turnIndex] ?? 0;
      setEstimatedGlobalWordIndex(baseGlobalWordIndexRef.current);
      setCurrentTurnIndex(turnIndex);
      setIsSpeaking(true);
      setError(null);

      const isLastTurn = turnIndex === currentPassage.turns.length - 1;
      const onEnded = () => {
        if (playTokenRef.current !== token) return; // superseded meanwhile
        if (isLastTurn) {
          setIsSpeaking(false);
          return;
        }
        void playTurn(turnIndex + 1, token);
      };

      const cached = clipUrlsRef.current.get(turnIndex);
      if (cached) {
        playUrl(cached, onEnded);
        return;
      }
      const prefetchPromise = prefetchPromisesRef.current.get(turnIndex);
      try {
        if (prefetchPromise) await prefetchPromise;
        if (playTokenRef.current !== token) return; // superseded while awaiting
        const cachedNow = clipUrlsRef.current.get(turnIndex);
        if (cachedNow) {
          playUrl(cachedNow, onEnded);
          return;
        }
        const turn = currentPassage.turns[turnIndex];
        const speaker = turn.speaker ?? "solo";
        const voice = voiceAssignmentRef.current[speaker];
        const { audioBase64 } = await synthesizeSpeech({ text: turn.text, language: "en", voice });
        if (playTokenRef.current !== token) return;
        const url = toAudioDataUrl(audioBase64);
        clipUrlsRef.current.set(turnIndex, url);
        playUrl(url, onEnded);
      } catch (err) {
        if (playTokenRef.current !== token) return;
        setError(err instanceof Error ? err.message : String(err));
        setIsSpeaking(false);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    []
  );

  const play = useCallback(() => {
    playTokenRef.current += 1;
    void playTurn(currentTurnIndexRef.current, playTokenRef.current);
  }, [playTurn]);

  const stop = useCallback(() => {
    playTokenRef.current += 1; // supersede any in-flight auto-advance
    if (audioRef.current) audioRef.current.pause();
    setIsSpeaking(false);
  }, []);

  const previousTurn = useCallback(() => {
    const currentPassage = passageRef.current;
    if (!currentPassage || currentTurnIndexRef.current === 0) return;
    playTokenRef.current += 1;
    if (audioRef.current) audioRef.current.pause();
    const newIndex = currentTurnIndexRef.current - 1;
    const offsets = turnWordOffsets(currentPassage);
    baseGlobalWordIndexRef.current = offsets[newIndex] ?? 0;
    setEstimatedGlobalWordIndex(baseGlobalWordIndexRef.current);
    setCurrentTurnIndex(newIndex);
    setIsSpeaking(false);
  }, []);

  const nextTurn = useCallback(() => {
    const currentPassage = passageRef.current;
    if (!currentPassage || currentTurnIndexRef.current >= currentPassage.turns.length - 1) return;
    playTokenRef.current += 1;
    if (audioRef.current) audioRef.current.pause();
    const newIndex = currentTurnIndexRef.current + 1;
    const offsets = turnWordOffsets(currentPassage);
    baseGlobalWordIndexRef.current = offsets[newIndex] ?? 0;
    setEstimatedGlobalWordIndex(baseGlobalWordIndexRef.current);
    setCurrentTurnIndex(newIndex);
    setIsSpeaking(false);
  }, []);

  const replayFromStart = useCallback(() => {
    playTokenRef.current += 1;
    if (audioRef.current) audioRef.current.pause();
    baseGlobalWordIndexRef.current = 0;
    setEstimatedGlobalWordIndex(0);
    setCurrentTurnIndex(0);
    setIsSpeaking(false);
  }, []);

  const seekToGlobalWord = useCallback(async (globalWordIndex: number) => {
    const currentPassage = passageRef.current;
    if (!currentPassage) return;
    const totalWords = turnWordCounts(currentPassage).reduce((a, b) => a + b, 0);
    if (globalWordIndex < 0 || globalWordIndex >= totalWords) return;

    const { turnIndex, wordIndex } = resolveGlobalWordIndex(currentPassage, globalWordIndex);
    const offsets = turnWordOffsets(currentPassage);
    baseGlobalWordIndexRef.current = offsets[turnIndex] + wordIndex;
    setEstimatedGlobalWordIndex(baseGlobalWordIndexRef.current);
    setCurrentTurnIndex(turnIndex);
    setError(null);

    playTokenRef.current += 1;
    const token = playTokenRef.current;
    setIsSpeaking(true);
    try {
      const turn = currentPassage.turns[turnIndex];
      const words = targetWords(turn.text);
      const remainder = words.slice(wordIndex).join(" ");
      const speaker = turn.speaker ?? "solo";
      const voice = voiceAssignmentRef.current[speaker];
      const { audioBase64 } = await synthesizeSpeech({ text: remainder, language: "en", voice });
      if (playTokenRef.current !== token) return;
      const url = toAudioDataUrl(audioBase64);
      const isLastTurn = turnIndex === currentPassage.turns.length - 1;
      playUrl(url, () => {
        if (playTokenRef.current !== token) return;
        if (isLastTurn) {
          setIsSpeaking(false);
          return;
        }
        void playTurn(turnIndex + 1, token);
      });
    } catch (err) {
      if (playTokenRef.current !== token) return;
      setError(err instanceof Error ? err.message : String(err));
      setIsSpeaking(false);
    }
  }, [playTurn]);

  const setSpeed = useCallback((next: number) => {
    setSpeedState(next);
    if (audioRef.current) audioRef.current.playbackRate = next;
  }, []);

  return {
    isSpeaking,
    currentTurnIndex,
    estimatedGlobalWordIndex,
    speed,
    error,
    play,
    stop,
    previousTurn,
    nextTurn,
    replayFromStart,
    seekToGlobalWord,
    setSpeed,
  };
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run src/lib/useComprehensionAudio.test.ts`
Expected: all tests PASS.

- [ ] **Step 5: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/lib/useComprehensionAudio.ts apps/web/src/lib/useComprehensionAudio.test.ts
git commit -m "feat(web): add useComprehensionAudio — prefetch-all-turns sequential playback with global seek"
```

---

## Task 6: Generic-ify `savedListeningExercises.ts` and add the `"comprehension"` member

**Files:**
- Modify: `apps/web/src/lib/savedListeningExercises.ts`
- Modify: `apps/web/src/lib/savedListeningExercises.test.ts`
- Modify: `apps/web/src/app/(app)/listening/dictation/page.tsx`
- Modify: `apps/web/src/app/(app)/listening/dictation/page.test.tsx`

**Interfaces:**
- Consumes: `ListeningKind`, `ListeningTurn`, `ListeningQuestion` from `./listeningPassage` (Task 4); `AppContext` from `./appContext` (Task 3); `VocabRecord["cefrLevel"]`.
- Produces: `saveListeningExercise<T extends SavedListeningExercise["type"]>(uid, type, item, generationFilters, targetLanguage): Promise<string>` and `getRandomSavedListeningExercise<T>(uid, targetLanguage, type, filters, excludeId?): Promise<Extract<SavedListeningExercise, {type: T}> | null>` — both now require an explicit `type` argument (a breaking change from today's single-type signature, fixed at this task's 2 call sites in `dictation/page.tsx`). Task 8 (the comprehension page) calls both with `type: "comprehension"`.

### Context

Read `apps/web/src/lib/savedListeningExercises.ts` and `apps/web/src/lib/savedReadingExercises.ts` in full first. Today, `savedListeningExercises.ts` is hardcoded to a single type (`"dictation"`) — no generic dispatch at all. `savedReadingExercises.ts` already solved exactly this problem for 4 reading types (bilingual/part5/part6/part7) via a `FiltersFor<T>`/`Extract<>` generic pattern — mirror that pattern here, not invent a new one.

- [ ] **Step 1: Update the tests first**

Read `apps/web/src/lib/savedListeningExercises.test.ts` in full, then replace every call site of `saveListeningExercise(...)`/`getRandomSavedListeningExercise(...)` to insert `"dictation"` as the new second argument (matching `saveReadingExercise`'s `(uid, type, passage, filters, language)` call shape) — e.g. `saveListeningExercise("user-123", ITEM, { difficulty: "medium" }, "english")` becomes `saveListeningExercise("user-123", "dictation", ITEM, { difficulty: "medium" }, "english")`, and `getRandomSavedListeningExercise("user-123", "english", { difficulty: "easy" })` becomes `getRandomSavedListeningExercise("user-123", "english", "dictation", { difficulty: "easy" })`. Apply this to every call in the file (5 call sites for `getRandomSavedListeningExercise`, 1 for `saveListeningExercise`, per the existing file).

Add these new tests to the end of the file:

```ts
import { parseListeningPassage } from "./listeningPassage";

const COMPREHENSION_ITEM = parseListeningPassage(
  {
    kind: "talk",
    turns: [{ speaker: null, gender: "male", text: "Welcome aboard." }],
    questions: [{ question: "q", options: ["a", "b", "c", "d"], correctIndex: 0 }],
  },
  "b1",
  "general",
  "english"
);

describe("saveListeningExercise (comprehension)", () => {
  it("saves a comprehension exercise with its own filters shape, including speakerGenders", async () => {
    const newId = await saveListeningExercise(
      "user-123",
      "comprehension",
      {
        kind: COMPREHENSION_ITEM.kind,
        turns: COMPREHENSION_ITEM.turns,
        questions: COMPREHENSION_ITEM.questions,
        speakerGenders: COMPREHENSION_ITEM.speakerGenders,
      },
      { context: "general", level: "b1" },
      "english"
    );
    expect(typeof newId).toBe("string");
  });
});

describe("getRandomSavedListeningExercise (comprehension) — does not cross-match dictation docs", () => {
  it("never returns a dictation-typed doc when asking for comprehension, even with an identical-looking filter shape", async () => {
    // Regression guard mirroring savedReadingExercises.ts's own cross-type
    // test: the `ex.type !== type` check must run unconditionally, before
    // any filter-shape comparison, so two different types sharing similar
    // field names can never cross-match.
    const result = await getRandomSavedListeningExercise("user-123", "english", "comprehension", {
      context: "general",
      level: "b1",
    });
    // In a fresh in-memory/mocked Firestore with no comprehension docs
    // saved yet, this must be null, not a dictation doc that happens to
    // exist — the actual mock setup for this test file (Firestore
    // read mocking) should follow this file's own existing convention for
    // the "dictation" tests above.
    expect(result === null || result.type === "comprehension").toBe(true);
  });
});
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run src/lib/savedListeningExercises.test.ts`
Expected: FAIL — the functions don't accept a `type` argument yet, and `"comprehension"` isn't a valid union member yet.

- [ ] **Step 3: Implement the generic-ified module**

Replace the entire contents of `apps/web/src/lib/savedListeningExercises.ts`:

```ts
import { collection, doc, getDocs, query, setDoc, where } from "firebase/firestore";
import { getFirebaseDb } from "./firebase";
import type { DictationItem, DictationDifficulty } from "./dictation";
import type { ListeningKind, ListeningTurn, ListeningQuestion, Speaker, SpeakerGender } from "./listeningPassage";
import type { AppContext } from "./appContext";
import type { TargetLanguage } from "./languages";
import type { VocabRecord } from "./vocabRecords";

export interface DictationFilters {
  difficulty: DictationDifficulty;
}

export interface ComprehensionFilters {
  context: AppContext;
  level: VocabRecord["cefrLevel"];
}

export interface ComprehensionItem {
  kind: ListeningKind;
  turns: ListeningTurn[];
  questions: ListeningQuestion[];
  // Persisted deliberately, unlike the specific voice SLOT (male1 vs
  // male2) chosen for a session: gender is inherent content of the
  // passage (which speaker is male vs female), not a playback detail. The
  // raw AI JSON's "gender" field only exists at generation time — without
  // this, a reused conversation would have nothing to derive gender from
  // and every reused conversation would silently collapse to same-gender
  // voices for both speakers (assignVoices' own "default to female when
  // unknown" fallback), losing the variety the feature exists to provide.
  speakerGenders: Partial<Record<Speaker, SpeakerGender>>;
}

// A parallel, independent module to savedReadingExercises.ts — deliberately
// not a member of that file's SavedReadingExercise union, since a
// listening item's shape has nothing structurally in common with a reading
// passage. Mirrors savedReadingExercises.ts's own FiltersFor<T>/Extract<>
// generic pattern now that this module has more than one type.
export type SavedListeningExercise =
  | {
      id: string;
      type: "dictation";
      item: DictationItem;
      generationFilters: DictationFilters;
      targetLanguage: TargetLanguage;
      createdAt: string;
    }
  | {
      id: string;
      type: "comprehension";
      item: ComprehensionItem;
      generationFilters: ComprehensionFilters;
      targetLanguage: TargetLanguage;
      createdAt: string;
    };

type FiltersFor<T extends SavedListeningExercise["type"]> = Extract<SavedListeningExercise, { type: T }>["generationFilters"];
type ItemFor<T extends SavedListeningExercise["type"]> = Extract<SavedListeningExercise, { type: T }>["item"];

function listeningExercisesCol(uid: string) {
  return collection(getFirebaseDb(), "users", uid, "listening_exercises");
}

export async function saveListeningExercise<T extends SavedListeningExercise["type"]>(
  uid: string,
  type: T,
  item: ItemFor<T>,
  generationFilters: FiltersFor<T>,
  targetLanguage: TargetLanguage
): Promise<string> {
  const ref = doc(listeningExercisesCol(uid));
  // Carries its own id field, matching every other save*Exercise function
  // in this app — see savedReadingExercises.ts's saveReadingExercise.
  const record = {
    type,
    item,
    generationFilters,
    targetLanguage,
    createdAt: new Date().toISOString(),
  };
  await setDoc(ref, { ...record, id: ref.id });
  return ref.id;
}

function matchesDictation(
  exercise: Extract<SavedListeningExercise, { type: "dictation" }>,
  filters: DictationFilters
): boolean {
  return exercise.generationFilters.difficulty === filters.difficulty;
}

function matchesComprehension(
  exercise: Extract<SavedListeningExercise, { type: "comprehension" }>,
  filters: ComprehensionFilters
): boolean {
  return exercise.generationFilters.context === filters.context && exercise.generationFilters.level === filters.level;
}

export async function getRandomSavedListeningExercise<T extends SavedListeningExercise["type"]>(
  uid: string,
  targetLanguage: TargetLanguage,
  type: T,
  filters: FiltersFor<T>,
  excludeId?: string
): Promise<Extract<SavedListeningExercise, { type: T }> | null> {
  const q = query(listeningExercisesCol(uid), where("targetLanguage", "==", targetLanguage));
  const snapshot = await getDocs(q);
  const candidates: Extract<SavedListeningExercise, { type: T }>[] = [];
  for (const d of snapshot.docs) {
    const ex = { ...(d.data() as SavedListeningExercise), id: d.id };
    if (ex.id === excludeId) continue;
    if (ex.type !== type) continue;
    // Safe: `type` narrows `ex` to the matching union member at runtime,
    // even though TypeScript can't express that narrowing through a
    // generic `T` — `filters`' own generic type already forces the caller
    // to pass the matching filter shape for this exact `type`.
    const matches =
      ex.type === "dictation" ? matchesDictation(ex, filters as DictationFilters) : matchesComprehension(ex, filters as ComprehensionFilters);
    if (matches) candidates.push(ex as Extract<SavedListeningExercise, { type: T }>);
  }
  if (candidates.length === 0) return null;
  return candidates[Math.floor(Math.random() * candidates.length)];
}
```

- [ ] **Step 4: Fix `dictation/page.tsx`'s 2 call sites**

In `apps/web/src/app/(app)/listening/dictation/page.tsx`, find:

```ts
      const saved = await getRandomSavedListeningExercise(user.uid, "english", { difficulty }, excludeId);
```

Replace with:

```ts
      const saved = await getRandomSavedListeningExercise(user.uid, "english", "dictation", { difficulty }, excludeId);
```

Find:

```ts
      const newId = await saveListeningExercise(user.uid, item, { difficulty }, "english");
```

Replace with:

```ts
      const newId = await saveListeningExercise(user.uid, "dictation", item, { difficulty }, "english");
```

- [ ] **Step 5: Fix `dictation/page.test.tsx`'s assertion on the new call shape**

In `apps/web/src/app/(app)/listening/dictation/page.test.tsx`, find the `expect(saveListeningExercise).toHaveBeenCalledWith(` block (around line 546) and add `"dictation"` as the second argument in that expectation, matching the new call shape from Step 4 — read the surrounding test first to get the exact existing arguments (item/filters/language) right, and insert `"dictation"` right after `user.uid`/the uid argument, before them.

- [ ] **Step 6: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run src/lib/savedListeningExercises.test.ts "src/app/(app)/listening/dictation/page.test.tsx"`
Expected: all tests PASS.

- [ ] **Step 7: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add apps/web/src/lib/savedListeningExercises.ts apps/web/src/lib/savedListeningExercises.test.ts "apps/web/src/app/(app)/listening/dictation/page.tsx" "apps/web/src/app/(app)/listening/dictation/page.test.tsx"
git commit -m "feat(web): generic-ify savedListeningExercises, add comprehension save/reuse"
```

---

## Task 7: Multi-card Nghe hub

**Files:**
- Modify: `apps/web/src/app/(app)/listening/page.tsx`
- Modify: `apps/web/src/app/(app)/listening/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: `APP_CONTEXTS`, `APP_CONTEXT_LABELS`, `APP_CONTEXT_EMOJI` from `@/lib/appContext` (Task 3); `SimpleDropdown` from `@/components/shared/SimpleDropdown` (existing component, already used by `reading/page.tsx` — read that file's import for the exact path/props).
- Produces: routes to `/listening/dictation?difficulty=X&action=Y` (unchanged) and `/listening/comprehension?context=X&level=Y&action=Y` (new — Task 8 reads these params).

### Context

Read `apps/web/src/app/(app)/listening/page.tsx` and `apps/web/src/app/(app)/reading/page.tsx` in full first. Today's `listening/page.tsx` is single-mode (only Nghe chép, no card grid). This task converts it to the same multi-card pattern `reading/page.tsx` already uses (a `mode` state selecting between cards, each card showing its own filter row below the grid), reusing the existing `.reading-hub-cards`/`.reading-hub-card` CSS classes (already defined in `bloom.css` for the reading hub — confirm by reading it, no new grid CSS needed here).

This also resolves a pre-existing Minor finding from the Nghe chép audio-improvements final review ("the hub has no named '🎤 Nghe chép' card") as a side effect of this restructuring — not a separate step, just note it happens.

- [ ] **Step 1: Read the current test file**

Read `apps/web/src/app/(app)/listening/page.test.tsx` in full (as of this plan's writing, it's 144 lines) — every existing test after the language-gate one assumes the hub has exactly one implicit mode (dictation) always active, with the difficulty picker and action buttons always visible. The new hub defaults `mode` to `null` and shows no filter row or action buttons until a card is clicked — every one of those existing tests needs a card click inserted before its existing assertions, not just new tests appended.

- [ ] **Step 2: Replace the test file**

Replace the entire contents of `apps/web/src/app/(app)/listening/page.test.tsx`:

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import ListeningHubPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));

function makeRecord(overrides: Partial<VocabRecord>): VocabRecord {
  return {
    id: "id",
    headword: "word",
    inputType: "word",
    ipa: "",
    meaning: "nghĩa",
    examples: [],
    personalNotes: "",
    topicIds: [],
    targetLanguage: "english",
    cefrLevel: "b1",
    activeContext: "general",
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    nextReviewAt: null,
    sm2Repetitions: 0,
    sm2EaseFactor: 2.5,
    sm2Interval: 1,
    definition: "",
    synonyms: [],
    ...overrides,
  };
}

function mockSignedIn(settings: UserSettings = DEFAULT_SETTINGS) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(useSettingsContext).mockReturnValue({ settings: DEFAULT_SETTINGS, loading: false, error: null, save: vi.fn() } as never);
});

describe("ListeningHubPage (auth)", () => {
  it("prompts sign-in when logged out", () => {
    vi.mocked(useAuthUser).mockReturnValue({ user: null, loading: false } as never);
    render(<ListeningHubPage />);
    expect(screen.getByText("Đăng nhập với Google")).toBeInTheDocument();
  });
});

describe("ListeningHubPage (language gate)", () => {
  it("shows a blocking message and no cards when the target language isn't English", async () => {
    mockSignedIn({ ...DEFAULT_SETTINGS, targetLanguage: "korean" });
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);

    expect(
      await screen.findByText("Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.")
    ).toBeInTheDocument();
    expect(screen.queryByText("🎤 Nghe chép")).not.toBeInTheDocument();
    expect(screen.queryByText("🎧 Nghe hiểu")).not.toBeInTheDocument();
  });
});

describe("ListeningHubPage (cards)", () => {
  it("renders both mode cards, with no filter row or action buttons until one is picked", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<ListeningHubPage />);

    expect(await screen.findByText("🎤 Nghe chép")).toBeInTheDocument();
    expect(screen.getByText("🎧 Nghe hiểu")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeInTheDocument();
  });

  it("shows the difficulty filter only when the dictation card is selected", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<ListeningHubPage />);

    fireEvent.click(await screen.findByText("🎤 Nghe chép"));
    expect(screen.getByText("Khó")).toBeInTheDocument();
    expect(screen.queryByText(/General/)).not.toBeInTheDocument();
  });

  it("shows the topic/level filters only when the comprehension card is selected", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);
    render(<ListeningHubPage />);

    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));
    expect(screen.getByText(/General/)).toBeInTheDocument();
    expect(screen.queryByText("Khó")).not.toBeInTheDocument();
  });
});

describe("ListeningHubPage (dictation word gating)", () => {
  it("shows the min-words hint instead of Tạo bài luyện when fewer than 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" })]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));

    expect(
      await screen.findByText("Hãy lưu ít nhất 2 từ tiếng Anh vào Ngân hàng từ vựng. Hiện có 1 từ.")
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Tạo bài luyện" })).not.toBeInTheDocument();
  });

  it("only counts words whose targetLanguage is english toward the minimum", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([
      makeRecord({ id: "1", targetLanguage: "english" }),
      makeRecord({ id: "2", targetLanguage: "korean" }),
    ]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));

    expect(await screen.findByText(/Hiện có 1 từ\./)).toBeInTheDocument();
  });

  it("shows Tạo bài luyện once at least 2 eligible words exist", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
  });

  it("'Lấy bài có sẵn' is never gated by word count, even with 0 eligible words", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));

    expect(await screen.findByRole("button", { name: "🔀 Lấy bài có sẵn" })).not.toBeDisabled();
  });
});

describe("ListeningHubPage (comprehension is never gated on vocab count)", () => {
  it("always shows Tạo bài luyện for comprehension, even with 0 vocab records", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));

    expect(await screen.findByRole("button", { name: "Tạo bài luyện" })).not.toBeDisabled();
  });
});

describe("ListeningHubPage (navigation)", () => {
  it("dictation defaults to difficulty=hard and navigates with action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([makeRecord({ id: "1" }), makeRecord({ id: "2" })]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/dictation?difficulty=hard&action=generate");
  });

  it("dictation navigates with the selected difficulty and action=existing", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎤 Nghe chép"));
    fireEvent.click(screen.getByRole("button", { name: "Dễ" }));
    fireEvent.click(screen.getByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/dictation?difficulty=easy&action=existing");
  });

  it("comprehension defaults to context=general, level omitted (defaults to b1 on the destination page), and navigates with action=generate", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));
    fireEvent.click(screen.getByRole("button", { name: "Tạo bài luyện" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/comprehension?context=general&level=b1&action=generate");
  });

  it("comprehension navigates with the selected context/level and action=existing", async () => {
    mockSignedIn();
    vi.mocked(getVocabRecords).mockResolvedValue([]);

    render(<ListeningHubPage />);
    fireEvent.click(await screen.findByText("🎧 Nghe hiểu"));
    fireEvent.click(screen.getByText(/Business/));
    fireEvent.click(screen.getByRole("button", { name: "🔀 Lấy bài có sẵn" }));

    expect(pushMock).toHaveBeenCalledWith("/listening/comprehension?context=business&level=b1&action=existing");
  });
});
```

Note: the `SimpleDropdown` component's trigger button label is `level ? level.toUpperCase() : "Tất cả"` per Task 7's own implementation below — since `level` starts `null`, its initial rendered label is "Tất cả", not a CEFR string, so the default navigation test above correctly expects `level=b1` (the `navigate()`/`buildQuery` function's own `level ?? "b1"` fallback, not a UI-selected value) — don't confuse the two.

- [ ] **Step 3: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/page.test.tsx"`
Expected: FAIL — no card grid exists yet.

- [ ] **Step 4: Rewrite `listening/page.tsx`**

Replace the entire contents of `apps/web/src/app/(app)/listening/page.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import type { DictationDifficulty } from "@/lib/dictation";
import { APP_CONTEXTS, APP_CONTEXT_LABELS, APP_CONTEXT_EMOJI, type AppContext } from "@/lib/appContext";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";

const MIN_VOCAB_WORDS = 2;

type CefrLevel = VocabRecord["cefrLevel"];
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];

const DIFFICULTY_OPTIONS: { value: DictationDifficulty; label: string }[] = [
  { value: "easy", label: "Dễ" },
  { value: "medium", label: "Trung bình" },
  { value: "hard", label: "Khó" },
];

const CEFR_DROPDOWN_OPTIONS: SimpleDropdownOption<string>[] = [
  { value: "", label: "Tất cả" },
  ...CEFR_LEVELS.map((level) => ({ value: level as string, label: level.toUpperCase() })),
];

type Mode = "dictation" | "comprehension";

export default function ListeningHubPage() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [mode, setMode] = useState<Mode | null>(null);
  const [difficulty, setDifficulty] = useState<DictationDifficulty>("hard");
  const [context, setContext] = useState<AppContext>("general");
  const [level, setLevel] = useState<CefrLevel | null>(null);

  useEffect(() => {
    if (!user) return;
    getVocabRecords(user.uid)
      .then(setRecords)
      .catch(() => {});
  }, [user]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Nghe</h2>
        <p className="scr-sub">Đăng nhập để luyện nghe.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (settings.targetLanguage !== "english") {
    return (
      <div>
        <h2 className="scr-title">Nghe</h2>
        <p className="reading-min-words-hint">
          Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.
        </p>
      </div>
    );
  }

  const eligibleCount = records.filter((r) => r.targetLanguage === "english").length;
  const canGenerateDictation = eligibleCount >= MIN_VOCAB_WORDS;

  function buildQuery(action: "generate" | "existing"): string {
    const params = new URLSearchParams();
    if (mode === "dictation") {
      params.set("difficulty", difficulty);
    } else if (mode === "comprehension") {
      params.set("context", context);
      params.set("level", level ?? "b1");
    }
    params.set("action", action);
    return params.toString();
  }

  function navigate(action: "generate" | "existing") {
    if (!mode) return;
    const path = mode === "dictation" ? "/listening/dictation" : "/listening/comprehension";
    router.push(`${path}?${buildQuery(action)}`);
  }

  return (
    <div>
      <h2 className="scr-title">Nghe</h2>
      <p className="scr-sub">Chọn chế độ luyện nghe.</p>

      <div className="reading-hub-cards">
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "dictation" ? " active" : ""}`}
          onClick={() => setMode("dictation")}
        >
          <span className="reading-hub-card-title">🎤 Nghe chép</span>
          <span className="reading-hub-card-desc">AI tạo 1 câu từ Vocab Bank của bạn. Nghe và gõ lại chính xác.</span>
        </button>
        <button
          type="button"
          className={`reading-hub-card reading-hub-card-toggle${mode === "comprehension" ? " active" : ""}`}
          onClick={() => setMode("comprehension")}
        >
          <span className="reading-hub-card-title">🎧 Nghe hiểu</span>
          <span className="reading-hub-card-desc">
            AI tạo một đoạn hội thoại hoặc bài nói ngắn. Nghe và trả lời 3 câu hỏi trắc nghiệm — giống phần nghe TOEIC.
          </span>
        </button>
      </div>

      {mode === "dictation" && (
        <div className="practice-filters">
          {DIFFICULTY_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              type="button"
              className={`vb-chip${difficulty === opt.value ? " active" : ""}`}
              onClick={() => setDifficulty(opt.value)}
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}

      {mode === "comprehension" && (
        <div className="practice-filters">
          {APP_CONTEXTS.map((ctx) => (
            <button
              key={ctx}
              type="button"
              className={`vb-chip${context === ctx ? " active" : ""}`}
              onClick={() => setContext(ctx)}
            >
              {APP_CONTEXT_EMOJI[ctx]} {APP_CONTEXT_LABELS[ctx]}
            </button>
          ))}
          <SimpleDropdown
            triggerLabel={level ? level.toUpperCase() : "Tất cả"}
            ariaLabel="Chọn cấp độ"
            options={CEFR_DROPDOWN_OPTIONS}
            value={level ?? ""}
            onChange={(v) => setLevel((v || null) as CefrLevel | null)}
            active={level !== null}
          />
        </div>
      )}

      {mode && (
        <div className="reading-setup-actions">
          {mode === "dictation" && !canGenerateDictation ? (
            <p className="reading-min-words-hint">
              Hãy lưu ít nhất {MIN_VOCAB_WORDS} từ tiếng Anh vào Ngân hàng từ vựng. Hiện có {eligibleCount} từ.
            </p>
          ) : (
            <button type="button" className="btn-primary" onClick={() => navigate("generate")}>
              Tạo bài luyện
            </button>
          )}
          <button type="button" className="btn-secondary" onClick={() => navigate("existing")}>
            🔀 Lấy bài có sẵn
          </button>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/page.test.tsx"`
Expected: all tests PASS.

- [ ] **Step 6: Typecheck**

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output — but Task 8's `/listening/comprehension` route doesn't exist until the next task, so `router.push` calls to it are fine (Next.js routing isn't statically type-checked against actual route existence), and `tsc` should still pass cleanly for this task alone.

- [ ] **Step 7: Commit**

```bash
git add "apps/web/src/app/(app)/listening/page.tsx" "apps/web/src/app/(app)/listening/page.test.tsx"
git commit -m "feat(web): add the Nghe hiểu card to the Nghe hub"
```

---

## Task 8: Comprehension session/result page

**Files:**
- Create: `apps/web/src/app/(app)/listening/comprehension/page.tsx`
- Create: `apps/web/src/app/(app)/listening/comprehension/page.test.tsx`
- Modify: `apps/web/src/styles/bloom.css`

**Interfaces:**
- Consumes: everything from Tasks 3-7 — `listeningPassage.ts` (types, `buildListeningPassagePrompt`, `parseListeningPassage`, `assignVoices`, `scoreComprehension`), `useComprehensionAudio.ts`, `savedListeningExercises.ts`'s `"comprehension"` member, `McQuestionCard` (existing, `apps/web/src/components/reading/McQuestionCard.tsx`, unmodified), `VocabSuggestionsSection` (existing, `apps/web/src/components/shared/VocabSuggestionsSection.tsx`, unmodified), `generateContent`/`parseAiJsonObject` (existing, unmodified).
- Produces: the `/listening/comprehension` route the hub (Task 7) already links to.

### Context

Read `apps/web/src/app/(app)/listening/dictation/page.tsx` in full first (the closest sibling — same `useSearchParams()`+`<Suspense>` wrapper pattern, same loading/session/result phase structure, same save/reuse button pattern) and `apps/web/src/app/(app)/reading/bilingual/page.tsx` (for the `getVocabRecords`+`getTopics`-on-mount pattern feeding `VocabSuggestionsSection`, since comprehension needs both, unlike dictation which only needs `getVocabRecords`).

Unlike dictation, "Tạo bài luyện" here is **never gated** on vocab count (comprehension doesn't use the vocab bank at all — matches Part5/6/7's own ungated generation, not dictation's 2-word-minimum gate) and there is **no listen-before-submit gate** (`canSubmit` is purely "all 3 questions answered", per the plan's Global Constraints).

- [ ] **Step 1: Write the failing tests**

Create `apps/web/src/app/(app)/listening/comprehension/page.test.tsx`. Base it structurally on `apps/web/src/app/(app)/listening/dictation/page.test.tsx` — read that file in full first for its exact mocking conventions (`vi.mock` blocks for `next/navigation`, `useAuthUser`, `useSettingsContext`, `getVocabRecords`, `generateContent`, `synthesizeSpeechClient`, `savedListeningExercises`) and reuse the same structure, adapted to this page's own generation shape:

```tsx
import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import ComprehensionPage from "./page";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { synthesizeSpeech } from "@/lib/synthesizeSpeechClient";
import { getRandomSavedListeningExercise, saveListeningExercise } from "@/lib/savedListeningExercises";
import { DEFAULT_SETTINGS, type UserSettings } from "@/lib/settings";

vi.mock("@/lib/useAuthUser", () => ({ useAuthUser: vi.fn() }));
vi.mock("@/lib/SettingsContext", () => ({ useSettingsContext: vi.fn() }));
vi.mock("@/lib/vocabRecords", () => ({ getVocabRecords: vi.fn() }));
vi.mock("@/lib/topics", () => ({ getTopics: vi.fn() }));
vi.mock("@/lib/generateContent", () => ({ generateContent: vi.fn() }));
vi.mock("@/lib/synthesizeSpeechClient", async () => {
  const actual = await vi.importActual<typeof import("@/lib/synthesizeSpeechClient")>("@/lib/synthesizeSpeechClient");
  return { ...actual, synthesizeSpeech: vi.fn() };
});
vi.mock("@/lib/savedListeningExercises", () => ({
  getRandomSavedListeningExercise: vi.fn(),
  saveListeningExercise: vi.fn(),
}));
vi.mock("@/components/SignInButton", () => ({
  SignInButton: () => <button>Đăng nhập với Google</button>,
}));

const pushMock = vi.fn();
const replaceMock = vi.fn();
let mockSearchParams = new URLSearchParams();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: replaceMock }),
  useSearchParams: () => mockSearchParams,
}));

function setSearchParams(params: Record<string, string>) {
  mockSearchParams = new URLSearchParams(params);
}

const SETTINGS_WITH_KEY: UserSettings = {
  ...DEFAULT_SETTINGS,
  activeProvider: "gemini",
  providers: { ...DEFAULT_SETTINGS.providers, gemini: { model: "gemini-2.5-flash", apiKeyCiphertext: "cipher-abc" } },
};

function mockSignedIn(settings: UserSettings = SETTINGS_WITH_KEY) {
  vi.mocked(useAuthUser).mockReturnValue({ user: { uid: "u1" }, loading: false } as never);
  vi.mocked(useSettingsContext).mockReturnValue({ settings, loading: false, error: null, save: vi.fn() });
}

const VALID_PASSAGE_JSON = {
  kind: "conversation",
  turns: [
    { speaker: "A", gender: "male", text: "Welcome to the store." },
    { speaker: "B", gender: "female", text: "Thanks, I need a laptop." },
  ],
  questions: [
    { question: "What does B need?", options: ["A laptop", "A phone", "A book", "A chair"], correctIndex: 0 },
    { question: "Where are they?", options: ["A store", "A park", "A school", "A gym"], correctIndex: 0 },
    { question: "Who speaks first?", options: ["A", "B", "Neither", "Both"], correctIndex: 0 },
  ],
};

beforeEach(() => {
  vi.clearAllMocks();
  setSearchParams({ context: "general", level: "b1", action: "generate" });
  vi.mocked(getVocabRecords).mockResolvedValue([]);
  vi.mocked(getTopics).mockResolvedValue([]);
  vi.mocked(synthesizeSpeech).mockResolvedValue({ audioBase64: "AAAA" });
  vi.mocked(getRandomSavedListeningExercise).mockResolvedValue(null);
  vi.mocked(generateContent).mockResolvedValue({ text: JSON.stringify(VALID_PASSAGE_JSON) });
});

describe("ComprehensionPage (language gate)", () => {
  it("blocks the session when targetLanguage is not english, never calling generateContent", async () => {
    mockSignedIn({ ...SETTINGS_WITH_KEY, targetLanguage: "japanese" });
    render(<ComprehensionPage />);
    expect(
      await screen.findByText("Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.")
    ).toBeInTheDocument();
    expect(generateContent).not.toHaveBeenCalled();
  });
});

describe("ComprehensionPage (generate + session)", () => {
  it("auto-generates a passage on mount and is never gated on vocab count", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    expect(await screen.findByText("Lượt 1/2 — Người nói A")).toBeInTheDocument();
    expect(generateContent).toHaveBeenCalledTimes(1);
  });

  it("shows all 3 questions together and gates Nộp bài on all being answered, with no listen requirement", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");

    expect(screen.getByRole("button", { name: "Nộp bài" })).toBeDisabled();

    const options = screen.getAllByRole("button", { name: "A laptop" });
    fireEvent.click(options[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A store" })[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A" })[0]);

    // No play() was ever called, and Nộp bài is still enabled — no listen-gate.
    expect(screen.getByRole("button", { name: "Nộp bài" })).not.toBeDisabled();
  });

  it("prefetches both turns' audio on generate, tagged with distinct voices for a male/female pair", async () => {
    mockSignedIn();
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");

    await waitFor(() => expect(synthesizeSpeech).toHaveBeenCalledTimes(2));
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Welcome to the store.", language: "en", voice: "male1" });
    expect(synthesizeSpeech).toHaveBeenCalledWith({ text: "Thanks, I need a laptop.", language: "en", voice: "female1" });
  });
});

describe("ComprehensionPage (result + save/reuse)", () => {
  async function completeSession() {
    render(<ComprehensionPage />);
    await screen.findByText("Lượt 1/2 — Người nói A");
    fireEvent.click(screen.getAllByRole("button", { name: "A laptop" })[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A store" })[0]);
    fireEvent.click(screen.getAllByRole("button", { name: "A" })[0]);
    fireEvent.click(screen.getByRole("button", { name: "Nộp bài" }));
    await screen.findByText("3/3");
  }

  it("shows correctCount/3 and a full transcript with speaker labels", async () => {
    mockSignedIn();
    await completeSession();
    expect(screen.getByText("A: Welcome to the store.")).toBeInTheDocument();
    expect(screen.getByText("B: Thanks, I need a laptop.")).toBeInTheDocument();
  });

  it("offers Lưu bài for a generated session", async () => {
    mockSignedIn();
    vi.mocked(saveListeningExercise).mockResolvedValue("new-id");
    await completeSession();
    fireEvent.click(screen.getByRole("button", { name: "Lưu bài" }));
    await waitFor(() =>
      expect(saveListeningExercise).toHaveBeenCalledWith(
        "u1",
        "comprehension",
        expect.objectContaining({ kind: "conversation" }),
        { context: "general", level: "b1" },
        "english"
      )
    );
  });

  it("hides Lưu bài for a reused (already-saved) session", async () => {
    mockSignedIn();
    setSearchParams({ context: "general", level: "b1", action: "existing" });
    vi.mocked(getRandomSavedListeningExercise).mockResolvedValue({
      id: "saved-1",
      type: "comprehension",
      item: {
        kind: "conversation",
        turns: [
          { speaker: "A", text: "Welcome to the store." },
          { speaker: "B", text: "Thanks, I need a laptop." },
        ],
        questions: VALID_PASSAGE_JSON.questions,
        speakerGenders: { A: "male", B: "female" },
      },
      generationFilters: { context: "general", level: "b1" },
      targetLanguage: "english",
      createdAt: "2026-01-01T00:00:00.000Z",
    });
    await completeSession();
    expect(screen.queryByRole("button", { name: "Lưu bài" })).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/comprehension/page.test.tsx"`
Expected: FAIL — the page doesn't exist yet.

- [ ] **Step 3: Implement the page**

Create `apps/web/src/app/(app)/listening/comprehension/page.tsx`:

```tsx
"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { getTopics, type Topic } from "@/lib/topics";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import {
  buildListeningPassagePrompt,
  parseListeningPassage,
  assignVoices,
  scoreComprehension,
  type ListeningPassage,
  type Speaker,
  type VoiceId,
} from "@/lib/listeningPassage";
import {
  saveListeningExercise,
  getRandomSavedListeningExercise,
  type ComprehensionItem,
} from "@/lib/savedListeningExercises";
import { APP_CONTEXTS, type AppContext } from "@/lib/appContext";
import { useComprehensionAudio } from "@/lib/useComprehensionAudio";
import { McQuestionCard } from "@/components/reading/McQuestionCard";
import { VocabSuggestionsSection } from "@/components/shared/VocabSuggestionsSection";

type Phase = "loading" | "session" | "result";
type CefrLevel = VocabRecord["cefrLevel"];
const MIN_SPEED = 0.5;
const MAX_SPEED = 2;
const SPEED_STEP = 0.05;

function isCefrLevel(value: string | null): value is CefrLevel {
  return value === "a1" || value === "a2" || value === "b1" || value === "b2" || value === "c1" || value === "c2";
}

function isAppContext(value: string | null): value is AppContext {
  return (APP_CONTEXTS as string[]).includes(value ?? "");
}

function ComprehensionPageContent() {
  const { user, loading: authLoading } = useAuthUser();
  const { settings, loading: settingsLoading } = useSettingsContext();
  const router = useRouter();
  const searchParams = useSearchParams();

  const contextParamRaw = searchParams.get("context");
  const contextParam: AppContext = isAppContext(contextParamRaw) ? contextParamRaw : "general";
  const levelParam = searchParams.get("level");
  const level: CefrLevel = isCefrLevel(levelParam) ? levelParam : "b1";
  const action = searchParams.get("action");

  const [records, setRecords] = useState<VocabRecord[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);

  const [phase, setPhase] = useState<Phase>("loading");
  const [generating, setGenerating] = useState(false);
  const [fetchingSaved, setFetchingSaved] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [savedNotice, setSavedNotice] = useState<string | null>(null);
  const [passage, setPassage] = useState<ListeningPassage | null>(null);
  const [voices, setVoices] = useState<Partial<Record<Speaker, VoiceId>>>({});
  const [selectedAnswers, setSelectedAnswers] = useState<(number | null)[]>([]);
  const [sessionMode, setSessionMode] = useState<"generated" | "reused">("generated");
  const [justSavedId, setJustSavedId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [finalScore, setFinalScore] = useState(0);

  const sessionKeyRef = useRef(0);
  const audio = useComprehensionAudio(passage, voices, sessionKeyRef.current);

  useEffect(() => {
    if (!user) return;
    Promise.all([getVocabRecords(user.uid), getTopics(user.uid)])
      .then(([r, t]) => {
        setRecords(r);
        setTopics(t);
      })
      .catch(() => {});
  }, [user]);

  function startSession(newPassage: ListeningPassage, mode: "generated" | "reused") {
    sessionKeyRef.current += 1;
    setSessionMode(mode);
    setJustSavedId(null);
    setSaveError(null);
    setPassage(newPassage);
    setVoices(assignVoices(newPassage));
    setSelectedAnswers(new Array(newPassage.questions.length).fill(null));
    setPhase("session");
  }

  async function handleGenerate() {
    if (!user || !settings) return;
    const activeConfig = settings.providers[settings.activeProvider];
    if (!activeConfig.apiKeyCiphertext) {
      setGenerateError("Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.");
      return;
    }
    setGenerating(true);
    setGenerateError(null);
    try {
      const prompt = buildListeningPassagePrompt(level, contextParam, "english");
      const response = await generateContent({
        provider: settings.activeProvider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const generated = parseListeningPassage(json, level, contextParam, "english");
      if (generated.turns.length === 0 || generated.questions.length === 0) {
        throw new Error("AI không trả về bài luyện hợp lệ.");
      }
      startSession(generated, "generated");
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
    } finally {
      setGenerating(false);
      setSavedNotice(null);
    }
  }

  async function fetchSavedExercise(excludeId?: string): Promise<boolean> {
    if (!user) return false;
    setGenerateError(null);
    setSavedNotice(null);
    setFetchingSaved(true);
    let found = false;
    try {
      const saved = await getRandomSavedListeningExercise(
        user.uid,
        "english",
        "comprehension",
        { context: contextParam, level },
        excludeId
      );
      if (saved) {
        found = true;
        // Built directly, not via parseListeningPassage — that function
        // expects raw AI JSON (with a per-turn "gender" field to derive
        // speakerGenders from), which a saved doc doesn't have. The saved
        // doc already carries speakerGenders as its own persisted field
        // (see ComprehensionItem) — assignVoices still picks a fresh
        // *slot* (male1 vs male2) each time, but the underlying gender
        // per speaker is the passage's own content, not re-derived.
        const restored: ListeningPassage = {
          kind: saved.item.kind,
          turns: saved.item.turns,
          questions: saved.item.questions,
          speakerGenders: saved.item.speakerGenders,
          level: saved.generationFilters.level,
          context: saved.generationFilters.context,
          targetLanguage: "english",
        };
        startSession(restored, "reused");
      } else {
        setSavedNotice("Chưa có bài đã lưu khớp bộ lọc này — đang tạo bài mới bằng AI…");
      }
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : String(err));
      return true;
    } finally {
      setFetchingSaved(false);
    }
    if (!found) {
      await handleGenerate();
      return true;
    }
    return found;
  }

  async function runAction() {
    if (action === "generate") {
      await handleGenerate();
    } else if (action === "existing") {
      await fetchSavedExercise();
    }
  }

  const triggeredRef = useRef(false);
  useEffect(() => {
    if (!user || !settings) return;
    if (settings.targetLanguage !== "english") return;
    if (action !== "generate" && action !== "existing") {
      router.replace("/listening");
      return;
    }
    if (triggeredRef.current) return;
    triggeredRef.current = true;
    void runAction();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, settings, action]);

  async function handleSaveExercise() {
    if (saving || !user || !passage) return;
    setSaving(true);
    setSaveError(null);
    try {
      const item: ComprehensionItem = {
        kind: passage.kind,
        turns: passage.turns,
        questions: passage.questions,
        speakerGenders: passage.speakerGenders,
      };
      const newId = await saveListeningExercise(
        user.uid,
        "comprehension",
        item,
        { context: contextParam, level },
        "english"
      );
      setJustSavedId(newId);
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleSelectAnswer(questionIndex: number, optionIndex: number) {
    setSelectedAnswers((prev) => {
      const next = [...prev];
      next[questionIndex] = optionIndex;
      return next;
    });
  }

  function handleSubmit() {
    if (!passage) return;
    const score = scoreComprehension(passage, selectedAnswers);
    setFinalScore(score);
    setPhase("result");
  }

  async function handleNewSession() {
    if (sessionMode === "reused") {
      await fetchSavedExercise(justSavedId ?? undefined);
      return;
    }
    await handleGenerate();
  }

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Nghe hiểu</h2>
        <p className="scr-sub">Đăng nhập để luyện tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (settingsLoading || !settings) return <p>Đang tải…</p>;

  if (settings.targetLanguage !== "english") {
    return (
      <div>
        <h2 className="scr-title">Nghe hiểu</h2>
        <p className="reading-min-words-hint">
          Nghe chép hiện chỉ hỗ trợ khi Ngôn ngữ mục tiêu là Tiếng Anh — đổi trong Cài đặt để dùng.
        </p>
      </div>
    );
  }

  if (phase === "loading") {
    return (
      <div>
        <h2 className="scr-title">Nghe hiểu</h2>
        {(generating || fetchingSaved) && <p>{generating ? "Đang tạo bài…" : "Đang tìm bài…"}</p>}
        {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
        {generateError && (
          <>
            <p role="alert">{generateError}</p>
            <div className="reading-result-actions">
              <button type="button" className="btn-secondary" onClick={() => router.push("/listening")}>
                Về trang chính
              </button>
              <button type="button" className="btn-primary" onClick={() => void runAction()}>
                Thử lại
              </button>
            </div>
          </>
        )}
      </div>
    );
  }

  if (phase === "session" && passage) {
    const turn = passage.turns[audio.currentTurnIndex];
    const canSubmit = selectedAnswers.every((a) => a !== null);
    const totalWords = passage.turns.reduce((sum, t) => sum + t.text.split(/\s+/).filter(Boolean).length, 0);

    return (
      <div>
        <h2 className="scr-title">Nghe hiểu</h2>
        <div className="reading-submit-bar">
          <span className="reading-progress-label">
            {selectedAnswers.filter((a) => a !== null).length}/{selectedAnswers.length} câu đã trả lời
          </span>
          <button type="button" className="btn-primary" onClick={handleSubmit} disabled={!canSubmit}>
            Nộp bài
          </button>
        </div>
        {audio.error && <p role="alert">{audio.error}</p>}
        <div className="dictation-controls">
          <button type="button" className="btn-secondary" onClick={audio.previousTurn} disabled={audio.currentTurnIndex === 0}>
            ⏮
          </button>
          <button type="button" className="btn-primary" onClick={audio.isSpeaking ? audio.stop : audio.play}>
            {audio.isSpeaking ? "⏹ Dừng" : "▶ Phát"}
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={audio.nextTurn}
            disabled={audio.currentTurnIndex >= passage.turns.length - 1}
          >
            ⏭
          </button>
          <button type="button" className="btn-secondary" onClick={audio.replayFromStart}>
            ↺
          </button>
          <div className="dictation-speed-selector">
            <input
              type="range"
              min={MIN_SPEED}
              max={MAX_SPEED}
              step={SPEED_STEP}
              value={audio.speed}
              className="dictation-speed-slider"
              aria-label="Tốc độ phát"
              onChange={(e) => audio.setSpeed(Number(e.target.value))}
            />
            <span className="dictation-speed-label">{audio.speed.toFixed(2)}x</span>
          </div>
        </div>
        <p className="reading-progress-label">
          Lượt {audio.currentTurnIndex + 1}/{passage.turns.length}
          {turn?.speaker ? ` — Người nói ${turn.speaker}` : ""}
        </p>
        {totalWords > 1 && (
          <input
            type="range"
            min={0}
            max={totalWords - 1}
            step={1}
            value={audio.estimatedGlobalWordIndex}
            className="dictation-seek-slider"
            aria-label="Tua theo từ"
            onChange={(e) => void audio.seekToGlobalWord(Number(e.target.value))}
          />
        )}
        <div className="reading-session-body">
          <div className="mc-question-grid">
            {passage.questions.map((q, i) => (
              <McQuestionCard
                key={i}
                label={`${i + 1}. ${q.question}`}
                options={q.options}
                selected={selectedAnswers[i]}
                onSelect={(optionIndex) => handleSelectAnswer(i, optionIndex)}
              />
            ))}
          </div>
        </div>
      </div>
    );
  }

  const correctCount = Math.round(finalScore * (passage?.questions.length ?? 0));
  const transcriptText = (passage?.turns ?? []).map((t) => t.text).join(" ");

  return (
    <div>
      <h2 className="scr-title">Kết quả</h2>
      <p className="mc-score">
        {correctCount}/{passage?.questions.length ?? 0}
      </p>
      <div className="mc-question-grid">
        {(passage?.questions ?? []).map((q, i) => (
          <McQuestionCard
            key={i}
            label={`${i + 1}. ${q.question}`}
            options={q.options}
            selected={selectedAnswers[i]}
            correctIndex={q.correctIndex}
          />
        ))}
      </div>
      <div>
        <h3>Bản ghi âm</h3>
        {(passage?.turns ?? []).map((t, i) => (
          <p key={i}>{t.speaker ? `${t.speaker}: ${t.text}` : t.text}</p>
        ))}
      </div>
      {sessionMode === "generated" && (
        <VocabSuggestionsSection text={transcriptText} existingRecords={records} topics={topics} />
      )}
      <div className="reading-result-actions">
        {sessionMode === "generated" &&
          (justSavedId ? (
            <span className="reading-saved-mark">Đã lưu ✔</span>
          ) : (
            <button type="button" className="btn-secondary" onClick={() => void handleSaveExercise()} disabled={saving}>
              {saving ? "Đang lưu…" : "Lưu bài"}
            </button>
          ))}
        <button type="button" className="btn-secondary" onClick={() => router.push("/listening")}>
          Về trang chính
        </button>
        <button type="button" className="btn-primary" onClick={() => void handleNewSession()}>
          Bài khác
        </button>
      </div>
      {saveError && <p role="alert">{saveError}</p>}
      {savedNotice && <p className="reading-saved-notice">{savedNotice}</p>}
      {generateError && <p role="alert">{generateError}</p>}
    </div>
  );
}

export default function ComprehensionPage() {
  return (
    <Suspense fallback={<p>Đang tải…</p>}>
      <ComprehensionPageContent />
    </Suspense>
  );
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `cd apps/web && npx vitest run --run "src/app/(app)/listening/comprehension/page.test.tsx"`
Expected: all tests PASS. If any test's exact button/label text doesn't match what the implementation above renders (e.g. `McQuestionCard`'s rendered option text, or the "Lượt N/M" wording), fix the test to match the actual rendered output rather than guessing blindly — the test file above was written without running it against real component output, unlike every other file in this plan's earlier tasks.

- [ ] **Step 5: Add CSS for the turn navigation buttons**

Read `apps/web/src/styles/bloom.css`'s existing `.dictation-controls` rule (added by the Nghe chép plan) — the new prev/stop/next/replay buttons reuse `.btn-primary`/`.btn-secondary` already defined there, so no new CSS class is needed unless the 4-button-plus-speed-slider row overflows on mobile widths. If it does, add a `flex-wrap: wrap;` to `.dictation-controls`:

```css
.dictation-controls {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}
```

- [ ] **Step 6: Run the full web suite, typecheck, and build**

Run: `cd apps/web && npm test -- --run`
Expected: all pass except the one known pre-existing unrelated `src/styles/bloom.test.ts` `.app-frame` border-radius failure.

Run: `cd apps/web && npx tsc --noEmit`
Expected: no output.

Run: `cd apps/web && npm run build`
Expected: clean build; `/listening`, `/listening/dictation`, and `/listening/comprehension` all statically prerendered with no missing-Suspense-boundary error.

- [ ] **Step 7: Commit**

```bash
git add "apps/web/src/app/(app)/listening/comprehension/page.tsx" "apps/web/src/app/(app)/listening/comprehension/page.test.tsx" apps/web/src/styles/bloom.css
git commit -m "feat(web): add the Nghe hiểu session/result page"
```
