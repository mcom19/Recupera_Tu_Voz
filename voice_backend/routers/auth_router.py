from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from db.database import get_db
from models.db_models import User
from services.auth_service import hash_password, verify_password, create_token

router = APIRouter(prefix="/auth", tags=["auth"])

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    name: str = ""

class AuthResponse(BaseModel):
    token: str
    user_id: str
    name: str
    email: str
    has_voice: bool

@router.post("/register", response_model=AuthResponse)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    if len(req.password) < 6:
        raise HTTPException(400, "La contraseña debe tener al menos 6 caracteres")

    existing = db.query(User).filter(User.email == req.email).first()
    if existing:
        raise HTTPException(400, "Ya existe una cuenta con ese email")

    user = User(
        email=req.email,
        hashed_pw=hash_password(req.password),
        name=req.name,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return AuthResponse(
        token=create_token(user.id),
        user_id=user.id,
        name=user.name,
        email=user.email,
        has_voice=False,
    )

@router.post("/login", response_model=AuthResponse)
def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == form.username).first()
    if not user or not verify_password(form.password, user.hashed_pw):
        raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")

    from services import tts_service
    has_voice = tts_service.has_voice(user.id)

    return AuthResponse(
        token=create_token(user.id),
        user_id=user.id,
        name=user.name,
        email=user.email,
        has_voice=has_voice,
    )
