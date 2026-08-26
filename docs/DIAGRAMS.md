# D2 Architecture Documentation

The `.d2` files are canonical, diffable architecture sources.

```bash
mkdir -p docs/rendered
for f in docs/diagrams/*.d2; do
  d2 "$f" "docs/rendered/$(basename "$f" .d2).svg"
done
```

Files:
- `architecture.d2`: application flow.
- `cicd.d2`: SSH/CI/GHCR release flow.
- `security-boundary.d2`: secret/runtime boundaries.
- `docs/assets/richlesson-icon.svg`: repository/app icon.
