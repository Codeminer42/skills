---
name: review-that-runs
description: Review a pull request by running it, not just reading it. Detects the project's forge (GitHub, GitLab, Bitbucket, Azure DevOps, Gerrit, plain git) and stack, checks out the change in an isolated worktree, runs the project's own CI gates, drives the app in Chrome for frontend changes, verifies every finding before writing it, and writes the review to a local notes file with one proof line per finding. Posts nothing to the code host. Use when asked to review a PR, MR, change or branch, locally or before posting.
license: MIT
metadata:
  author: geeksilva97
  version: "1.1"
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
3. **Nothing reaches the code host.** No `gh pr review`, `glab mr note`, `az repos pr` comment etc. The deliverable is the notes file. Posting it is the user's call.
4. **Detect, don't assume.** Forge, language, package manager and gates come from the repository, never from habit. A guessed `npm test` that fails in a Ruby repo gets blamed on the PR.
5. **Frontend changes get run in Chrome.** The real app, styled, built from the PR's own
   worktree. A passing test, a screenshot of unstyled markup and a careful read of the
   diff are not validation: layout and overflow are invisible to all three. If the app
   genuinely cannot run, say so and name the reason.
6. **Every finding ends with a proof line.** `*Verified:*` when you tested it,
   `*Inferred:*` when you only read it. No proof line, no comment.
7. **Mark what you changed to make it run.** Any edit to mocks, fixtures or env to boot
   the app carries a `// REVIEW SCRATCH: not part of the PR` comment, and the overview
   names it, so mock behaviour is never read as the PR's.

## Flow

Track progress in a todo list with exactly these steps, in order:

1. **Detect**: identify the forge, then fetch the head and build the project profile
   (below) before running anything.
2. **Target**: read the PR's metadata and diff with the forge's own tool, and fetch its head. Note the head SHA and the base branch.
3. **Spec**: find the ticket in the branch, title or description. Unreachable? The PR
   description is the spec. Say which one you used.
4. **Big picture**: read `CLAUDE.md` / `AGENTS.md`, the project's docs and ADRs, and the modules around the change. A diff can be locally correct and still wrong for the system.
5. **What changed**: one business-level paragraph. "Fixes the duplicate image on the product page", never "renamed a to b and added an if".
6. **Scope check**: the spec against the diff. Matches, misses pieces, or does things nobody asked for.
7. **Find problems**: correctness (edge cases, wrong data, unhandled errors, races) and design (consistency with sibling code, reinventing what already exists, silent breaking changes). Open every changed file at the PR's revision. When a function, route or event changes, find its other callers including the ones the diff does
   not touch.
8. **Verify**: test each finding before writing it up. Prefer a failing test that reproduces it. Frontend goes through Chrome (below). Discard what does not hold.
9. **Write**: fill the template.
10. **Tighten**: cut filler, restated findings and praise adjectives.
11. **Check anchors**: every anchor must land on a line the PR diff shows.

## Detecting the project

The forge comes from the remote and decides how to fetch. Everything else comes from the PR's head, since a PR can change the lockfile or CI config.

- **Forge**: from `git remote get-url origin`. Decides how to fetch the head (`pull/<N>/head`, `merge-requests/<N>/head`, `refs/changes/...`), the name of the thing (PR, MR, change), anchor format and suggestion syntax. Self-hosted and unrecognised? Ask. CLI missing or logged out? Fall back to plain `git fetch` and ask for the description.
- **Stack**: manifests and lockfiles name the language, package manager, toolchain pins and frozen-install command. Monorepo? Note which packages the diff touches.
- **Gates**: read the CI config first (`.github/workflows/`, `.gitlab-ci.yml`,
`bitbucket-pipelines.yml`, `Jenkinsfile`...). What CI runs is what will judge the PR. `Makefile`, `bin/`, `script/` and `package.json` scripts usually wrap the same steps.
- **Runtime**: how the app boots (compose, `Procfile.dev`, `bin/dev`), what services it needs, which mock layer exists, and whether the diff renders in a browser.

| Forge | Metadata and diff | Fetch the head |
|---|---|---|
| GitHub | `gh pr view <N> --json title,body,headRefOid,baseRefName`, `gh pr diff <N>` | `git fetch origin pull/<N>/head` |
| GitLab | `glab mr view <N> --output json` (`sha`, `target_branch`), `glab mr diff <N>` | `git fetch origin merge-requests/<N>/head` |
| Gitea / Forgejo | REST `/api/v1/repos/<owner>/<repo>/pulls/<N>` and `.diff` | `git fetch origin pull/<N>/head` |
| Bitbucket Cloud | REST `/2.0/repositories/<ws>/<repo>/pullrequests/<N>` and `/diff` | The source branch; for a fork, from the fork's URL |
| Azure DevOps | `az repos pr show --id <N>` (`lastMergeSourceCommit`) | `sourceRefName`; `refs/pull/<N>/merge` is a merge preview, not the head |
| Gerrit | `ssh -p 29418 <host> gerrit query --current-patch-set change:<N>` | `git fetch origin refs/changes/<NN>/<N>/<patchset>`, `NN` = last two digits |
| Plain git | The user names the branch and its base | `git fetch origin <branch>` |

Diff against the merge base (`git diff <base>...<head>`, three dots). Two dots against a moved base shows other people's commits as the PR's.

| Lockfile | Frozen install |
|---|---|
| `pnpm-lock.yaml` / `yarn.lock` / `package-lock.json` / `bun.lock` | `pnpm i --frozen-lockfile` / `yarn install --immutable` (v1: `--frozen-lockfile`) / `npm ci` / `bun i --frozen-lockfile` |
| `Gemfile.lock` | `BUNDLE_FROZEN=true bundle install` |
| `uv.lock` / `poetry.lock` / `Pipfile.lock` | `uv sync --frozen` / `poetry sync` / `pipenv sync` |
| `go.sum` / `Cargo.lock` | `go mod download` / `cargo fetch --locked` |
| `composer.lock` / `mix.lock` | `composer install` / `mix deps.get` |
| `mvnw` / `gradlew` / `packages.lock.json` | the wrapper, never a global binary / `dotnet restore --locked-mode` |

Toolchain pins to copy: `.tool-versions`, `mise.toml`, `.nvmrc`, `.node-version`, `.ruby-version`, `.python-version`, `rust-toolchain.toml`, `global.json`, the `packageManager` field. A CI step that needs secrets or deploy access does not run locally: list it under what could not be checked. Monorepo (`pnpm-workspace.yaml`, `turbo.json`, `nx.json`, Cargo or Go workspaces): run the gates for the changed packages and their dependents.

Write the profile as the first line of the validation run, e.g. "GitLab MR, Rails 7 +
Hotwire, Ruby 3.3, gates from `.gitlab-ci.yml`: rspec, rubocop, brakeman."

## Running the PR

- Copy the project's toolchain pins into the worktree and install with the lockfile frozen, using the command the profile names.
- Run the project's own gates, the ones CI runs. Report what ran and what did not.
- Serve the frontend on a port the user is not using. Their dev server is serving
  *their* branch, not the PR's.
- No backend? Use the project's own mock layer (MSW handlers, fixtures, cassettes,
  factories) instead of starting services against the user's local database. Compose
  stacks run under their own project name (`-p review-<N>`) and ports, or not at all. Seed what the changed flow needs, and mark it (rule 7).

## Frontend validation with Chrome DevTools MCP

Server-rendered templates (ERB, Jinja, Blade, HEEx...) count as frontend.

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

Write `<repo-root>/<pr|mr|change>-<N>-review-notes.md`, using the forge's term:

```markdown
# <PR|MR|Change> #<N> review notes (<forge>)

## Overview

<Business-level description, 2-5 sentences. Name any REVIEW SCRATCH edits.>

*Verdict: <does what was asked / misses X / also does unrelated Y>*

## Validation run

<The project profile. Then one line per pass that actually ran, and one line for what
could not be checked and why.>

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

Line numbers are head-branch numbers on lines the diff shows. `side=RIGHT` is GitHub's
term; on other forges it is the new-file line. Use the forge's suggestion syntax (` ```suggestion ` on GitHub, ` ```suggestion:-0+0 ` on GitLab, a plain ` ```diff `
elsewhere) only when the fix is exactly the anchored lines rewritten: Apply replaces the
whole anchored range. When posted, the review goes out as a plain comment, with no
approval, vote or change request. Those are a human's call.

When the notes are posted, the review body ends with this line, verbatim:

> *First pass by [review-that-runs](https://github.com/Codeminer42/skills/tree/main/review-that-runs). Approving is a human's call.*
