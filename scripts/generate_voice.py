#!/usr/bin/env python3
import argparse
import asyncio
import json
import math
import shutil
import subprocess
from pathlib import Path

try:
    import edge_tts
except ImportError:
    raise SystemExit(
        "Missing edge-tts.\n"
        "Install it in the active environment with:\n"
        "  python -m pip install edge-tts\n"
    )

PREMIUM_VOICES = {
    "andrew": "en-US-AndrewMultilingualNeural",
    "ava": "en-US-AvaMultilingualNeural",
    "brian": "en-US-BrianMultilingualNeural",
    "emma": "en-US-EmmaMultilingualNeural",
    "guy": "en-US-GuyNeural",
    "jenny": "en-US-JennyNeural",
}

def audio_duration(path):
    if not shutil.which("ffprobe"):
        return None
    p = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        return float(p.stdout.strip())
    except ValueError:
        return None

async def synth(text, voice, output, rate):
    await edge_tts.Communicate(text=text, voice=voice, rate=rate).save(str(output))

async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("lesson", nargs="?", default="build/lesson.json")
    ap.add_argument("--voice", choices=PREMIUM_VOICES.keys())
    ap.add_argument("--rate", default="-4%")
    ap.add_argument("--padding", type=float, default=.9)
    args = ap.parse_args()

    path = Path(args.lesson)
    lesson = json.loads(path.read_text())
    voice_key = args.voice or lesson.get("voice","andrew")
    if voice_key not in PREMIUM_VOICES:
        voice_key = "andrew"
    voice = PREMIUM_VOICES[voice_key]

    out = Path("public/audio")
    out.mkdir(parents=True, exist_ok=True)

    # remove stale scene audio
    for f in out.glob("scene-*.mp3"):
        f.unlink()

    print("Premium neural voice:", voice)

    for i, scene in enumerate(lesson["scenes"], 1):
        narration = str(scene.get("narration","")).strip()
        if not narration:
            narration = str(scene.get("subheading") or scene.get("heading") or "")
        target = out / f"scene-{i:02d}.mp3"
        print(f"[{i}/{len(lesson['scenes'])}] {scene.get('heading','Scene')}")
        await synth(narration, voice, target, args.rate)
        dur = audio_duration(target)
        if dur is not None:
            scene["duration"] = max(float(scene.get("duration",5)), math.ceil((dur+args.padding)*10)/10)
            print(f"  audio {dur:.2f}s -> scene {scene['duration']:.1f}s")

    path.write_text(json.dumps(lesson,indent=2))
    print("Updated:", path)

if __name__ == "__main__":
    asyncio.run(main())
