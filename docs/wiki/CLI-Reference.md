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
