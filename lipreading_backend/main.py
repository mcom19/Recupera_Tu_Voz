"""
Backend de lipreading — STUB local para pruebas básicas.

Todavía no hay un modelo VSR (Visual Speech Recognition) integrado.
Este servicio solo sirve para validar el pipeline completo: la app
graba un vídeo, lo sube aquí por POST /lipreading/speak, y este stub
responde con un audio de prueba (un tono generado, sin depender de
ningún asset externo) y un texto reconocido "de mentira" en la
cabecera `x-recognized-text` — el mismo contrato que usará el modelo
real cuando esté listo (ver PROTOTIPO_LECTURA_LABIOS.md en la raíz del
proyecto Flutter).

Cuando el modelo VSR esté listo, sustituye el cuerpo de
`lipreading_speak()` por la inferencia real; el resto (CORS, forma de
la respuesta) no debería tener que cambiar.
"""
import io
import math
import random
import struct
import wave

from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

app = FastAPI(
    title="Recupera tu voz — Lipreading (stub local)",
    description="Servidor mínimo para probar el pipeline de lectura de labios sin modelo real todavía.",
    version="0.1.0",
)

# CORS abierto: la app Flutter Web (localhost:<puerto de flutter run>)
# y este backend (localhost:8010) son "orígenes" distintos para el
# navegador, así que sin esto el navegador bloquea la petición.
# `expose_headers` es imprescindible: sin él, el navegador oculta la
# cabecera x-recognized-text a la app aunque la respuesta la traiga.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["x-recognized-text"],
)

DEMO_PHRASES = [
    "hola, ¿cómo estás?",
    "tengo sed",
    "necesito ayuda",
    "gracias",
    "buenos días",
]


def _demo_tone_wav(freq: float = 440.0, duration: float = 0.6, sample_rate: int = 16000) -> bytes:
    """Genera un tono corto en WAV en memoria, sin ningún asset externo."""
    n_samples = int(duration * sample_rate)
    frames = bytearray()
    for i in range(n_samples):
        value = int(32767 * 0.3 * math.sin(2 * math.pi * freq * (i / sample_rate)))
        frames += struct.pack("<h", value)

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(bytes(frames))
    return buf.getvalue()


@app.get("/")
def root():
    return {"status": "online", "mode": "demo-stub", "endpoint": "/lipreading/speak"}


@app.post("/lipreading/speak")
async def lipreading_speak(video: UploadFile = File(...)):
    # Se lee y se descarta: de momento no hay modelo VSR que lo
    # procese. Aquí es donde se conectará la inferencia real cuando
    # esté lista.
    _ = await video.read()

    texto = random.choice(DEMO_PHRASES)
    audio_bytes = _demo_tone_wav()

    return StreamingResponse(
        io.BytesIO(audio_bytes),
        media_type="audio/wav",
        headers={"x-recognized-text": texto},
    )
