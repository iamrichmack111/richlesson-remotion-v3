#!/usr/bin/env python3
import json
import sys
from pathlib import Path

p=Path(sys.argv[1] if len(sys.argv)>1 else "build/lesson.json")
minimum=int(sys.argv[2]) if len(sys.argv)>2 else 75
d=json.loads(p.read_text()); q=d.get("quality",{}); scenes=d.get("scenes",[])
print("\nRICHLESSON PREFLIGHT")
print("="*44)
print(f"Title:               {d.get('title','')}")
print(f"Scenes:              {len(scenes)}")
print(f"Resolution:          {d.get('width','?')}x{d.get('height','?')}")
print(f"Grounding:           {q.get('grounding','?')}/100")
print(f"Scene variety:       {q.get('scene_variety','?')}/100")
print(f"Visual completeness: {q.get('visual_completeness','?')}/100")
print(f"Verification:        {q.get('verification','?')}/100")
print("-"*44)
print(f"QUALITY SCORE:       {q.get('overall','?')}/100")
print("="*44)
bad=[s for s in scenes if s.get("grounded") is False]
if bad:
    print("\nUngrounded scenes:")
    for s in bad: print(f"  - {s.get('heading','Scene')}")
score=int(q.get("overall",0))
if score<minimum:
    print(f"\nERROR: quality score {score} is below required {minimum}.")
    sys.exit(1)
print(f"\n✓ preflight passed (minimum {minimum})")
