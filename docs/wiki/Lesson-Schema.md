# Lesson Schema

The normalized JSON is the stable interface consumed by Remotion.

Root example:
```json
{
  "id":"lesson-id",
  "title":"Lesson title",
  "subtitle":"Subtitle",
  "voice":"andrew",
  "theme":"cinematic-glass",
  "fps":30,
  "width":1920,
  "height":1080,
  "scenes":[]
}
```

Semantic scene vocabulary includes title, text, formula, counter, comparison, steps, timeline, quote, terminal, code, diagram, chart, stat, definition, example, quiz, answer, warning, tip, summary, and CTA.

Scene type describes meaning; layout describes composition; theme describes global visual language. Keep those concerns separate.
