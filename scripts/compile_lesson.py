#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
from pathlib import Path

ALLOWED_SCENES = {
    "title", "text", "formula", "counter", "comparison", "steps", "timeline",
    "quote", "terminal", "code", "diagram", "chart", "stat", "definition",
    "example", "quiz", "answer", "warning", "tip", "summary", "cta"
}

DEFAULT_MODEL = "gemma3:4b"

def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-") or "lesson"

def parse_scalar(v):
    v = v.strip()
    if not v:
        return ""
    if v.lower() in {"true", "false"}:
        return v.lower() == "true"
    try:
        if "." in v:
            return float(v)
        return int(v)
    except ValueError:
        return v

def parse_structured_md(text):
    lines = text.splitlines()
    title = "Untitled Lesson"
    subtitle = ""
    voice = "andrew"
    theme = "cinematic-glass"
    scenes = []

    # Header
    for line in lines:
        if line.startswith("# "):
            title = line[2:].strip()
            break

    header_map = {}
    for line in lines[:20]:
        m = re.match(r"^([A-Za-z_-]+):\s*(.+)$", line.strip())
        if m:
            header_map[m.group(1).lower()] = m.group(2).strip()

    subtitle = header_map.get("subtitle", subtitle)
    voice = header_map.get("voice", voice)
    theme = header_map.get("theme", theme)

    chunks = re.split(r"(?m)^##\s+(?:Scene|[A-Za-z][A-Za-z -]*)\s*$", text)
    headings = re.findall(r"(?m)^##\s+(.+?)\s*$", text)

    for idx, chunk in enumerate(chunks[1:]):
        section_heading = headings[idx].strip() if idx < len(headings) else "Text"
        default_type = section_heading.lower().replace(" ", "-")
        if default_type == "scene":
            default_type = "text"
        if default_type not in ALLOWED_SCENES:
            default_type = "text"

        scene = {"type": default_type, "duration": 5}
        narration_lines = []
        body_lines = []
        list_items = []
        in_code = False
        code_lines = []
        code_lang = ""

        for raw in chunk.strip().splitlines():
            line = raw.rstrip()

            if line.startswith("```"):
                if not in_code:
                    in_code = True
                    code_lang = line[3:].strip()
                    continue
                else:
                    in_code = False
                    scene["code"] = "\n".join(code_lines)
                    if code_lang:
                        scene["language"] = code_lang
                    code_lines = []
                    continue

            if in_code:
                code_lines.append(line)
                continue

            if line.startswith(">"):
                narration_lines.append(line[1:].strip())
                continue

            m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line.strip())
            if m:
                key = m.group(1).lower().replace("-", "_")
                val = parse_scalar(m.group(2))
                if key == "type" and val not in ALLOWED_SCENES:
                    val = "text"
                scene[key] = val
                continue

            if re.match(r"^\s*[-*]\s+", line):
                list_items.append(re.sub(r"^\s*[-*]\s+", "", line).strip())
                continue

            if line.strip():
                body_lines.append(line.strip())

        if list_items:
            if scene.get("type") == "quiz":
                scene["choices"] = list_items
            else:
                scene["items"] = list_items

        if narration_lines:
            scene["narration"] = " ".join(narration_lines)

        # First free line becomes heading unless provided
        if body_lines:
            scene.setdefault("heading", body_lines[0])
            if len(body_lines) > 1:
                scene.setdefault("subheading", " ".join(body_lines[1:]))

        scene.setdefault("heading", section_heading)
        if scene.get("duration") == "auto":
            scene["duration"] = 5
        scenes.append(scene)

    if not scenes:
        # simple fallback: paragraphs become text scenes
        paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip() and not p.startswith("#")]
        for p in paras:
            scenes.append({
                "type": "text",
                "duration": 6,
                "heading": p.splitlines()[0][:90],
                "subheading": " ".join(p.splitlines()[1:])[:240],
                "narration": " ".join(p.splitlines())
            })

    return {
        "id": slugify(title),
        "title": title,
        "subtitle": subtitle,
        "voice": voice,
        "theme": theme,
        "fps": 30,
        "scenes": scenes
    }

def parse_structured_txt(text):
    title = "Untitled Lesson"
    subtitle = ""
    voice = "andrew"
    theme = "cinematic-glass"
    scenes = []
    current = None

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue

        mscene = re.match(r"^\[SCENE\s+([A-Za-z_-]+)\]$", line, re.I)
        if mscene:
            if current:
                scenes.append(current)
            stype = mscene.group(1).lower()
            if stype not in ALLOWED_SCENES:
                stype = "text"
            current = {"type": stype, "duration": 5}
            continue

        m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if not m:
            if current:
                current["subheading"] = (current.get("subheading", "") + " " + line).strip()
            continue

        key = m.group(1).lower()
        val = parse_scalar(m.group(2))

        if current is None:
            if key == "title": title = str(val)
            elif key == "subtitle": subtitle = str(val)
            elif key == "voice": voice = str(val)
            elif key == "theme": theme = str(val)
        else:
            key = key.replace("-", "_")
            if key == "type" and val not in ALLOWED_SCENES:
                val = "text"
            current[key] = val

    if current:
        scenes.append(current)

    return {
        "id": slugify(title),
        "title": title,
        "subtitle": subtitle,
        "voice": voice,
        "theme": theme,
        "fps": 30,
        "scenes": scenes
    }

def build_ai_prompt(text, filename):
    schema = {
        "id": "lesson-slug",
        "title": "Lesson title",
        "subtitle": "Optional subtitle",
        "voice": "andrew",
        "theme": "cinematic-glass",
        "fps": 30,
        "scenes": [
            {
                "type": "title",
                "duration": 5,
                "heading": "Scene heading",
                "subheading": "Optional supporting text",
                "narration": "Concise narration grounded only in the source"
            }
        ]
    }
    return f"""You are a lesson compiler.

Convert the source text into a concise educational video lesson.

Return VALID JSON ONLY.
Do not use markdown fences.
Do not explain your choices.
Do not include chain-of-thought.
Do not invent facts that are not present in the source.

Allowed scene types:
{", ".join(sorted(ALLOWED_SCENES))}

Use:
- title for opening scene
- text for ordinary explanation
- formula for equations or symbolic rules
- counter for meaningful numeric progression
- comparison for A vs B
- steps for processes or sequences
- timeline for chronological material
- quote only for an exact short quotation from the source
- terminal for shell commands
- code for source code
- diagram when relationships or architecture should be visualized
- chart when numeric series are explicitly present
- stat for one important number
- definition for term + meaning
- example for worked examples
- quiz for a multiple-choice check
- answer for answer reveal
- warning for cautions
- tip for practical advice
- summary for final recap
- cta only if the source itself supports a call to action

Every scene should have narration.
Keep narration natural and generally 1-3 sentences.
Preserve formulas, commands, terminology, and numbers exactly.
Use duration 5 unless more time is clearly needed.
Default voice: andrew
Default theme: cinematic-glass
FPS: 30

Target schema example:
{json.dumps(schema, indent=2)}

Source filename: {filename}

SOURCE:
{text}
"""

def ollama_generate(text, filename, model):
    prompt = build_ai_prompt(text, filename)
    proc = subprocess.run(
        ["ollama", "run", model],
        input=prompt,
        text=True,
        capture_output=True
    )
    if proc.returncode != 0:
        raise SystemExit("Ollama failed:\n" + proc.stderr)

    out = proc.stdout.strip()
    # Remove accidental fences if any
    out = re.sub(r"^```(?:json)?\s*", "", out)
    out = re.sub(r"\s*```$", "", out)

    # best-effort JSON extraction
    first = out.find("{")
    last = out.rfind("}")
    if first != -1 and last != -1:
        out = out[first:last+1]

    try:
        return json.loads(out)
    except json.JSONDecodeError as e:
        Path("build").mkdir(exist_ok=True)
        Path("build/ollama-raw.txt").write_text(proc.stdout)
        raise SystemExit(
            f"Model did not return valid JSON ({e}). "
            "Raw response saved to build/ollama-raw.txt"
        )

def validate(data):
    if not isinstance(data, dict):
        raise SystemExit("Lesson must be a JSON object.")
    data.setdefault("id", slugify(data.get("title", "lesson")))
    data.setdefault("title", "Untitled Lesson")
    data.setdefault("subtitle", "")
    data.setdefault("voice", "andrew")
    data.setdefault("theme", "cinematic-glass")
    data.setdefault("fps", 30)

    cleaned = []
    for i, scene in enumerate(data.get("scenes", [])):
        if not isinstance(scene, dict):
            continue
        stype = str(scene.get("type", "text")).lower()
        if stype not in ALLOWED_SCENES:
            stype = "text"
        scene["type"] = stype
        scene.setdefault("duration", 5)
        try:
            scene["duration"] = max(2, float(scene["duration"]))
        except Exception:
            scene["duration"] = 5
        scene.setdefault("heading", f"Scene {i+1}")
        scene.setdefault("narration", scene.get("subheading", scene["heading"]))
        cleaned.append(scene)

    if not cleaned:
        raise SystemExit("No scenes were generated.")
    data["scenes"] = cleaned
    return data

def main():
    ap = argparse.ArgumentParser(description="Compile .md or .txt into Richlesson JSON.")
    ap.add_argument("input")
    ap.add_argument("-o", "--output", default="build/lesson.json")
    ap.add_argument("--ai", action="store_true", help="Use local Ollama to restructure messy input")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--theme", help="Override lesson theme")
    ap.add_argument("--voice", help="Override voice")
    args = ap.parse_args()

    path = Path(args.input)
    if path.suffix.lower() not in {".md", ".txt"}:
        raise SystemExit("Input must be .md or .txt")

    text = path.read_text(encoding="utf-8")

    if args.ai:
        data = ollama_generate(text, path.name, args.model)
    else:
        data = parse_structured_md(text) if path.suffix.lower() == ".md" else parse_structured_txt(text)

    data = validate(data)
    if args.theme:
        data["theme"] = args.theme
    if args.voice:
        data["voice"] = args.voice

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(out)

if __name__ == "__main__":
    main()
