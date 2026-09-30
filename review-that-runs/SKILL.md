---
name: review-that-runs
description: Review a pull request by running it, not just reading it. Checks out the PR in an isolated worktree, runs the project's own gates, drives the app in Chrome for frontend changes, verifies every finding before writing it, and writes the review to a local notes file with one proof line per finding. Posts nothing to GitHub. Use when asked to review a PR or a branch, locally or before posting.
license: MIT
metadata:
  author: geeksilva97
  version: "1.0"
---

# Review that runs

Written for the post [Six weeks of AI code review: what it caught and what it let through](https://blog.codeminer42.com/six-weeks-of-ai-code-review-what-it-caught-and-what-it-let-through/), which tells what these rules caught and missed over 79 real PRs.

A first-pass PR review for a human to read, cut and post. The agent checks; the human
decides. Nothing here approves or blocks a PR.

Structure borrowed from Matteo Collina's `reviewing-prs.md` (skill `nodejs-core`,
https://github.com/mcollina/skills). The difference: this one executes.

## Hard rules

1. **Verify before you claim.** Anything you cannot prove against the code on the
   branch does not become a comment. A killed false positive is the system working.
2. **Never touch the user's working tree.** Fetch the PR and `git worktree add --detach`
   into a scratch directory. Remove it when you are done.
3. **Nothing reaches GitHub.** No `gh pr review`, no `gh pr comment`. The deliverable is
   the notes file. Posting it is the user's call.
4. **Frontend changes get run in Chrome.** The real app, styled, built from the PR's own
   worktree. A passing test, a screenshot of unstyled markup and a careful read of the
   diff are not validation: layout and overflow are invisible to all three. If the app
   genuinely cannot run, say so and name the reason.
5. **Every finding ends with a proof line.** `*Verified:*` when you tested it,
   `*Inferred:*` when you only read it. No proof line, no comment.
6. **Mark what you changed to make it run.** Any edit to mocks, fixtures or env to boot
   the app carries a `// REVIEW SCRATCH: not part of the PR` comment, and the overview
   names it, so mock behaviour is never read as the PR's.

## Flow

Track progress in a todo list with exactly these steps, in order:

1. **Target**: `gh pr view <N>` and `gh pr diff <N>`. Note the head SHA.
2. **Spec**: find the ticket in the branch, title or description. Unreachable? The PR
   description is the spec. Say which one you used.
3. **Big picture**: read `CLAUDE.md` / `AGENTS.md`, the project's docs and ADRs, and the
   modules around the change. A diff can be locally correct and still wrong for the
   system.
4. **What changed**: one business-level paragraph. "Fixes the duplicate image on the
   product page", never "renamed a to b and added an if".
5. **Scope check**: the spec against the diff. Matches, misses pieces, or does things
   nobody asked for.
6. **Find problems**: correctness (edge cases, wrong data, unhandled errors, races) and
   design (consistency with sibling code, reinventing what already exists, silent
   breaking changes). Open every changed file at the PR's revision. When a function,
   route or event changes, find its other callers, including the ones the diff does
   not touch.
7. **Verify**: test each finding before writing it up. Prefer a failing test that
   reproduces it. Frontend goes through Chrome (below). Discard what does not hold.
8. **Write**: fill the template.
9. **Tighten**: cut filler, restated findings and praise adjectives.
10. **Check anchors**: every anchor must land on a line the PR diff shows.

## Running the PR

- Copy the project's toolchain pins (`.tool-versions`, `.nvmrc`) into the worktree and
  install with the lockfile frozen.
- Run the project's own gates: typecheck, lint, tests. Report what ran and what did not.
- Serve the frontend on a port the user is not using. Their dev server is serving
  *their* branch, not the PR's.
- No backend? Use the project's own mock layer (MSW handlers, fixtures) instead of
  starting services against the user's local database. Seed what the changed flow
  needs, and mark it (rule 6).

## Frontend validation with Chrome DevTools MCP

- `new_page` on the served app, log in, navigate to the changed flow.
- `take_snapshot` to find elements; screenshots are evidence, not discovery.
- Measure layout with `evaluate_script` over the real DOM: `innerWidth`, the container's
  `clientWidth`, the table's `scrollWidth`. State the viewport you measured at, and
  `resize_page` when the finding is about a narrower screen.
- Try the change as each affected role, including one that should not see it.
- `list_console_messages` at the end. New errors are findings.

## Severity

Open each comment with its severity as a plain sentence:

| Tier | Lead-in |
|---|---|
| Blocker | "This breaks prod." / "This loses data." / "This is a security hole." |
| Should-fix | "This is a real bug." |
| Suggestion | "Worth considering." |
| Nitpick | "Small thing." |

## Output template

Write `<repo-root>/pr-<N>-review-notes.md`:

```markdown
# PR #<N> review notes

## Overview

<Business-level description, 2-5 sentences. Name any REVIEW SCRATCH edits.>

*Verdict: <does what was asked / misses X / also does unrelated Y>*

## Validation run

<One line per pass that actually ran, and one line for what could not be checked and why.>

## Comments

<!-- anchor path="path/to/file.ext" start_line=N line=M side=RIGHT -->

<Lead-in. One short paragraph: what breaks and what it costs. At most one evidence
block: a suggestion, a diff, or input -> expected vs got.>

*Verified: <how you confirmed it>*

---

<!-- anchor path="path/to/other.ext" line=N side=RIGHT -->

<next comment>

*Inferred: <what you read, and why you could not test it>*
```

Line numbers are head-branch numbers on lines the diff shows. Use a ` ```suggestion `
block only when the fix is exactly the anchored lines rewritten; GitHub replaces the
whole anchored range when someone clicks Apply. When posted, the review goes out as
`COMMENT`. Approving and requesting changes is a human's call.

When the notes are posted, the review body ends with this line, verbatim:

> *First pass by review-that-runs. Approving is a human's call.*
