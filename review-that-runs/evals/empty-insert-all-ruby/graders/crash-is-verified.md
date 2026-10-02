---
type: llm
weight: 2
focus: { source: file, path: "app/pr-104-review-notes.md" }
---
PASS if that comment ends with a `*Verified:*` line describing an import, test or script
that was actually run with only known members, and the `ArgumentError` it raised.
FAIL if the proof line is `*Inferred:*` or only describes reading code.
