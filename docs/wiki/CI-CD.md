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
