FROM nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git ffmpeg libsndfile1 build-essential wget unzip \
    pkg-config \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libavfilter-dev \
    libmecab-dev \
    mecab \
    mecab-ipadic-utf8 \
    patchelf \
    python3 python3-pip python3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /app

# PyTorch con CUDA 12.1 (compatible con CUDA 12.2)
RUN pip install --no-cache-dir \
    torch==2.1.0 torchaudio==2.1.0 \
    --index-url https://download.pytorch.org/whl/cu121

# Fake av trick para MeloTTS
RUN python -c "\
import os; \
os.makedirs('/tmp/fake_av', exist_ok=True); \
open('/tmp/fake_av/setup.py', 'w').write('from setuptools import setup\nsetup(name=\"av\", version=\"10.0.0\")\n'); \
" && pip install --no-cache-dir /tmp/fake_av

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN pip install --no-cache-dir \
    git+https://github.com/myshell-ai/MeloTTS.git \
    git+https://github.com/myshell-ai/OpenVoice.git

RUN pip install --no-cache-dir "av>=12.0.0"

# Checkpoints OpenVoice v2
RUN wget -q https://myshell-public-repo-host.s3.amazonaws.com/openvoice/checkpoints_v2_0417.zip \
    -O /tmp/ckpt.zip && unzip /tmp/ckpt.zip -d /app && rm /tmp/ckpt.zip

RUN python -c "import nltk; nltk.download('averaged_perceptron_tagger_eng')"
RUN python -m unidic download
RUN mkdir -p /app/voices

# Parchear ctranslate2 para permitir stack ejecutable
RUN find /usr/local/lib -name "libctranslate2*.so*" | xargs -I{} patchelf --clear-execstack {} 2>/dev/null || true

COPY . /app

EXPOSE 8880
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8880"]