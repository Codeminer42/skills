---
type: llm
weight: 2
focus: { source: file, path: "app/pr-88-review-notes.md" }
---
PASS if a comment points out that `migrations/002_rename_no_show_to_missed.js` has no
JSDoc block, which AGENTS.md requires on every migration, ideally pointing at
`001_split_names.js` as the model.
FAIL if the notes do not mention it.
