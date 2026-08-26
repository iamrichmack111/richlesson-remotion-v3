#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:?usage: ollama_lesson.sh input.txt [model]}"
MODEL="${2:-gemma3:4b}"

mkdir -p build
SOURCE="$(cat "$INPUT")"

PLAN_PROMPT=$(cat <<PROMPT_EOF
You are a lesson planner.
Create a concise educational video outline from the source.
Do not solve math. Do not invent facts or dates.
Return JSON only:
{
  "title":"Lesson title",
  "subtitle":"Optional subtitle",
  "goal":"Learning goal",
  "sections":[
    {
      "heading":"Section heading",
      "recommended_type":"definition",
      "purpose":"Why this scene exists",
      "source_excerpt":"EXACT short excerpt copied from source"
    }
  ]
}
Allowed recommended_type values:
title, text, formula, counter, comparison, steps, timeline, quote,
terminal, code, diagram, chart, stat, definition, example, quiz,
answer, warning, tip, summary, cta.
Every source_excerpt must be copied exactly from the source.
Prefer 5 to 12 scenes. Avoid more than two consecutive scenes of the same type.

SOURCE:
$SOURCE
PROMPT_EOF
)

jq -n --arg model "$MODEL" --arg prompt "$PLAN_PROMPT" \
  '{model:$model,prompt:$prompt,stream:false,format:"json",options:{temperature:0.1}}' \
  > build/outline-request.json

curl -fsS http://127.0.0.1:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d @build/outline-request.json \
  > build/outline-response.json

jq -r '.response' build/outline-response.json > build/outline-raw.json
jq empty build/outline-raw.json 2>/dev/null || {
  echo "ERROR: planner returned invalid JSON"
  cat build/outline-raw.json
  exit 1
}
jq . build/outline-raw.json > build/outline.json
echo "✓ Pass 1 outline generated"

OUTLINE="$(cat build/outline.json)"

LESSON_PROMPT=$(cat <<PROMPT_EOF
You are a lesson scene compiler.
Use the source AND outline to build final lesson JSON.

ACCURACY RULES:
- Stay grounded in the source.
- Do not invent facts, dates, quotations, or examples.
- Do not solve math or calculate numeric answers.
- If calculation is needed, emit "calculation" and set answer:null.
- Every scene MUST include source_excerpt copied EXACTLY from SOURCE.
- Narration must be supported by source_excerpt.
- Keep narration concise, usually 1 to 3 sentences.
- Avoid more than two consecutive scenes of the same type.

Choose one layout per scene:
hero, split, spotlight, cards, stacked, editorial, console, blueprint,
big-number, callout, checklist, quiz-grid, quote-focus, minimal.

Allowed scene types:
title, text, formula, counter, comparison, steps, timeline, quote,
terminal, code, diagram, chart, stat, definition, example, quiz,
answer, warning, tip, summary, cta.

Root shape:
{
  "id":"lesson-slug",
  "title":"Lesson title",
  "subtitle":"Optional subtitle",
  "voice":"andrew",
  "theme":"cinematic-glass",
  "fps":30,
  "scenes":[
    {
      "type":"definition",
      "layout":"split",
      "duration":5,
      "heading":"Scene heading",
      "subheading":"Optional supporting text",
      "source_excerpt":"exact text copied from source",
      "narration":"grounded narration"
    }
  ]
}

OUTLINE:
$OUTLINE

SOURCE:
$SOURCE
PROMPT_EOF
)

cat > build/lesson-schema.json <<'JSON'
{
  "type":"object",
  "required":["id","title","subtitle","voice","theme","fps","scenes"],
  "properties":{
    "id":{"type":"string"},
    "title":{"type":"string"},
    "subtitle":{"type":"string"},
    "voice":{"type":"string","enum":["andrew","ava","brian","emma","guy","jenny"]},
    "theme":{"type":"string","enum":["cinematic-glass","blueprint","terminal-noir","neon-grid","editorial","paper-ink","retro-future","classroom","data-lab","minimal-luxury","space-console","industrial","midnight-academy","signal","monochrome"]},
    "fps":{"type":"integer"},
    "scenes":{
      "type":"array",
      "minItems":2,
      "items":{
        "type":"object",
        "required":["type","layout","duration","heading","source_excerpt","narration"],
        "properties":{
          "type":{"type":"string","enum":["title","text","formula","counter","comparison","steps","timeline","quote","terminal","code","diagram","chart","stat","definition","example","quiz","answer","warning","tip","summary","cta"]},
          "layout":{"type":"string","enum":["hero","split","spotlight","cards","stacked","editorial","console","blueprint","big-number","callout","checklist","quiz-grid","quote-focus","minimal"]},
          "duration":{"type":"number"},
          "heading":{"type":"string"},
          "subheading":{"type":"string"},
          "source_excerpt":{"type":"string"},
          "narration":{"type":"string"},
          "formula":{"type":"string"},
          "question":{"type":"string"},
          "calculation":{"type":"string"},
          "answer":{"type":["string","null"]},
          "choices":{"type":"array","items":{"type":"string"}},
          "items":{"type":"array","items":{"type":"string"}},
          "left":{"type":"string"},
          "right":{"type":"string"},
          "footer":{"type":"string"},
          "command":{"type":"string"},
          "code":{"type":"string"},
          "stat":{"type":["string","number"]}
        }
      }
    }
  }
}
JSON

jq -n --arg model "$MODEL" --arg prompt "$LESSON_PROMPT" --slurpfile schema build/lesson-schema.json \
  '{model:$model,prompt:$prompt,stream:false,format:$schema[0],options:{temperature:0.1}}' \
  > build/ollama-request.json

curl -fsS http://127.0.0.1:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d @build/ollama-request.json \
  > build/ollama-response.json

jq -r '.response' build/ollama-response.json > build/lesson-raw.json
jq empty build/lesson-raw.json 2>/dev/null || {
  echo "ERROR: scene compiler returned invalid JSON"
  cat build/lesson-raw.json
  exit 1
}
jq . build/lesson-raw.json > build/lesson-ai.json
SCENES="$(jq '.scenes | length' build/lesson-ai.json)"
echo "✓ Pass 2 lesson generated"
echo "✓ scenes: $SCENES"
echo "✓ build/lesson-ai.json"
