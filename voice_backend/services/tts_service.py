import os
import io
import shutil
import soundfile as sf

VOICES_DIR = os.getenv("VOICES_DIR", "/app/voices")

_tts_engine = None
_converter  = None
_tgt_se_cache = {}

def load_models():
    global _tts_engine, _converter
    try:
        from openvoice.api import ToneColorConverter
        from melo.api import TTS

        print("Cargando TTS base (MeloTTS)...")
        _tts_engine = TTS(language="ES", device="cuda")

        print("Cargando conversor de timbre (OpenVoice)...")
        _converter = ToneColorConverter(
            "/app/checkpoints_v2/converter/config.json", device="cuda"
        )
        _converter.load_ckpt("/app/checkpoints_v2/converter/checkpoint.pth")

        print("✅ Modelos cargados")
    except Exception as e:
        import traceback; traceback.print_exc()
        print(f"⚠️  Error cargando modelos: {e}")

def models_ready() -> bool:
    return _tts_engine is not None and _converter is not None

def voice_path(user_id: str) -> str:
    return os.path.join(VOICES_DIR, user_id, "reference.wav")

def has_voice(user_id: str) -> bool:
    return os.path.exists(voice_path(user_id))

def save_reference_audio(user_id: str, raw_bytes: bytes, ext: str = ".wav") -> str:
    import librosa
    user_dir = os.path.join(VOICES_DIR, user_id)
    os.makedirs(user_dir, exist_ok=True)

    raw_path = os.path.join(user_dir, f"raw{ext}")
    with open(raw_path, "wb") as f:
        f.write(raw_bytes)

    out_path = voice_path(user_id)
    hps_sr = _converter.hps.data.sampling_rate
    audio, sr = librosa.load(raw_path, sr=None, mono=True)
    if sr != hps_sr:
        audio = librosa.resample(audio, orig_sr=sr, target_sr=hps_sr)
    sf.write(out_path, audio, hps_sr, subtype="PCM_16")
    os.remove(raw_path)

    # Invalidar caché del embedding para este usuario
    if user_id in _tgt_se_cache:
        del _tgt_se_cache[user_id]

    return out_path

def delete_voice(user_id: str):
    user_dir = os.path.join(VOICES_DIR, user_id)
    if os.path.exists(user_dir):
        shutil.rmtree(user_dir)
    if user_id in _tgt_se_cache:
        del _tgt_se_cache[user_id]

def _get_tgt_se(user_id: str):
    """Extrae y cachea el embedding de voz del usuario."""
    if user_id not in _tgt_se_cache:
        from openvoice import se_extractor
        ref_path = voice_path(user_id)
        tgt_se, _ = se_extractor.get_se(ref_path, _converter, vad=True)
        _tgt_se_cache[user_id] = tgt_se
    return _tgt_se_cache[user_id]

def synthesize(user_id: str, text: str, speed: float = 1.0) -> bytes:
    if not models_ready():
        raise RuntimeError("Modelos TTS no disponibles")
    if not has_voice(user_id):
        raise ValueError("Este usuario no tiene voz clonada")

    tmp_base = f"/tmp/{user_id}_base.wav"
    tmp_out  = f"/tmp/{user_id}_out.wav"

    try:
        # 1. Síntesis con voz base (MeloTTS)
        speaker_id = list(_tts_engine.hps.data.spk2id.values())[0]
        _tts_engine.tts_to_file(text, speaker_id, tmp_base, speed=speed)

        # 2. Embedding fuente: extraer directamente del converter (audio corto)
        src_se = _converter.extract_se(tmp_base)

        # 3. Embedding objetivo: desde el audio de referencia del usuario (cacheado)
        tgt_se = _get_tgt_se(user_id)

        # 4. Convertir timbre
        _converter.convert(
            audio_src_path=tmp_base,
            src_se=src_se,
            tgt_se=tgt_se,
            output_path=tmp_out,
            tau=0.7,
        )

        return _wav_to_mp3(tmp_out)

    finally:
        for p in [tmp_base, tmp_out]:
            if os.path.exists(p):
                os.remove(p)

def _wav_to_mp3(path: str) -> bytes:
    try:
        from pydub import AudioSegment
        seg = AudioSegment.from_wav(path)
        buf = io.BytesIO()
        seg.export(buf, format="mp3", bitrate="128k")
        return buf.getvalue()
    except ImportError:
        with open(path, "rb") as f:
            return f.read()