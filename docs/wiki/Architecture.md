# Architecture

## Pipeline
```text
source.md / source.txt
        |
        +--> deterministic parser
        |
        +--> local Ollama planner/compiler (--ai)
                    |
                    v
              normalized lesson JSON
                    |
              grounding + QA
                    |
          +---------+---------+
          |                   |
          v                   v
     neural TTS           Remotion scenes
          |                   |
          +---------+---------+
                    v
                   MP4
                    |
             optional publish
```

## Boundary rules
- Input interpretation must be independent from Remotion.
- `build/lesson.json` is the contract between content and rendering.
- TTS failure must not change source parsing.
- YouTube failure must not invalidate a completed render.
- AI output must be normalized before use.
- Secrets exist only at runtime.

## Failure domains
1. source path/format,
2. deterministic parser or Ollama,
3. malformed lesson JSON,
4. grounding/quality failure,
5. TTS,
6. Remotion/Chromium,
7. FFmpeg,
8. OAuth,
9. YouTube API.

Always debug upstream first.
