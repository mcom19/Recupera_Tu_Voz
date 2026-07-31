# Revisión técnica — voice_backend

FastAPI + SQLite/SQLAlchemy + JWT, con clonación de voz (MeloTTS + OpenVoice) en Docker con GPU. Revisión de código, no pentest.

## Críticos

**`SECRET_KEY` sin definir en producción.** `auth_service.py` usa un valor por defecto (`"cambia-esto-en-produccion..."`) si no hay variable de entorno `SECRET_KEY`, pero `docker-compose.yml` no la define. Tal como está el compose, en producción se firmarían los JWT con esa clave pública y cualquiera podría forjar tokens de cualquier usuario. Hay que añadir `SECRET_KEY` (generada con `openssl rand -hex 32`) a `docker-compose.yml` o a un `.env`, y lo más seguro es que `auth_service.py` falle al arrancar si la variable no existe en vez de usar un default.

**Conflicto de versión de `torch` entre Dockerfile y `requirements.txt`.** El Dockerfile instala `torch==2.1.0+torchaudio==2.1.0` con soporte CUDA (`--index-url .../cu121`), pero luego `pip install -r requirements.txt` reinstala `torch==2.1.0+cpu` y `torchaudio==2.1.0+cpu`, que pisan la build de GPU. El contenedor probablemente termina corriendo TTS en CPU pese al `runtime: nvidia`. Hay que quitar esas dos líneas de `requirements.txt` (o fijar el índice CUDA también ahí).

**Audios y BD de usuarios reales dentro del zip.** El backend traía `voice_app.db` y 6 carpetas en `voices/` con `reference.wav` (grabaciones de voz reales, ~3.8MB cada una). Son datos personales/biométricos — no deberían circular por email/zip ni acabar en git. Ya añadí `voices/` y `voice_app.db` al `.gitignore` del proyecto; conviene borrarlos del zip original y, si son de pruebas, regenerarlos localmente.

## Importantes

- **CORS `allow_origins=["*"]` + `allow_credentials=True`** (`main.py`): esta combinación es inválida por spec (los navegadores la rechazan) y además es la config más permisiva posible. Cuando se fije el dominio de producción, listar orígenes explícitos.
- **Sin rate limiting en `/auth/login` y `/auth/register`**: expuesto a fuerza bruta de contraseñas. Añadir algo como `slowapi` o limitarlo a nivel de proxy.
- **Validación de audio solo por extensión** (`voice_router.py`): un archivo renombrado a `.wav` que no sea audio real pasa la primera comprobación y solo falla (o no) dentro de `librosa.load`. Conviene validar el contenido (p.ej. con `soundfile.info()` en un try/except antes de aceptar el archivo) y limitar duración además de tamaño.
- **JWT de 30 días sin revocación**: si se filtra un token, es válido un mes completo y no hay forma de invalidarlo (no hay logout ni blacklist). Para una app con datos de voz de personas vulnerables, valorar tokens más cortos + refresh token.

## Menores / mejoras

- `get_db()` no hace `rollback()` en caso de excepción antes del `close()`.
- `_tgt_se_cache` (embeddings de voz en memoria) crece sin límite por usuario, sin TTL ni tope de tamaño.
- Contraseña mínima de 6 caracteres es bajo; considerar 8+ y alguna regla básica.
- `docker-compose.yml` fija `runtime: nvidia` de forma incondicional — el despliegue falla en cualquier entorno sin GPU/nvidia-docker instalado; documentarlo o hacerlo opcional.
- No hay verificación de email en el registro.

## Lo que está bien

Uso de SQLAlchemy ORM (sin SQL injection), contraseñas con bcrypt vía passlib, borrado de voz que limpia tanto BD como ficheros en disco, separación clara routers/services/models, y el pin de `bcrypt==4.0.1` evita el bug conocido de incompatibilidad entre passlib 1.7.4 y bcrypt≥4.1.
