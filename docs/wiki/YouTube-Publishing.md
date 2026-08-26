# YouTube Publishing

Publishing occurs after successful rendering.

## OAuth
Use a desktop/installed-app OAuth client and minimum necessary YouTube upload scope. Never commit client JSON or refresh tokens.

## Safe lifecycle
```text
render -> private upload -> human review -> visibility change
```

## Description files
Richlesson can read a Markdown/text description source. YouTube does not render GitHub Markdown exactly, so Markdown is primarily an authoring format.
