#!/usr/bin/env python3
import ast
import json
import re
import sys
from fractions import Fraction
from pathlib import Path

AI = Path(sys.argv[1] if len(sys.argv) > 1 else "build/lesson-ai.json")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "build/lesson.json")
SOURCE_FILE = Path(sys.argv[3]) if len(sys.argv) > 3 else None

lesson = json.loads(AI.read_text())
source = SOURCE_FILE.read_text(encoding="utf-8") if SOURCE_FILE and SOURCE_FILE.exists() else ""

def norm(s): return re.sub(r"\s+"," ",str(s)).strip()
def clean_text(v):
    if not isinstance(v,str): return v
    v = "".join(ch for ch in v if ch in "\n\r\t" or ord(ch)>=32)
    v = re.sub(r"[ \t]*\n[ \t]*"," ",v)
    v = re.sub(r" {2,}"," ",v)
    v = re.sub(r"\b(\w+)\s+\1\b",r"\1",v,flags=re.IGNORECASE)
    return v.strip()
def dedupe(items):
    out=[]; seen=set()
    for x in items or []:
        k=norm(x)
        if k and k not in seen: out.append(x); seen.add(k)
    return out

def eval_fraction(expr):
    tree=ast.parse(str(expr).strip().replace("^","**"),mode="eval")
    def walk(n):
        if isinstance(n,ast.Expression): return walk(n.body)
        if isinstance(n,ast.Constant):
            if isinstance(n.value,int): return Fraction(n.value,1)
            if isinstance(n.value,float): return Fraction(str(n.value))
            raise ValueError("non-numeric constant")
        if isinstance(n,ast.UnaryOp) and isinstance(n.op,ast.USub): return -walk(n.operand)
        if isinstance(n,ast.BinOp):
            a,b=walk(n.left),walk(n.right)
            if isinstance(n.op,ast.Add): return a+b
            if isinstance(n.op,ast.Sub): return a-b
            if isinstance(n.op,ast.Mult): return a*b
            if isinstance(n.op,ast.Div):
                if b==0: raise ValueError("division by zero")
                return a/b
        raise ValueError("unsafe expression")
    return walk(tree)
def exact(v): return str(v.numerator) if v.denominator==1 else f"{v.numerator}/{v.denominator}"
def decimal(v):
    x=float(v)
    return str(int(x)) if abs(x-round(x))<1e-12 else f"{x:.6f}".rstrip("0").rstrip(".")
def content_words(s):
    stop={"the","a","an","and","or","of","to","in","is","are","was","were","that","this","it","as","for","with","on","by","from","be","we","you","they"}
    return {w for w in re.findall(r"[a-z0-9]+",str(s).lower()) if len(w)>2 and w not in stop}

scenes=lesson.get("scenes",[])
if not isinstance(scenes,list) or not scenes: raise SystemExit("ERROR: no usable scenes")
cleaned=[]; grounded=0; unverified=0; duplicate_type_penalty=0; missing_visual=0; last_type=None; run=0

for i,scene in enumerate(scenes,1):
    if not isinstance(scene,dict): continue
    for k,v in list(scene.items()):
        if isinstance(v,str): scene[k]=clean_text(v)
    if "options" in scene and "choices" not in scene: scene["choices"]=scene.pop("options")
    if "points" in scene and "items" not in scene: scene["items"]=scene.pop("points")
    if isinstance(scene.get("choices"),list): scene["choices"]=dedupe(scene["choices"])
    if isinstance(scene.get("items"),list): scene["items"]=dedupe(scene["items"])
    scene.setdefault("type","text")
    scene.setdefault("layout","minimal")
    scene.setdefault("duration",5)
    scene.setdefault("heading",f"Scene {i}")
    scene.setdefault("narration",scene.get("subheading",scene["heading"]))

    excerpt=norm(scene.get("source_excerpt",""))
    if source and excerpt and excerpt in norm(source):
        nw=content_words(scene.get("narration","")); ew=content_words(excerpt)
        overlap=len(nw & ew)/max(1,len(nw))
        scene["grounded"]=overlap>=0.20
        scene["grounding_overlap"]=round(overlap,3)
    else:
        scene["grounded"]=False; scene["grounding_overlap"]=0.0
    if scene["grounded"]: grounded+=1

    calc=scene.get("calculation")
    if calc:
        try:
            v=eval_fraction(calc)
            scene["answer"]=exact(v); scene["decimal_answer"]=decimal(v)
            scene["verified"]=True; scene["verification_method"]="deterministic_fraction"
        except (ValueError, SyntaxError, ZeroDivisionError) as e:
            scene["verified"] = False
            scene["verification_error"] = str(e)
            unverified += 1
    elif scene.get("type") in {"quiz","answer","example"} and scene.get("answer") is not None:
        scene["verified"]=False; scene["verification_method"]="source_or_model_only"; unverified+=1

    if scene["type"]==last_type:
        run+=1
        if run>=2: duplicate_type_penalty+=1
    else:
        last_type=scene["type"]; run=0
    if scene["type"] in {"diagram","chart"} and not any(k in scene for k in ("items","formula","stat","code","command","left","right")):
        missing_visual+=1
    cleaned.append(scene)

lesson["scenes"]=cleaned
count=max(1,len(cleaned))
ground_score=round(100*grounded/count)
variety_score=max(0,100-duplicate_type_penalty*18)
visual_score=max(0,100-missing_visual*15)
verification_score=max(0,100-unverified*20)
overall=round(ground_score*.45+variety_score*.20+visual_score*.15+verification_score*.20)
lesson["quality"]={"grounding":ground_score,"scene_variety":variety_score,"visual_completeness":visual_score,"verification":verification_score,"overall":overall}
OUT.write_text(json.dumps(lesson,indent=2),encoding="utf-8")
print(f"✓ normalized scenes: {len(cleaned)}")
print(f"✓ grounded scenes: {grounded}/{len(cleaned)}")
print(f"✓ quality score: {overall}/100")
print(f"✓ wrote {OUT}")
