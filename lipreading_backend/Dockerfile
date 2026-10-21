# Backend de lipreading — stub local, sin GPU ni modelo pesado: solo
# valida el pipeline (app -> backend -> audio + texto) mientras no hay
# un modelo VSR real. Se puede reconstruir sobre esta misma imagen (o
# una con CUDA, como voice_backend/Dockerfile) cuando llegue el modelo.
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app

EXPOSE 8010
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8010"]
