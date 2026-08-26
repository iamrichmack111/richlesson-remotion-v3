# AI Pipeline

AI is optional. It is useful when ordinary prose must be converted into a lesson plan.

## Preferred two-pass pattern
1. Planner: goal, sections, source excerpts, recommended scene types.
2. Compiler: strict scene JSON.

## Controls
- Ollama HTTP API instead of interactive terminal parsing.
- non-streaming structured response,
- low temperature,
- JSON schema,
- exact source excerpts,
- normalization,
- quality/preflight threshold,
- human review before public publishing.

Do not treat a valid JSON object as proof that facts are correct.
