# Troubleshooting

## No scenes
Structured parser was given unstructured text. Use `--ai` or add scene structure.

## Invalid AI JSON
Inspect the Ollama API response and normalized `build/lesson-ai.json`.

## ANSI terminal garbage
Do not parse interactive `ollama run` output. Use the HTTP API and extract `.response`.

## durationInFrames = 0
This is usually an upstream empty lesson. Inspect `build/lesson.json` before Remotion.

## Docker cannot reach Ollama
Use a host-reachable endpoint and ensure the program honors `OLLAMA_URL`.

## YouTube OAuth
Verify API enablement, installed-app client configuration, token scope, and that credentials are not ignored from runtime mounts.
