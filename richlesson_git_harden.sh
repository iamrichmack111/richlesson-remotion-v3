#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-richlesson-remotion-v3}"
VISIBILITY="${VISIBILITY:-public}"
BRANCH="${BRANCH:-main}"
DESCRIPTION="${DESCRIPTION:-Terminal-first AI-assisted Markdown/TXT lesson-to-video pipeline with local Ollama, neural narration, Remotion, Docker, quality gates, and optional YouTube publishing.}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing $1"; exit 1; }; }
need git; need gh; need jq
gh auth status >/dev/null 2>&1 || { echo 'ERROR: run gh auth login first'; exit 1; }
[[ -f package.json && -d src && -d scripts ]] || { echo 'ERROR: run from richlesson project root'; exit 1; }

OWNER="$(gh api user --jq .login)"
SSH_REMOTE="git@github.com:${OWNER}/${REPO}.git"

echo "== Richlesson GitHub hardening =="
echo "repo: ${OWNER}/${REPO}"
echo "ssh:  ${SSH_REMOTE}"

# -----------------------------------------------------------------------------
# Honest baseline commit (no fake historical dates)
# -----------------------------------------------------------------------------
if [[ ! -d .git ]]; then git init -b "$BRANCH"; else git branch -M "$BRANCH"; fi
if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m 'feat: establish Richlesson v3 application baseline' || true
fi

mkdir -p .github/workflows .github/ISSUE_TEMPLATE docs/{assets,diagrams,wiki} man build public/audio scripts
touch build/.gitkeep public/audio/.gitkeep

# -----------------------------------------------------------------------------
# Ignore/security boundaries
# -----------------------------------------------------------------------------
cat > .gitignore <<'EOF'
.DS_Store
.idea/
.vscode/
*.swp
*.swo
*~

# Python
__pycache__/
*.py[cod]
.pytest_cache/
.mypy_cache/
.ruff_cache/
.coverage
htmlcov/
.venv/
venv/
env/

# Node
node_modules/
.npm/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Build/media
build/*
!build/.gitkeep
public/audio/*
!public/audio/.gitkeep
*.mp4
*.mov
*.webm
*.mkv
*.wav
*.mp3
*.m4a

# Secrets / OAuth
.env
.env.*
!.env.example
youtube-client-secret.json
youtube-token.json
build/youtube-token.json
client_secret_*.json
*client_secret*.json
*.pem
*.key
*.p12
*.pfx

# Temp/logs
*.log
tmp/
temp/
.cache/
EOF

cat > .dockerignore <<'EOF'
.git
.github
.venv
venv
node_modules
build
public/audio
__pycache__
*.pyc
*.mp4
*.mov
*.webm
*.wav
*.mp3
.env
.env.*
youtube-client-secret.json
youtube-token.json
client_secret_*.json
*client_secret*.json
.DS_Store
EOF

cat > .editorconfig <<'EOF'
root = true
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
[*.{js,jsx,ts,tsx,json,yml,yaml,md}]
indent_style = space
indent_size = 2
[*.py]
indent_style = space
indent_size = 4
[*.sh]
indent_style = space
indent_size = 2
EOF

cat > .env.example <<'EOF'
OLLAMA_URL=http://127.0.0.1:11434
MODEL=gemma3:4b
VOICE=andrew
THEME=cinematic-glass
RESOLUTION=1080p
PRIVACY=private
REQUIRE_SCORE=75
YOUTUBE_CLIENT_SECRET=youtube-client-secret.json
EOF

git add .gitignore .dockerignore .editorconfig .env.example build/.gitkeep public/audio/.gitkeep
git commit -m 'chore: harden repository ignores and secret boundaries' || true

# -----------------------------------------------------------------------------
# Runtime/dev dependencies + Bandit
# -----------------------------------------------------------------------------
cat > requirements-runtime.txt <<'EOF'
edge-tts
google-api-python-client
google-auth-oauthlib
google-auth-httplib2
EOF

cat > requirements-dev.txt <<'EOF'
bandit[sarif]>=1.9.4,<2
ruff>=0.12,<1
pytest>=8,<9
pip-audit>=2.9,<3
EOF

cat > .bandit <<'EOF'
[bandit]
exclude = ./.venv,./venv,./node_modules,./build
skips = B101
EOF

# -----------------------------------------------------------------------------
# CI: validate, don't waste CI minutes rendering full videos
# -----------------------------------------------------------------------------
cat > .github/workflows/ci.yml <<'YAML'
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: npm
      - uses: actions/setup-python@v5
        with:
          python-version: '3.13'
          cache: pip
          cache-dependency-path: |
            requirements-runtime.txt
            requirements-dev.txt
      - name: System dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y --no-install-recommends ffmpeg jq shellcheck
      - run: npm ci
      - run: python -m pip install --upgrade pip
      - run: python -m pip install -r requirements-runtime.txt -r requirements-dev.txt
      - name: TypeScript
        run: npx tsc --noEmit
      - name: Python syntax
        run: python -m compileall -q scripts
      - name: Ruff
        run: ruff check scripts
      - name: ShellCheck
        run: |
          shellcheck richlesson.sh
          find scripts -maxdepth 1 -name '*.sh' -print0 | xargs -0 -r shellcheck
      - name: JSON examples
        run: find lessons -type f -name '*.json' -print0 | xargs -0 -r -n1 jq empty
      - name: Docker build smoke test
        run: docker build --pull -t richlesson-ci:${{ github.sha }} .
YAML

# Official PyCQA Bandit action + dependency audits
cat > .github/workflows/security.yml <<'YAML'
name: Security
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '17 6 * * 1'
  workflow_dispatch:
permissions:
  contents: read
  security-events: write
  actions: read
jobs:
  bandit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Bandit
        uses: PyCQA/bandit-action@v1
        with:
          targets: scripts
          severity: low
          confidence: low
  dependency-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.13'
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: npm
      - run: python -m pip install -r requirements-runtime.txt pip-audit
      - run: pip-audit
      - run: npm ci
      - run: npm audit --audit-level=high
YAML

# -----------------------------------------------------------------------------
# CD: multi-arch GHCR on tags + GitHub release
# -----------------------------------------------------------------------------
cat > .github/workflows/docker-publish.yml <<'YAML'
name: Docker Publish
on:
  push:
    tags: ['v*']
  workflow_dispatch:
permissions:
  contents: read
  packages: write
jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=tag
            type=sha
            type=raw,value=latest,enable=${{ startsWith(github.ref, 'refs/tags/v') }}
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          platforms: linux/amd64,linux/arm64
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
YAML

cat > .github/workflows/release.yml <<'YAML'
name: Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: gh release create "${GITHUB_REF_NAME}" --generate-notes --title "Richlesson ${GITHUB_REF_NAME}"
YAML

# Dependabot: npm, pip, Actions, Docker
cat > .github/dependabot.yml <<'YAML'
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule: {interval: weekly, day: monday, time: '07:00'}
    labels: [dependencies, javascript]
    open-pull-requests-limit: 5
  - package-ecosystem: pip
    directory: /
    schedule: {interval: weekly, day: monday, time: '07:10'}
    labels: [dependencies, python]
    open-pull-requests-limit: 5
  - package-ecosystem: github-actions
    directory: /
    schedule: {interval: weekly, day: monday, time: '07:20'}
    labels: [dependencies, github-actions]
    open-pull-requests-limit: 5
  - package-ecosystem: docker
    directory: /
    schedule: {interval: weekly, day: monday, time: '07:30'}
    labels: [dependencies, docker]
    open-pull-requests-limit: 5
YAML

git add requirements-runtime.txt requirements-dev.txt .bandit .github
git commit -m 'ci: add CI security scanning dependabot and release automation' || true

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
cat > Dockerfile <<'EOF'
FROM node:22-bookworm-slim
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
EOF

cat > docker-compose.yml <<'EOF'
services:
  richlesson:
    build: .
    image: richlesson:local
    volumes:
      - ./build:/app/build
      - ./public/audio:/app/public/audio
      - ./lessons:/work/lessons:ro
    environment:
      OLLAMA_URL: ${OLLAMA_URL:-http://host.docker.internal:11434}
      MODEL: ${MODEL:-gemma3:4b}
      VOICE: ${VOICE:-andrew}
      THEME: ${THEME:-cinematic-glass}
      RESOLUTION: ${RESOLUTION:-1080p}
    extra_hosts:
      - 'host.docker.internal:host-gateway'
EOF

cat > docs/DOCKER.md <<'EOF'
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
EOF

git add Dockerfile docker-compose.yml docs/DOCKER.md
git commit -m 'build: containerize Richlesson and add GHCR delivery path' || true

# -----------------------------------------------------------------------------
# Icon + D2 architecture sources
# -----------------------------------------------------------------------------
cat > docs/assets/richlesson-icon.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="96" fill="#0b0f17"/>
  <rect x="76" y="96" width="360" height="238" rx="30" fill="#111827" stroke="#94a3b8" stroke-width="8"/>
  <circle cx="112" cy="132" r="10" fill="#e5e7eb"/><circle cx="144" cy="132" r="10" fill="#e5e7eb"/><circle cx="176" cy="132" r="10" fill="#e5e7eb"/>
  <path d="M126 198l54 34-54 34z" fill="#f8fafc"/>
  <rect x="205" y="194" width="144" height="16" rx="8" fill="#cbd5e1"/>
  <rect x="205" y="226" width="102" height="16" rx="8" fill="#64748b"/>
  <path d="M196 376h120" stroke="#e2e8f0" stroke-width="18" stroke-linecap="round"/>
  <path d="M338 346l58 30-58 30z" fill="#f8fafc"/>
</svg>
EOF

cat > docs/diagrams/architecture.d2 <<'EOF'
direction: right
source: "Markdown / TXT"
parser: "Deterministic Parser"
planner: "Ollama Planner"
compiler: "Scene Compiler"
validator: "Grounding + QA"
tts: "Neural TTS"
remotion: "Remotion"
video: "MP4"
youtube: "YouTube"
source -> parser: "structured"
source -> planner: "--ai"
planner -> compiler -> validator
parser -> validator
validator -> tts -> remotion
validator -> remotion
remotion -> video -> youtube: "optional"
EOF

cat > docs/diagrams/cicd.d2 <<'EOF'
direction: right
dev: "Developer"
ssh: "SSH push"
github: "GitHub"
ci: "CI\nTS + Python + Shell"
security: "Security\nBandit + audits"
tag: "v* tag"
buildx: "Docker Buildx"
ghcr: "GHCR"
release: "GitHub Release"
dev -> ssh -> github
github -> ci
github -> security
github -> tag
tag -> buildx -> ghcr
tag -> release
EOF

cat > docs/diagrams/security-boundary.d2 <<'EOF'
direction: right
repo: "Git repo"
ollama: "Local Ollama"
container: "Richlesson runtime"
oauth: "OAuth client"
token: "YouTube token"
youtube: "YouTube API"
repo -> container
ollama -> container: "local API"
oauth -> container: "runtime only"
token -> container: "runtime only"
container -> youtube
EOF

cat > docs/DIAGRAMS.md <<'EOF'
# D2 Architecture Documentation

The `.d2` files are canonical, diffable architecture sources.

```bash
mkdir -p docs/rendered
for f in docs/diagrams/*.d2; do
  d2 "$f" "docs/rendered/$(basename "$f" .d2).svg"
done
```

Files:
- `architecture.d2`: application flow.
- `cicd.d2`: SSH/CI/GHCR release flow.
- `security-boundary.d2`: secret/runtime boundaries.
- `docs/assets/richlesson-icon.svg`: repository/app icon.
EOF

git add docs/assets docs/diagrams docs/DIAGRAMS.md
git commit -m 'docs: add D2 architecture sources and project icon' || true

# -----------------------------------------------------------------------------
# Unix man page
# -----------------------------------------------------------------------------
cat > man/richlesson.1 <<'EOF'
.TH RICHLESSON 1 "August 2026" "Richlesson" "User Commands"
.SH NAME
richlesson \- generate narrated lesson videos from Markdown or text
.SH SYNOPSIS
.B ./richlesson.sh
.I INPUT
.RI [ OPTIONS ]
.SH DESCRIPTION
Richlesson is a terminal-first lesson-to-video pipeline. Structured Markdown or text can be compiled deterministically; ordinary prose can be planned by a local Ollama model. Richlesson generates neural narration, validates lesson data, renders with Remotion, and can optionally upload the resulting MP4 to YouTube.
.SH OPTIONS
.TP
.B --ai
Use local Ollama-assisted planning.
.TP
.BI --model " MODEL"
Select the Ollama model.
.TP
.BI --theme " THEME"
Choose the Remotion visual theme.
.TP
.BI --voice " VOICE"
Choose the configured neural voice.
.TP
.BI --resolution " PRESET"
Choose 720p, 1080p, 1440p, 4k, shorts, or square.
.TP
.B --youtube
Upload after a successful render.
.TP
.BI --privacy " STATUS"
Choose private, unlisted, or public.
.TP
.BI --description " FILE"
Use a Markdown/text file as YouTube description source.
.SH EXAMPLES
.nf
./richlesson.sh lesson.md --resolution 1080p
./richlesson.sh article.txt --ai --model gemma3:4b
./richlesson.sh article.md --youtube --privacy private --description description.md
.fi
.SH SECURITY
Never commit OAuth clients, refresh tokens, private keys, `.env` secrets, or private source materials.
.SH FILES
.I build/lesson.json
Normalized scene contract.
.br
.I build/lesson.mp4
Default rendered video.
.br
.I docs/wiki/
Canonical wiki source.
.SH SEE ALSO
.BR ffmpeg (1),
.BR docker (1),
.BR git (1),
.BR jq (1)
EOF

cat > docs/MANPAGE.md <<'EOF'
# Man Page
Preview:
```bash
man ./man/richlesson.1
```
Install for the current user:
```bash
mkdir -p ~/.local/share/man/man1
cp man/richlesson.1 ~/.local/share/man/man1/
mandb 2>/dev/null || true
man richlesson
```
EOF

git add man docs/MANPAGE.md
git commit -m 'docs: add Unix man page and operator reference' || true

# -----------------------------------------------------------------------------
# Detailed wiki source. User initializes wiki once; script syncs after.
# -----------------------------------------------------------------------------
cat > docs/wiki/Home.md <<EOF
# Richlesson Wiki

Richlesson converts Markdown or text into narrated, programmable Remotion lesson videos while keeping AI optional and publishing separate from rendering.

## Principles
1. Human-readable source remains canonical.
2. Structured source does not require AI.
3. Local AI is a planner/formatter, not the sole factual authority.
4. Normalized JSON is the rendering boundary.
5. Narration is generated independently from visuals.
6. Source grounding and quality gates happen before rendering.
7. YouTube publishing is optional and private-first.
8. OAuth secrets and tokens never belong in Git or Docker layers.
9. Architecture and operations documentation are source-controlled.
10. Full video rendering is not part of ordinary CI.

## Pages
- [Architecture](Architecture)
- [CLI Reference](CLI-Reference)
- [Lesson Schema](Lesson-Schema)
- [AI Pipeline](AI-Pipeline)
- [Themes and Layouts](Themes-and-Layouts)
- [Voice and Audio](Voice-and-Audio)
- [YouTube Publishing](YouTube-Publishing)
- [Docker](Docker)
- [Security](Security)
- [CI-CD](CI-CD)
- [Operations Runbook](Operations-Runbook)
- [Troubleshooting](Troubleshooting)
- [Development](Development)
- [Roadmap](Roadmap)
- [FAQ](FAQ)

Repository: \\`${OWNER}/${REPO}\\`
EOF

cat > docs/wiki/Architecture.md <<'EOF'
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
EOF

cat > docs/wiki/CLI-Reference.md <<'EOF'
# CLI Reference

Structured:
```bash
./richlesson.sh lesson.md
```
AI:
```bash
./richlesson.sh notes.txt --ai --model gemma3:4b
```
Theme/voice:
```bash
./richlesson.sh lesson.md --theme blueprint --voice andrew
```
Resolution:
```bash
./richlesson.sh lesson.md --resolution 1080p
```
Presets: `720p`, `1080p`, `1440p`, `4k`, `shorts`, `square`.

YouTube:
```bash
./richlesson.sh lesson.md --youtube --privacy private --description description.md
```
Private review is the recommended default for generated content.
EOF

cat > docs/wiki/Lesson-Schema.md <<'EOF'
# Lesson Schema

The normalized JSON is the stable interface consumed by Remotion.

Root example:
```json
{
  "id":"lesson-id",
  "title":"Lesson title",
  "subtitle":"Subtitle",
  "voice":"andrew",
  "theme":"cinematic-glass",
  "fps":30,
  "width":1920,
  "height":1080,
  "scenes":[]
}
```

Semantic scene vocabulary includes title, text, formula, counter, comparison, steps, timeline, quote, terminal, code, diagram, chart, stat, definition, example, quiz, answer, warning, tip, summary, and CTA.

Scene type describes meaning; layout describes composition; theme describes global visual language. Keep those concerns separate.
EOF

cat > docs/wiki/AI-Pipeline.md <<'EOF'
# AI Pipeline

AI is optional. It is useful when ordinary prose must be converted into a lesson plan.

## Preferred two-pass pattern
1. Planner: goal, sections, source excerpts, recommended scene types.
2. Compiler: strict scene JSON.

## Controls
- Ollama HTTP API instead of interactive terminal parsing.
- non-streaming structured response,
- low temperature,
- JSON schema,
- exact source excerpts,
- normalization,
- quality/preflight threshold,
- human review before public publishing.

Do not treat a valid JSON object as proof that facts are correct.
EOF

cat > docs/wiki/Themes-and-Layouts.md <<'EOF'
# Themes and Layouts

Themes should alter typography, geometry, grid/glow behavior, contrast, panels, and presentation language—not merely colors.

Current theme family includes cinematic glass, blueprint, terminal noir, neon grid, editorial, paper/ink, retro future, classroom, data lab, minimal luxury, space console, industrial, midnight academy, signal, and monochrome.

Layouts can include hero, split, spotlight, cards, stacked, editorial, console, blueprint, big-number, callout, checklist, quiz-grid, quote-focus, and minimal.

Long lessons should rotate compatible layouts to avoid visual repetition.
EOF

cat > docs/wiki/Voice-and-Audio.md <<'EOF'
# Voice and Audio

Narration is generated per scene so Richlesson can:
- measure real speech duration,
- regenerate one scene,
- align scene timing,
- change voices without rewriting visuals,
- create captions.

Generated audio belongs under `public/audio/` and is ignored by Git.

Review pronunciation of acronyms, formulas, symbols, names, and command-line flags before publishing.
EOF

cat > docs/wiki/YouTube-Publishing.md <<'EOF'
# YouTube Publishing

Publishing occurs after successful rendering.

## OAuth
Use a desktop/installed-app OAuth client and minimum necessary YouTube upload scope. Never commit client JSON or refresh tokens.

## Safe lifecycle
```text
render -> private upload -> human review -> visibility change
```

## Description files
Richlesson can read a Markdown/text description source. YouTube does not render GitHub Markdown exactly, so Markdown is primarily an authoring format.
EOF

cat > docs/wiki/Docker.md <<'EOF'
# Docker

The image packages Node, Python, FFmpeg, jq, application source, npm dependencies, and runtime Python dependencies.

Ollama model weights and OAuth credentials stay outside the image.

Use bind mounts for lesson inputs and build outputs. On Docker Desktop/macOS, host Ollama is commonly reachable through `host.docker.internal` when the application is configured to honor that URL.
EOF

cat > docs/wiki/Security.md <<'EOF'
# Security

## Protected data
Never version OAuth clients, refresh tokens, private keys, `.env` secrets, or private books/source material.

## Repository controls
- `.gitignore` / `.dockerignore`,
- Bandit,
- pip-audit,
- npm audit,
- Dependabot,
- SSH Git remote,
- source grounding and validation,
- private-first upload policy.

## Credential incident response
If a credential is exposed: revoke/rotate it, remove it locally, verify ignore rules, inspect Git history, and invalidate dependent tokens.
EOF

cat > docs/wiki/CI-CD.md <<'EOF'
# CI/CD

## CI
Pushes/PRs validate TypeScript, Python syntax, Ruff, ShellCheck, JSON fixtures, and Docker build.

## Security
Bandit and dependency audits run separately.

## CD
Version tags publish multi-architecture Docker images to GHCR and create a GitHub Release.

```bash
git tag v0.3.0
git push origin v0.3.0
```

Ordinary CI intentionally avoids full Remotion video renders.
EOF

cat > docs/wiki/Operations-Runbook.md <<'EOF'
# Operations Runbook

Preflight:
```bash
git status
node --version
python --version
ffmpeg -version
jq --version
```
AI health:
```bash
curl -fsS http://127.0.0.1:11434/api/tags | jq .
```
Build:
```bash
./richlesson.sh lesson.md --resolution 1080p
```
AI build:
```bash
./richlesson.sh article.txt --ai --model gemma3:4b
```
Inspect before publish:
```bash
jq . build/lesson.json
ls -lh build/lesson.mp4
```
Publish privately first.
EOF

cat > docs/wiki/Troubleshooting.md <<'EOF'
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
EOF

cat > docs/wiki/Development.md <<'EOF'
# Development

When adding a scene type:
1. add schema vocabulary,
2. normalize the data,
3. add renderer,
4. add example,
5. add validation,
6. update docs,
7. run CI checks.

Keep source parsing, AI planning, validation, TTS, rendering, and publishing independently testable.
EOF

cat > docs/wiki/Roadmap.md <<'EOF'
# Roadmap

Potential work:
- word-level caption alignment,
- dedicated D2/SVG scene renderer,
- chart renderer,
- thumbnails,
- multilingual narration,
- long-document chapter chunking,
- restartable rendering,
- publishing queues,
- richer grounding metrics,
- transcripts,
- podcast/audio-only mode,
- model-output fixtures and regression tests.
EOF

cat > docs/wiki/FAQ.md <<'EOF'
# FAQ

## Is AI required?
No. Structured lessons are deterministic.

## Why local AI?
It can restructure prose without sending source text to a remote LLM API.

## Why not let the model solve everything?
Small models can hallucinate. AI is best used as a director/formatter while source material and deterministic validators remain authoritative.

## Why Remotion?
It makes video layouts programmable with React and works well for text, code, terminal scenes, diagrams, captions, and data-driven motion graphics.

## Why private YouTube uploads?
They create a human review gate before public distribution.
EOF

cat > scripts/sync-wiki.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO="${REPO:-richlesson-remotion-v3}"
OWNER="${OWNER:-$(gh api user --jq .login)}"
REMOTE="git@github.com:${OWNER}/${REPO}.wiki.git"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "NOTE: initialize the GitHub Wiki once in the web UI first."
git clone "$REMOTE" "$TMP/wiki"
find "$TMP/wiki" -maxdepth 1 -type f -name '*.md' -delete
cp docs/wiki/*.md "$TMP/wiki/"
cd "$TMP/wiki"
git add -A
git diff --cached --quiet && { echo 'Wiki already current.'; exit 0; }
git commit -m 'docs: sync detailed Richlesson wiki'
git push origin master 2>/dev/null || git push origin main
EOF
chmod +x scripts/sync-wiki.sh

git add docs/wiki scripts/sync-wiki.sh
git commit -m 'docs: add comprehensive wiki source and SSH sync tooling' || true

# -----------------------------------------------------------------------------
# Governance
# -----------------------------------------------------------------------------
cat > SECURITY.md <<'EOF'
# Security Policy

Do not open public issues containing credentials, OAuth tokens, private source material, or exploitable secret details.

Never commit Google OAuth client files, YouTube tokens, private keys, or `.env` secrets. If credentials are committed, revoke them even if history is rewritten later.
EOF

cat > CONTRIBUTING.md <<'EOF'
# Contributing

Before a PR:
```bash
npm ci
npx tsc --noEmit
python -m pip install -r requirements-runtime.txt -r requirements-dev.txt
python -m compileall -q scripts
ruff check scripts
bandit -r scripts
shellcheck richlesson.sh scripts/*.sh
docker build -t richlesson:test .
```

Keep source parsing, AI planning, validation, TTS, rendering, and publishing independently testable. Never add real credential files to fixtures.
EOF

cat > .github/ISSUE_TEMPLATE/bug.yml <<'EOF'
name: Bug
description: Report a reproducible Richlesson defect
title: '[bug] '
labels: [bug]
body:
  - type: textarea
    id: summary
    attributes: {label: Summary}
    validations: {required: true}
  - type: textarea
    id: reproduce
    attributes: {label: Reproduction, description: 'Include command and sanitized output.'}
    validations: {required: true}
  - type: textarea
    id: environment
    attributes: {label: Environment, description: 'OS, Node, Python, FFmpeg, Ollama model if relevant.'}
EOF

cat > .github/ISSUE_TEMPLATE/feature.yml <<'EOF'
name: Feature
description: Propose an improvement
title: '[feature] '
labels: [enhancement]
body:
  - type: textarea
    id: problem
    attributes: {label: Problem}
    validations: {required: true}
  - type: textarea
    id: proposal
    attributes: {label: Proposed behavior}
    validations: {required: true}
EOF

cat > .github/PULL_REQUEST_TEMPLATE.md <<'EOF'
## Summary

## Validation
- [ ] TypeScript passes
- [ ] Python checks pass
- [ ] Bandit reviewed
- [ ] ShellCheck passes
- [ ] Docker builds
- [ ] No credentials/secrets are committed
- [ ] Architecture/docs updated if needed

## Risk

## Screenshots / sample render
EOF

git add SECURITY.md CONTRIBUTING.md .github/ISSUE_TEMPLATE .github/PULL_REQUEST_TEMPLATE.md
git commit -m 'chore: add repository security and contribution governance' || true

# -----------------------------------------------------------------------------
# Detailed README with badges
# -----------------------------------------------------------------------------
cat > README.md <<EOF
<p align="center"><img src="docs/assets/richlesson-icon.svg" width="150" alt="Richlesson icon"></p>

# Richlesson

[![CI](https://github.com/${OWNER}/${REPO}/actions/workflows/ci.yml/badge.svg)](https://github.com/${OWNER}/${REPO}/actions/workflows/ci.yml)
[![Security](https://github.com/${OWNER}/${REPO}/actions/workflows/security.yml/badge.svg)](https://github.com/${OWNER}/${REPO}/actions/workflows/security.yml)
[![Docker](https://github.com/${OWNER}/${REPO}/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/${OWNER}/${REPO}/actions/workflows/docker-publish.yml)
[![security: bandit](https://img.shields.io/badge/security-bandit-yellow.svg)](https://github.com/PyCQA/bandit)
![Node](https://img.shields.io/badge/Node-22+-informational)
![Python](https://img.shields.io/badge/Python-3.13+-informational)
![Remotion](https://img.shields.io/badge/video-Remotion-informational)
![Ollama](https://img.shields.io/badge/local_AI-Ollama-informational)

**Terminal-first AI-assisted lesson-to-video generation from Markdown or plain text.**

Richlesson separates content interpretation from deterministic video rendering. Structured lessons work without AI. Ordinary prose can be reorganized with a local Ollama model, normalized into a lesson JSON contract, narrated with neural TTS, rendered with Remotion, and optionally published to YouTube.

## Architecture

\`\`\`text
Markdown / TXT
      |
      +---- structured ----> deterministic parser
      |
      +---- --ai ----------> local Ollama
                               |
                               v
                         lesson planning
                               |
                               v
                         scene compiler
                               |
                               v
                        source grounding
                               |
                               v
                          quality gate
                               |
                    +----------+----------+
                    |                     |
                    v                     v
              neural narration       Remotion scenes
                    |                     |
                    +----------+----------+
                               |
                               v
                              MP4
                               |
                               v
                     optional YouTube upload
\`\`\`

## Features
- Markdown and TXT inputs.
- Deterministic non-AI mode.
- Local Ollama-assisted lesson planning.
- JSON rendering contract.
- Many semantic scene types, layouts, and themes.
- Neural narration and captions.
- 720p, 1080p, 1440p, 4K, Shorts, square presets.
- Optional private/unlisted/public YouTube delivery.
- Markdown/text description files.
- Source-grounding/quality architecture.
- Docker + Compose.
- CI, Bandit, audits, Dependabot.
- Multi-arch GHCR CD on tags.
- D2 diagrams, SVG icon, man page, detailed wiki source.

## Setup
\`\`\`bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-runtime.txt
npm ci
\`\`\`

macOS:
\`\`\`bash
brew install ffmpeg jq
\`\`\`

## Usage
Structured:
\`\`\`bash
./richlesson.sh lessons/improvement.md
\`\`\`
AI:
\`\`\`bash
./richlesson.sh article.txt --ai --model gemma3:4b
\`\`\`
1080p:
\`\`\`bash
./richlesson.sh article.md --ai --resolution 1080p
\`\`\`
Shorts:
\`\`\`bash
./richlesson.sh article.md --ai --resolution shorts
\`\`\`
Private YouTube:
\`\`\`bash
./richlesson.sh article.md --ai --youtube --privacy private --description description.md
\`\`\`

## Themes
Examples: cinematic-glass, blueprint, terminal-noir, neon-grid, editorial, paper-ink, retro-future, classroom, data-lab, minimal-luxury, space-console, industrial, midnight-academy, signal, monochrome.

## Security
Do not commit OAuth clients, YouTube refresh tokens, private source books, environment secrets, private keys, or generated credentials. AI-generated factual content must be reviewed before public release.

## Docker
\`\`\`bash
docker build -t richlesson:local .
docker compose build
\`\`\`

## CI/CD
CI checks TypeScript, Python, Ruff, ShellCheck, JSON, and Docker. Security checks Bandit plus Python/npm dependency audits. Full video rendering is intentionally excluded from routine CI.

Release:
\`\`\`bash
git tag v0.3.0
git push origin v0.3.0
\`\`\`
This publishes a multi-architecture GHCR image and creates a GitHub Release.

## Documentation
- [Docker](docs/DOCKER.md)
- [D2 diagrams](docs/DIAGRAMS.md)
- [Man page](docs/MANPAGE.md)
- [Wiki source](docs/wiki/Home.md)

Man page:
\`\`\`bash
man ./man/richlesson.1
\`\`\`

D2:
\`\`\`bash
d2 docs/diagrams/architecture.d2 docs/architecture.svg
\`\`\`

## Wiki
Initialize the GitHub Wiki once in the web UI, then:
\`\`\`bash
./scripts/sync-wiki.sh
\`\`\`
The wiki clone/push uses SSH: \`git@github.com:${OWNER}/${REPO}.wiki.git\`.

## Development principles
1. human-readable source is canonical,
2. AI is optional,
3. AI plans/structures rather than silently becoming factual authority,
4. JSON is the rendering boundary,
5. publishing is separate and optional,
6. secrets never enter Git/Docker layers,
7. architecture documentation changes with architecture.
EOF

git add README.md
git commit -m 'docs: publish detailed README with badges and operating model' || true

# -----------------------------------------------------------------------------
# GitHub repo create/configure; force SSH
# -----------------------------------------------------------------------------
if ! gh repo view "${OWNER}/${REPO}" >/dev/null 2>&1; then
  gh repo create "${OWNER}/${REPO}" --source=. "--${VISIBILITY}" --description "$DESCRIPTION"
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$SSH_REMOTE"
else
  git remote add origin "$SSH_REMOTE"
fi

git branch -M "$BRANCH"

gh repo edit "${OWNER}/${REPO}" \
  --description "$DESCRIPTION" \
  --add-topic remotion \
  --add-topic video-automation \
  --add-topic ollama \
  --add-topic education \
  --add-topic text-to-speech \
  --add-topic youtube \
  --add-topic docker \
  --add-topic ai

git push -u origin "$BRANCH"

# -----------------------------------------------------------------------------
# Backfilled issues (retroactive traceability, created now then closed)
# -----------------------------------------------------------------------------
for spec in \
  'architecture:5319e7:Architecture and system boundaries' \
  'ai:8250df:Local AI and lesson planning' \
  'video:d4c5f9:Remotion and rendering' \
  'security:d73a4a:Security hardening' \
  'documentation:0075ca:Documentation and wiki' \
  'docker:0db7ed:Container packaging' \
  'youtube:ff0000:YouTube delivery' \
  'dependencies:0366d6:Dependency updates'
do
  IFS=: read -r name color desc <<< "$spec"
  gh label create "$name" --repo "${OWNER}/${REPO}" --color "$color" --description "$desc" --force >/dev/null
done

backfill(){
  title="$1"; labels="$2"; body="$3"
  if gh issue list --repo "${OWNER}/${REPO}" --state all --search "$title in:title" --json title --jq '.[].title' | grep -Fxq "$title"; then
    echo "exists: $title"; return
  fi
  url="$(gh issue create --repo "${OWNER}/${REPO}" --title "$title" --label "$labels" --body "$body")"
  num="${url##*/}"
  gh issue close "$num" --repo "${OWNER}/${REPO}" --comment 'Backfilled issue: capability is already implemented; this issue records the work retroactively for project traceability.' >/dev/null
  echo "backfilled #$num $title"
}

backfill 'Define normalized lesson JSON contract' architecture 'Document the stable boundary between source interpretation and Remotion.'
backfill 'Add Markdown and TXT lesson compilation' architecture 'Support deterministic structured lesson inputs so AI remains optional.'
backfill 'Integrate local Ollama lesson restructuring' ai 'Add local-model scene planning and structured output.'
backfill 'Add neural narration pipeline' video 'Generate narration per scene and use audio duration for timing.'
backfill 'Build multi-theme Remotion visual system' video 'Support multiple themes, layouts, formula cards, comparisons, counters, and captions.'
backfill 'Add source grounding and quality gates' 'ai,security' 'Validate AI-created lessons before narration/rendering.'
backfill 'Add HD 4K Shorts and square resolution presets' video 'Make output dimensions selectable from CLI.'
backfill 'Add YouTube OAuth uploader and description files' youtube 'Publish completed lessons using private-first upload defaults.'
backfill 'Containerize Richlesson runtime' docker 'Package runtime dependencies into a reproducible container.'
backfill 'Harden security and dependency automation' 'security,dependencies' 'Add Bandit, audits, secret ignores, Dependabot, CI, and release automation.'
backfill 'Add D2 architecture docs and project icon' 'documentation,architecture' 'Keep architecture reviewable as source-controlled text.'
backfill 'Create detailed GitHub wiki and runbooks' documentation 'Backfill architecture, security, Docker, publishing, CI/CD, operations, and troubleshooting docs.'

# -----------------------------------------------------------------------------
# Wiki init runbook
# -----------------------------------------------------------------------------
cat > GITHUB_WIKI_SETUP.txt <<EOF
RICHLESSON WIKI SETUP
=====================

1. Open:
   https://github.com/${OWNER}/${REPO}/wiki

2. Initialize the Wiki once by creating the first Home page.

3. From the repo run:
   ./scripts/sync-wiki.sh

The wiki Git remote is SSH only:
   git@github.com:${OWNER}/${REPO}.wiki.git

Canonical pages remain in docs/wiki/ so documentation is source-controlled even if the Wiki UI changes.
EOF

git add GITHUB_WIKI_SETUP.txt
git commit -m 'docs: add GitHub Wiki initialization runbook' || true
git push origin "$BRANCH"

echo
echo '================================================================'
echo 'RICHLESSON GITHUB HARDENING COMPLETE'
echo '================================================================'
echo "Repo:       https://github.com/${OWNER}/${REPO}"
echo "SSH:        ${SSH_REMOTE}"
echo 'Wiki:       initialize once in UI, then ./scripts/sync-wiki.sh'
echo 'CI:         gh run list'
echo 'Man:        man ./man/richlesson.1'
echo 'D2:         d2 docs/diagrams/architecture.d2 docs/architecture.svg'
echo 'Release:    git tag v0.3.0 && git push origin v0.3.0'
echo "GHCR:       ghcr.io/${OWNER}/${REPO}:v0.3.0"
