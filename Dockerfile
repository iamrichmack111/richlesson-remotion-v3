FROM node:25-bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PATH="/opt/venv/bin:${PATH}"
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl ffmpeg jq python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
RUN python3 -m venv /opt/venv
COPY requirements-runtime.txt /tmp/requirements-runtime.txt
RUN python -m pip install --upgrade pip && python -m pip install -r /tmp/requirements-runtime.txt
COPY . .
RUN chmod +x richlesson.sh scripts/*.sh scripts/*.py 2>/dev/null || true && mkdir -p /work /app/build /app/public/audio
VOLUME ["/work", "/app/build", "/app/public/audio"]
ENTRYPOINT ["./richlesson.sh"]
