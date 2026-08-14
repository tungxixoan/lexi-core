from fastapi import FastAPI

app = FastAPI(title="LexiCore TTS/STT Service")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
