---
type: llm
weight: 2
focus: { source: file, path: "app/pr-63-review-notes.md" }
---
PASS if that comment ends with a `*Verified:*` line describing a test or script that was
run with a scan product whose name is null, and the "Unnamed item" label it produced.
FAIL if the proof line is `*Inferred:*` or only describes reading code.
