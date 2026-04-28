---
name: ship-issue
description: Autonomous PR pipeline for a GitHub issue — plan, implement with tests, run 3 parallel reviewers (security/SAST, UX/design-system, i18n), auto-fix findings, open a PR with a self-review comment. Trigger on "/ship-issue N", "ship issue #N", "implement issue N and open a PR", "run the full pipeline on issue N", "do issue N end to end". Rails-aware; works on any GitHub repo with `gh` CLI.
license: MIT
metadata:
  author: romulostorel
  version: "1.0"
---

# ship-issue — autonomous PR pipeline

You are running an end-to-end pipeline that takes a single GitHub issue from "open ticket" to "open PR with self-review attached." The work is split into six phases with three mandatory halt-and-confirm points so the human always controls when shared-state actions (push, PR create) happen.

The issue number comes from the user — either as a skill argument (`/ship-issue 42` → arg `"42"`), or from natural language ("ship issue 42"). If you can't extract a numeric issue id, ask the user before doing anything.

## Why this exists

A typical "ship a ticket" loop is: read the issue, plan, code, test, get review, fix review, open the PR. Doing it solo collapses planning and reviewing into the same head, which is where bugs hide. This skill restores the separation by spawning independent subagents for the plan and the three review dimensions (security, UX, i18n) — each with no knowledge of the others' findings — and forces the human into the loop at the points that matter (plan approval, ship-it).

## Pre-pipeline: probe the project

Before Phase 0, **probe the repo to learn what stack and conventions you're working with**. Don't hardcode commands; read what's there.

Run these in parallel:

- `ls Gemfile package.json pyproject.toml requirements.txt go.mod Cargo.toml composer.json 2>/dev/null` — stack signal.
- `ls CLAUDE.md AGENTS.md .agents.md 2>/dev/null` — agent guidance file. If found, read it; its conventions outrank anything in this skill.
- `git log --oneline -20` — note the commit-message style (Conventional Commits? plain prose? prefix with ticket id?).
- `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` — actual default branch (don't assume `main`).
- `cat README.md 2>/dev/null | head -100` — sometimes lists test/lint commands explicitly.

Then derive the **quality-gate commands** from what you found. Don't guess; verify each binary exists before relying on it.

| Stack | Test | Lint | SAST | Dep audit |
|---|---|---|---|---|
| Rails | `bundle exec rspec` (or `rails test`) | `bundle exec rubocop` (or `bin/rubocop`) | `bin/brakeman --no-pager` if installed | `bin/bundler-audit` if installed |
| Node | `npm test` / `pnpm test` / `yarn test` (look at `package.json` scripts) | `npm run lint` / `eslint` | `npm audit --omit=dev` | same |
| Python | `pytest` (or `python -m pytest`) | `ruff check` / `flake8` | `bandit -r .` if installed | `pip-audit` if installed |
| Go | `go test ./...` | `gofmt -l . && go vet ./...` | `gosec ./...` if installed | `govulncheck ./...` if installed |
| Rust | `cargo test` | `cargo clippy -- -D warnings` | — | `cargo audit` if installed |

For unfamiliar stacks, ask the user which commands constitute "green" before starting Phase 2.

If the project is **Rails**, also read `references/rails.md` from this skill's directory — it carries the conventions the pipeline assumes (service objects, thin controllers, no model callbacks, paired locales, `acts_as_tenant`-style multi-tenancy when applicable). Cite it to the planner subagent in Phase 1.

## Phase 0 — Preflight

Verify, in parallel:

- `gh issue view <N> --json number,title,body,labels,state,comments` — issue exists and is `open`. Read body + comments. Note labels — they shape the commit prefix (`bug` → `fix:`, `chore` → `chore:`, etc.).
- `git status --porcelain` — must be empty. Untracked files unrelated to the work-in-progress (editor configs, local-only `.claude/settings.local.json`) are acceptable but flag them; don't sweep them into the feature branch.
- `git rev-parse --abbrev-ref HEAD` — note current branch.
- `git fetch origin <default-branch>` then `git rev-list --count HEAD..origin/<default-branch>` — must be `0`.
- `gh auth status` — `gh` CLI is authenticated.

Print a one-line preflight summary: issue title, label, current branch, tree status. **If anything is off, stop and ask before doing anything else.** This is halt-point #1.

## Phase 1 — Plan (subagent)

Spawn a single Plan subagent (`subagent_type: "Plan"` if available; else `general-purpose`). Give it:

1. The issue body + comments verbatim.
2. A concise summary of the project conventions you discovered:
   - Stack and framework versions.
   - Test/lint/SAST commands (the ones derived above).
   - Code-organization conventions from `CLAUDE.md`/`AGENTS.md` if present (e.g., where service objects live, controller style, model rules, generator usage).
   - i18n setup if present (e.g., Rails `config/locales/<locale>/<domain>.yml`, Next.js `messages/<locale>.json`).
   - Multi-tenancy setup if present (e.g., `acts_as_tenant`, schema-per-tenant, row-level RLS) — *only* mention this if the codebase actually uses it.
3. A request for these specific outputs:
   - **Files to add/edit (exact paths)** — be precise.
   - **Multi-tenancy classification per new model** — only if the project uses tenant scoping; otherwise omit this entire bullet.
   - **Test surface** — exact spec/test files + behaviours to assert. Include cross-tenant isolation specs only if the project uses tenant scoping and a new tenant-owned model is introduced.
   - **i18n keys** to add (paired across all configured locales) — omit if the project has no i18n setup.
   - **Out-of-scope list** — anything the issue body hints at but this PR will deliberately not touch.
   - **Risk callouts** — Brakeman/SAST-shaped, XSS, N+1, cross-tenant exposure, or whatever risk classes the stack tends to surface.

Read the plan back to the user as a numbered summary and **halt for approval**. This is halt-point #2. Capture any adjustments before continuing.

## Phase 2 — Implement

Create a feature branch named `<type>/issue-<N>-<short-slug>`:
- `<type>` from the issue's labels: `bug` → `fix`, `chore` → `chore`, `docs` → `docs`, otherwise `feat`. If the repo's commit history uses a different convention (e.g. `feature/` prefix, ticket-id prefix), follow that instead.
- `<short-slug>` 3–5 kebab-case words derived from the issue title.

Implement per the approved plan. Hard rules that hold across stacks:

- Use the framework's generators when adding boilerplate (e.g., `bin/rails g model`, `npm run generate`, etc.) — never hand-write migration files in Rails-style stacks.
- Strong input validation always; never disable param filtering / mass-assignment guards. Never `permit!`-style "accept anything".
- For tenant-scoped repos: never use `.unscoped` / `without_tenant`-style escape hatches in domain code. They belong in admin/maintenance namespaces only.
- Every user-facing string goes through the project's i18n mechanism if one exists. If a locale has multiple translations (e.g., `en` + `pt-BR`), add the key to **all** of them, not just the default.
- Tests live next to what they cover, mirroring the project's existing layout.
- For new tenant-owned models in tenant-scoped projects, add a cross-tenant isolation test (a query under tenant B returns zero records created under tenant A).

After implementing, run the full quality-gate quartet derived from the probe:

```
<test-command>
<lint-command>
<sast-command if available>
<dep-audit if available>
```

All must pass. If lint has trivial autofixable offenses, run the project's autofix flag (e.g., `rubocop -A`, `eslint --fix`) and re-run tests. Anything else: fix the underlying issue, don't suppress.

Commit on the feature branch using the repo's commit-message style (default: Conventional Commits). The body explains **why**, not what. Reference the issue (`Closes #N` in the body, not the subject — keeps the subject under 70 chars).

## Phase 3 — Parallel review (3 subagents)

Spawn three reviewers in **the same message** (parallel). Each gets the diff (`git diff <default-branch>...HEAD`) and the issue body. **None gets the others' results** — they review independently.

The reviewer briefs are stack-aware. The skeleton is the same; the specifics adapt to what you detected.

### Reviewer A — Security & SAST

Stack-specific tools:
- Rails: `bin/brakeman --no-pager`, `bin/bundler-audit`.
- Node: `npm audit --omit=dev`, `eslint-plugin-security` if configured.
- Python: `bandit -r .`, `pip-audit`.
- Go: `gosec ./...`, `govulncheck ./...`.
- Rust: `cargo audit`.

Stack-agnostic checks always:
- OWASP-shape issues: SQLi, mass-assignment, open redirect, command injection, path traversal, CSRF bypass, deserialization.
- Unsafe templating: any HTML output that bypasses default escaping (`raw`, `html_safe`, `dangerouslySetInnerHTML`, `v-html`, `{{{...}}}`, etc.).
- Authentication/authorization gaps on new routes.
- Secret leakage in logs / error messages / commits.
- For tenant-scoped projects: missing tenant-scope on new queries.

Reviewer must run the SAST tool against the diff and report **only new warnings introduced by this diff** (not pre-existing ones).

### Reviewer B — UX & design-system consistency

Compare new templates/components against the repo's existing patterns. The file extensions to scan depend on the stack:
- Rails / Hotwire: `.erb`, `app/components/`, `app/javascript/controllers/`.
- React/Next: `.tsx`/`.jsx`, `components/`, `hooks/`.
- Vue: `.vue`, `composables/`.
- Svelte: `.svelte`.

Flag:
- Deviations from established design-system class strings or component reuse opportunities missed.
- Color/typography/spacing tokens drifting from the existing precedent.
- Accessibility issues — missing labels, focus management, semantic HTML, `aria-*` where appropriate, destructive-action confirmations.
- For each finding, cite the existing file the new code should have matched.

### Reviewer C — i18n & locale completeness

Detect the i18n setup:
- Rails: `config/locales/<locale>/<domain>.yml`. Each new key must appear in every configured locale with matching interpolation variables.
- Next.js: `messages/<locale>.json` or `next-intl` namespaces.
- React-i18next: `public/locales/<locale>/<namespace>.json`.
- No i18n setup detected: reviewer reduces to "flag hardcoded user-facing strings" without locale-pair checks.

Walk every changed view/template/component/flash/error string. Flag:
- Hardcoded user-facing strings outside the i18n call.
- Locale orphans (a key in `en` with no `pt-BR` mirror, or vice-versa) — surface a recursive key diff between locale files.
- Interpolation variables that don't match between locales.
- Pluralization inconsistencies (one locale uses `one:`/`other:`, another doesn't).
- For locales the reviewer doesn't speak fluently, do not invent translations — flag the missing keys and let the human author them.

### Reviewer return format

Each reviewer returns:

```
{
  "reviewer": "A|B|C",
  "summary": "<one sentence>",
  "findings": [
    { "severity": "high|med|low", "location": "path:line", "issue": "...", "fix": "..." }
  ]
}
```

If a reviewer finds nothing, it still returns the structure with `findings: []` and lists what was checked. **No silent passes.**

## Phase 4 — Auto-fix

Collect the three reports. Apply fixes in this order:

1. **All `high` findings** — must be fixed before the PR opens. No exceptions.
2. **`med` findings** — fix unless the cost is large enough to justify carving into a follow-up issue. If you defer one, file `gh issue create` with the project's lowest-priority label and link it from the PR's Follow-ups section.
3. **`low` findings** — fix the cheap ones; defer the rest into the PR's Follow-ups section without filing issues.

After fixing, re-run the quality-gate quartet. All must pass. Amend the existing commit only if the fixes are mechanical (style, missing locale key, attribute additions); otherwise add a second commit (`fix: address review findings on issue-N`) so the review trail is visible in history.

## Phase 5 — Open PR + self-review comment

**Halt before pushing.** This is halt-point #3. Show the user:
- Final diff stat (`git diff --stat <default-branch>...HEAD`).
- Reviewer summaries (one line each, plus a count of findings by severity).
- The drafted PR title + body.

Wait for explicit "ship it" before `git push -u origin <branch>` and `gh pr create`.

PR title: follow the repo's commit-message style. Default `<type>: <short imperative>` under 70 chars.

PR body skeleton — adapt to what the project actually cares about:

```
## Summary
- <bullets — what shipped, why, link to spec doc if one exists in the repo (e.g. `docs/features/<feature>.md`)>

## [Multi-tenancy classification]   ← include this section ONLY if the project uses tenant scoping
<"No new models." OR per-model classification>

## Test plan
- [x] <test command> — N examples/cases, 0 failures
- [x] <lint command> — clean
- [x] <SAST command> — clean
- [ ] Manual smoke: <steps>

## Follow-ups (deliberately out of this PR)
- <items, with linked issue numbers if filed>

Closes #N
```

After `gh pr create`, post a **self-review comment** on the PR with the reviewer findings:

```
## Self-review (3 reviewers)

**Security / <SAST tool>** — <one-line summary>
<bulleted findings, each: severity · file:line · issue → fix applied (or "deferred → #issue")>

**UX / design system** — <one-line summary>
<bulleted findings, same shape>

**i18n / locale completeness** — <one-line summary>
<bulleted findings, same shape>

_Auto-generated by `ship-issue`. High findings were fixed before opening; med/low handling noted inline._
```

Use `gh pr comment <pr-url> --body "<body>"`. Print the PR URL to the user. End the pipeline.

## Halt-and-confirm checklist

The pipeline pauses for explicit user "go" at exactly these points:
1. End of Phase 0 — only if preflight is off.
2. End of Phase 1 — plan approval.
3. End of Phase 5 — final ship-it before push + PR create.

Anywhere else, do not pause unless a tool fails or you discover the plan is wrong, in which case surface it to the user immediately rather than improvising.

## Stack-specific deep-dives

When working in **Rails**, read `references/rails.md` and cite its conventions in the planner brief. It encodes: service objects under `app/services/<domain>/` with `.call`, thin controllers, no model callbacks, paired locales, `acts_as_tenant` rules, RSpec patterns, generator usage.

When working in **other stacks**, derive conventions from `CLAUDE.md`/`AGENTS.md` and the visible code. If you can't tell what the project's pattern is, ask the user before guessing.

## Gotchas

- **Project-scoped overrides.** If the repo has a `.claude/commands/ship-issue.md` (project-scoped slash command), Claude Code's project-scoped command takes precedence over this skill when invoked as `/ship-issue`. That's intentional — projects with strong opinions can override the generalized pipeline. If that file exists, prefer following it over this skill's generic guidance.
- **Default branch isn't always `main`.** Some repos use `master`, `develop`, or `trunk`. The probe step queries `gh repo view` for the actual default; honor that.
- **`gh` not authenticated.** Stop and tell the user to run `gh auth login` themselves — don't try to authenticate from inside the pipeline.
- **Locale parity false positives.** A `*_html` suffix key intentionally interpolates HTML (typically `link_to` output, which the framework marks safe). Reviewer C should not flag this as XSS *if* the interpolated value is framework-marked-safe; it's the safe pattern.
- **Reviewer briefs going stale.** Re-derive the diff (`git diff <default-branch>...HEAD`) right before spawning reviewers — implementing late commits and forgetting to refresh the diff means reviewers audit yesterday's code.
