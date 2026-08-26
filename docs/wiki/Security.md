# Security

## Protected data
Never version OAuth clients, refresh tokens, private keys, `.env` secrets, or private books/source material.

## Repository controls
- `.gitignore` / `.dockerignore`,
- Bandit,
- pip-audit,
- npm audit,
- Dependabot,
- SSH Git remote,
- source grounding and validation,
- private-first upload policy.

## Credential incident response
If a credential is exposed: revoke/rotate it, remove it locally, verify ignore rules, inspect Git history, and invalidate dependent tokens.
