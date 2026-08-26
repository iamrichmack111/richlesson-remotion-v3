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
