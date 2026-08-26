# Man Page
Preview:
```bash
man ./man/richlesson.1
```
Install for the current user:
```bash
mkdir -p ~/.local/share/man/man1
cp man/richlesson.1 ~/.local/share/man/man1/
mandb 2>/dev/null || true
man richlesson
```
