# Docker Operations

## Build
```bash
docker build -t richlesson:local .
```

## Run a structured lesson
```bash
docker run --rm \
  -v "$PWD/build:/app/build" \
  -v "$PWD/public/audio:/app/public/audio" \
  -v "$PWD/lessons:/work/lessons:ro" \
  richlesson:local /work/lessons/improvement.md --resolution 1080p
```

## Ollama
Keep model weights outside the image. On Docker Desktop/macOS use a host-reachable Ollama endpoint such as `http://host.docker.internal:11434` and make sure the Richlesson Ollama integration honors `OLLAMA_URL`.

## Secrets
Never COPY OAuth client files, YouTube tokens, `.env` files, or private keys into the image.

## GHCR release
```bash
git tag v0.3.0
git push origin v0.3.0
```
The tag workflow publishes `ghcr.io/<owner>/<repo>:v0.3.0` for amd64 and arm64.
