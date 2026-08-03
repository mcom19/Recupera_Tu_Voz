from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel
from db.database import get_db
from models.db_models import User, UserVoice
from services.auth_service import get_current_user
from services import tts_service
import os
import io
import traceback

router = APIRouter(prefix="/voice", tags=["voice"])

ALLOWED_EXTENSIONS = {".wav", ".mp3", ".m4a", ".ogg", ".flac"}
MAX_FILE_MB = 20

class TTSRequest(BaseModel):
    text: str
    speed: float = 1.0

class VoiceStatusResponse(BaseModel):
    has_voice: bool
    cloned_at: str | None = None

@router.get("/status", response_model=VoiceStatusResponse)
def voice_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    voice = db.query(UserVoice).filter(UserVoice.user_id == current_user.id).first()
    return VoiceStatusResponse(
        has_voice=voice is not None,
        cloned_at=voice.cloned_at.isoformat() if voice else None,
    )

@router.post("/upload")
async def upload_voice(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, f"Formato no permitido. Usa: {', '.join(ALLOWED_EXTENSIONS)}")

    raw_bytes = await file.read()
    if len(raw_bytes) > MAX_FILE_MB * 1024 * 1024:
        raise HTTPException(400, f"El archivo no puede superar {MAX_FILE_MB}MB")

    try:
        path = tts_service.save_reference_audio(current_user.id, raw_bytes, ext)
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(500, f"Error procesando audio: {str(e)}")

    voice = db.query(UserVoice).filter(UserVoice.user_id == current_user.id).first()
    if voice:
        voice.audio_path = path
        from datetime import datetime
        voice.cloned_at = datetime.utcnow()
    else:
        voice = UserVoice(user_id=current_user.id, audio_path=path)
        db.add(voice)
    db.commit()

    return {"status": "ok", "message": "Voz clonada correctamente"}

@router.post("/tts")
def synthesize(
    req: TTSRequest,
    current_user: User = Depends(get_current_user),
):
    if not tts_service.models_ready():
        raise HTTPException(503, "Motor de voz no disponible aún, espera unos segundos")

    if not tts_service.has_voice(current_user.id):
        raise HTTPException(400, "No tienes voz clonada. Sube primero un audio con POST /voice/upload")

    if not req.text.strip():
        raise HTTPException(400, "El texto no puede estar vacío")

    if len(req.text) > 500:
        raise HTTPException(400, "Máximo 500 caracteres por petición")

    try:
        mp3_bytes = tts_service.synthesize(
            user_id=current_user.id,
            text=req.text,
            speed=req.speed,
        )
    except Exception as e:
        # Traceback completo en los logs del contenedor
        traceback.print_exc()
        raise HTTPException(500, f"Error de síntesis: {str(e)}")

    return StreamingResponse(
        io.BytesIO(mp3_bytes),
        media_type="audio/mpeg",
        headers={"Content-Disposition": "inline; filename=tts.mp3"},
    )

@router.delete("/")
def delete_voice(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tts_service.delete_voice(current_user.id)
    db.query(UserVoice).filter(UserVoice.user_id == current_user.id).delete()
    db.commit()
    return {"status": "ok", "message": "Voz eliminada"}