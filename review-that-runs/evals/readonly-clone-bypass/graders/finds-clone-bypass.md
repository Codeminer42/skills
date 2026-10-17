---
type: llm
weight: 3
focus: { source: file, path: "app/pr-57-review-notes.md" }
---
PASS if a comment says the read-only guard does not survive `clone()`: `auditQuery()`
patches `update`/`del` on one builder instance, but `clone()` returns a fresh `Query`
without them, so `auditQuery().clone().del()` (or `.update()`) changes the audit log.
It must be presented as a real bug or worse (Blocker or Should-fix lead-in), since the
PR's purpose and AGENTS.md both say audit entries must never change.
FAIL if the notes miss it, or only mention it as a suggestion or nitpick.
