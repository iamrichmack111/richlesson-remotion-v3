#!/usr/bin/env bash
set -euo pipefail
REPO="${REPO:-richlesson-remotion-v3}"
OWNER="${OWNER:-$(gh api user --jq .login)}"
REMOTE="git@github.com:${OWNER}/${REPO}.wiki.git"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "NOTE: initialize the GitHub Wiki once in the web UI first."
git clone "$REMOTE" "$TMP/wiki"
find "$TMP/wiki" -maxdepth 1 -type f -name '*.md' -delete
cp docs/wiki/*.md "$TMP/wiki/"
cd "$TMP/wiki"
git add -A
git diff --cached --quiet && { echo 'Wiki already current.'; exit 0; }
git commit -m 'docs: sync detailed Richlesson wiki'
git push origin master 2>/dev/null || git push origin main
