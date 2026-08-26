#!/usr/bin/env bash
set -euo pipefail

command -v d2 >/dev/null || {
  echo "ERROR: D2 is not installed."
  echo "macOS: brew install d2"
  exit 1
}

mkdir -p docs/diagrams/wiki
mkdir -p docs/wiki/assets

render() {
    src="$1"
    name="$(basename "$src" .d2)"

    echo "Rendering $name..."

    d2 \
      --layout elk \
      --theme 200 \
      --dark-theme 200 \
      "$src" \
      "docs/wiki/assets/${name}.svg"

    d2 \
      --layout elk \
      --theme 200 \
      "$src" \
      "docs/wiki/assets/${name}.png"
}

for src in docs/diagrams/wiki/*.d2; do
    [ -e "$src" ] || continue
    render "$src"
done

echo
echo "✓ Wiki architecture infographics rendered"
