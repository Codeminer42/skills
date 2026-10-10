---
type: llm
focus: { source: file, path: "app/pr-112-review-notes.md" }
---
PASS if the notes follow the skill's template: an Overview with a business-level
description and a `*Verdict:*` line, and a Validation run section that says the rake test
suite ran. If there are comments, each opens with an `<!-- anchor ... -->` line and ends
with a `*Verified:*` or `*Inferred:*` line. An empty Comments section is fine here.
FAIL if a section is missing or any comment lacks its anchor or proof line.
