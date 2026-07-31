from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db.database import init_db
from routers import auth_router, voice_router
from services import tts_service

app = FastAPI(
    title="Recupera tu voz — API",
    description="Backend con autenticación y clonación de voz privada por usuario",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, pon solo tu dominio
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(voice_router.router)

@app.on_event("startup")
async def startup():
    init_db()
    tts_service.load_models()

@app.get("/")
def root():
    return {
        "status": "online",
        "models_ready": tts_service.models_ready(),
    }
