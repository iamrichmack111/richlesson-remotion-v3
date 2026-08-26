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
