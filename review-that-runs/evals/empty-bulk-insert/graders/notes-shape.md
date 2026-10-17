---
type: llm
focus: { source: file, path: "app/pr-71-review-notes.md" }
---
PASS if the notes follow the skill's template: an Overview with a business-level
description and a `*Verdict:*` line, a Validation run section that names which of the
project's own gates ran, and a Comments section where every comment opens with an
`<!-- anchor ... -->` line and ends with a `*Verified:*` or `*Inferred:*` line.
FAIL if a section is missing or any comment lacks its anchor or proof line.
