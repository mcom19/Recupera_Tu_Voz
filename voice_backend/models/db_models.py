from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship, declarative_base
from datetime import datetime
import uuid

Base = declarative_base()

def gen_id():
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"

    id            = Column(String, primary_key=True, default=gen_id)
    email         = Column(String, unique=True, nullable=False, index=True)
    hashed_pw     = Column(String, nullable=False)
    name          = Column(String, default="")
    created_at    = Column(DateTime, default=datetime.utcnow)
    is_active     = Column(Boolean, default=True)

    voice         = relationship("UserVoice", back_populates="user", uselist=False, cascade="all, delete")

class UserVoice(Base):
    __tablename__ = "user_voices"

    id            = Column(String, primary_key=True, default=gen_id)
    user_id       = Column(String, ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    audio_path    = Column(String, nullable=False)   # path al WAV de referencia
    cloned_at     = Column(DateTime, default=datetime.utcnow)

    user          = relationship("User", back_populates="voice")
