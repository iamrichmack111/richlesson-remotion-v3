#!/usr/bin/env python3

import re
from pathlib import Path

wiki = Path("docs/wiki")
diagrams = Path("docs/diagrams/wiki")
diagrams.mkdir(parents=True, exist_ok=True)

for md in sorted(wiki.glob("*.md")):
    slug = md.stem.lower()
    target = diagrams / f"{slug}.d2"

    if target.exists():
        continue

    text = md.read_text(errors="ignore")

    title_match = re.search(r"^#\s+(.+)$", text, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else md.stem

    headings = re.findall(r"^##\s+(.+)$", text, re.MULTILINE)
    headings = headings[:8]

    def safe(value):
        return (
            value.replace('"', "'")
            .replace("{", "(")
            .replace("}", ")")
        )

    lines = [
        "direction: right",
        "",
        "page: {",
        f'  label: "{safe(title)}"',
        "  shape: package",
        "}",
        "",
    ]

    previous = "page"

    for i, heading in enumerate(headings, 1):
        node = f"section{i}"
        lines += [
            f"{node}: {{",
            f'  label: "{safe(heading)}"',
            "  shape: document",
            "}",
            "",
            f"{previous} -> {node}",
            "",
        ]
        previous = node

    if not headings:
        lines += [
            'overview: "Concept Overview"',
            "page -> overview",
        ]

    target.write_text("\n".join(lines) + "\n")
    print(f"✓ {target}")

