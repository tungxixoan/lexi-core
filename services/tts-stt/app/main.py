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
