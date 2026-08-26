#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:-lessons/improvement.md}"
shift || true

AI=0
MODEL="${MODEL:-gemma3:4b}"
THEME="${THEME:-}"
VOICE="${VOICE:-}"
RESOLUTION="${RESOLUTION:-1080p}"
REQUIRE_SCORE="${REQUIRE_SCORE:-75}"
YOUTUBE=0
PRIVACY="${PRIVACY:-private}"
DESCRIPTION_FILE=""
TITLE=""
TAGS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai) AI=1; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    --voice) VOICE="$2"; shift 2 ;;
    --resolution) RESOLUTION="$2"; shift 2 ;;
    --require-score) REQUIRE_SCORE="$2"; shift 2 ;;
    --youtube) YOUTUBE=1; shift ;;
    --privacy) PRIVACY="$2"; shift 2 ;;
    --description) DESCRIPTION_FILE="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --tags) TAGS="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR: ffmpeg is required. macOS: brew install ffmpeg"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required. macOS: brew install jq"; exit 1; }
if [[ "$AI" -eq 1 ]]; then
  command -v ollama >/dev/null 2>&1 || { echo "ERROR: --ai requires Ollama."; exit 1; }
fi

[[ -d node_modules ]] || npm install
mkdir -p build public/audio

if [[ "$AI" -eq 1 ]]; then
  ./scripts/ollama_lesson.sh "$INPUT" "$MODEL"
  python scripts/verify_lesson.py build/lesson-ai.json build/lesson.json "$INPUT" || {
    echo "ERROR: lesson verification failed."
    exit 1
  }
else
  ARGS=("$INPUT" "-o" "build/lesson.json")
  [[ -n "$THEME" ]] && ARGS+=("--theme" "$THEME")
  [[ -n "$VOICE" ]] && ARGS+=("--voice" "$VOICE")
  python scripts/compile_lesson.py "${ARGS[@]}"
fi

# Explicit CLI overrides win over lesson/model defaults.
if [[ -n "$THEME" ]]; then
  jq --arg v "$THEME" '.theme=$v' build/lesson.json > build/lesson.tmp.json && mv build/lesson.tmp.json build/lesson.json
fi
if [[ -n "$VOICE" ]]; then
  jq --arg v "$VOICE" '.voice=$v' build/lesson.json > build/lesson.tmp.json && mv build/lesson.tmp.json build/lesson.json
fi

case "$RESOLUTION" in
  720p) WIDTH=1280; HEIGHT=720 ;;
  1080p) WIDTH=1920; HEIGHT=1080 ;;
  1440p) WIDTH=2560; HEIGHT=1440 ;;
  4k) WIDTH=3840; HEIGHT=2160 ;;
  shorts) WIDTH=1080; HEIGHT=1920 ;;
  square) WIDTH=1080; HEIGHT=1080 ;;
  *) echo "ERROR: unknown resolution '$RESOLUTION'. Use 720p, 1080p, 1440p, 4k, shorts, square."; exit 1 ;;
esac

jq --argjson width "$WIDTH" --argjson height "$HEIGHT" \
  '.width=$width | .height=$height' build/lesson.json > build/lesson.tmp.json
mv build/lesson.tmp.json build/lesson.json

echo "✓ Resolution: ${WIDTH}x${HEIGHT}"

if [[ "$AI" -eq 1 ]]; then
  python scripts/preflight.py build/lesson.json "$REQUIRE_SCORE" || {
    echo "ERROR: preflight quality check failed."
    exit 1
  }
fi

VOICE_ARGS=()
[[ -n "$VOICE" ]] && VOICE_ARGS+=("--voice" "$VOICE")
python scripts/generate_voice.py build/lesson.json "${VOICE_ARGS[@]}"

npx remotion render src/index.ts Lesson build/lesson.mp4

echo
echo "✓ Render complete: build/lesson.mp4"

if [[ "$YOUTUBE" -eq 1 ]]; then
  UPLOAD_ARGS=(build/lesson.mp4 --privacy "$PRIVACY")
  [[ -n "$DESCRIPTION_FILE" ]] && UPLOAD_ARGS+=(--description-file "$DESCRIPTION_FILE")
  [[ -n "$TITLE" ]] && UPLOAD_ARGS+=(--title "$TITLE")
  [[ -n "$TAGS" ]] && UPLOAD_ARGS+=(--tags "$TAGS")
  python scripts/upload_youtube.py "${UPLOAD_ARGS[@]}"
fi
