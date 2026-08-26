# Docker

The image packages Node, Python, FFmpeg, jq, application source, npm dependencies, and runtime Python dependencies.

Ollama model weights and OAuth credentials stay outside the image.

Use bind mounts for lesson inputs and build outputs. On Docker Desktop/macOS, host Ollama is commonly reachable through `host.docker.internal` when the application is configured to honor that URL.
