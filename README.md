# Richlesson V2

Terminal-first lesson video generator:

```text
.md / .txt
   ↓
deterministic parser OR local Ollama AI
   ↓
validated lesson.json
   ↓
premium neural TTS
   ↓
Remotion
   ↓
MP4
```

## Install

```bash
brew install ffmpeg
python -m pip install edge-tts
npm install
```

For AI formatting, install Ollama separately and have a model available, for example:

```bash
ollama pull gemma3:4b
```

## Structured Markdown — no AI

```bash
./richlesson.sh lessons/improvement.md
```

## Structured TXT — no AI

```bash
./richlesson.sh lessons/example.txt
```

## Messy Markdown or text — local AI

```bash
./richlesson.sh my-notes.md --ai
./richlesson.sh my-notes.txt --ai
```

Default model:

```text
gemma3:4b
```

Override it:

```bash
./richlesson.sh notes.md --ai --model gemma3:1b
```

## Themes

Use:

```bash
./richlesson.sh lesson.md --theme blueprint
```

Available themes:

- `cinematic-glass`
- `blueprint`
- `terminal-noir`
- `neon-grid`
- `editorial`
- `paper-ink`
- `retro-future`
- `classroom`
- `data-lab`
- `minimal-luxury`
- `space-console`
- `industrial`
- `midnight-academy`
- `signal`
- `monochrome`

These change more than colors: font family, corner geometry, grid behavior, glow behavior,
panel treatment, contrast, and overall presentation language.

## Voices

```bash
./richlesson.sh lesson.md --voice andrew
./richlesson.sh lesson.md --voice brian
./richlesson.sh lesson.md --voice ava
./richlesson.sh lesson.md --voice emma
./richlesson.sh lesson.md --voice guy
./richlesson.sh lesson.md --voice jenny
```

## Scene types

Supported:

```text
title
text
formula
counter
comparison
steps
timeline
quote
terminal
code
diagram
chart
stat
definition
example
quiz
answer
warning
tip
summary
cta
```

The current renderer has dedicated visual treatments for title, formula, counter,
comparison, steps/items, terminal/code, quiz choices, stat, and general text-based scenes.
The remaining scene names are already accepted by the compiler and fall back gracefully
to the general scene treatment until more specialized renderers are added.

## Markdown format

```md
# Lesson Title
subtitle: Optional subtitle
voice: andrew
theme: cinematic-glass

## Formula
heading: Seven-Rep Rule
formula: G = 2^(N/7)
subheading: Seven stable reps model one doubling.
> Narration goes in a blockquote.

## Steps
heading: Process
- First
- Second
- Third
> Narration for this scene.

## Terminal
heading: Start the stack
command: docker compose up -d
> This command starts the application stack.

## Code
heading: Flask route

```python
@app.get("/health")
def health():
    return {"ok": True}
```

> This defines a simple health endpoint.

## Quiz
heading: Quick Check
question: How many stable reps model one doubling?
- 5
- 7
- 10
- 14
answer: 7
> The answer is seven.
```

## AI behavior

AI is optional. The AI path asks the local model to:

- preserve the source meaning
- preserve formulas, commands, terminology, and numbers
- choose only from allowed scene types
- generate concise narration
- return JSON only

The JSON is validated before Remotion sees it. Unknown scene types are converted to `text`.

If the model emits invalid JSON, the raw response is saved to:

```text
build/ollama-raw.txt
```

## Output

```text
build/lesson.json
build/lesson.mp4
public/audio/scene-01.mp3
public/audio/scene-02.mp3
...
```

# V3 quality upgrades

V3 adds a two-pass local AI planner, exact source grounding, automatic phrase captions,
layout variation, and a preflight quality gate.

## New AI pipeline

```text
source.md / source.txt
  -> Pass 1: outline.json
  -> Pass 2: lesson-ai.json
  -> grounding + verification
  -> lesson.json
  -> quality preflight
  -> premium TTS
  -> Remotion
```

## Layout choices

```text
hero
split
spotlight
cards
stacked
editorial
console
blueprint
big-number
callout
checklist
quiz-grid
quote-focus
minimal
```

## Automatic captions

Each scene narration is automatically broken into short caption phrases and displayed
near the bottom of the frame. This adds essentially no extra compute and does not require Whisper.

## Grounding

Every AI-generated scene includes `source_excerpt`. Richlesson verifies that the excerpt
exists in the original source file and measures vocabulary overlap between the excerpt and narration.

## Preflight quality gate

The score considers source grounding, scene variety, visual completeness, and verification.
The default required score is 75.

```bash
REQUIRE_SCORE=85 ./richlesson.sh article.md --ai
```

If the score is too low, Richlesson stops before narration and rendering.

## V3 install additions

```bash
brew install ffmpeg jq
python -m pip install edge-tts
python -m pip install google-api-python-client google-auth-oauthlib google-auth-httplib2
npm install
```

For AI mode:

```bash
ollama pull gemma3:4b
```

## V3 examples

Grounded AI lesson with captions and a quality threshold:

```bash
./richlesson.sh article.md \
  --ai \
  --model gemma3:4b \
  --theme cinematic-glass \
  --voice andrew \
  --resolution 1080p \
  --require-score 80
```

Vertical lesson:

```bash
./richlesson.sh article.txt --ai --resolution shorts
```

Render and upload privately to YouTube with a Markdown description:

```bash
./richlesson.sh article.md \
  --ai \
  --resolution 1080p \
  --youtube \
  --privacy private \
  --description description.md \
  --tags "education,technology,richmack"
```

YouTube OAuth files should remain local and are ignored by Git.
