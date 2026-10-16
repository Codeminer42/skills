---
name: adr-setup
description: Set up Architecture Decision Records (ADRs) in a repository. Creates the ADR folder, the template, an index README, a first ADR recording the adoption, and adds a section to AGENTS.md or CLAUDE.md so agents check existing decisions and record new ones while they work. Offers a check (a bash script, also wired into package.json scripts in Node projects) and writes the job for the project's own CI, so CI fails on malformed records, a stale index, dead links in agent instructions, citations of records that don't exist, and edits to merged records. Does nothing if the repo already uses ADRs, except offer the check to a repo this skill set up. Use when asked to set up ADRs, start using architecture decision records, add a decision log, bootstrap docs/adr, or add an ADR check or lint to CI.
license: MIT
metadata:
  author: talyssonoc
  version: "1.1"
---

# ADR setup

Bootstraps a decision log in the current repository. This skill sets the structure up once. After that, two things keep ADRs written and true:

- the agent-instructions section it installs;
- the check it offers to add to CI.

An agent starts every session without memory of past discussions. If a decision isn't written down, the agent doesn't know it exists and may "improve" the code by undoing it. The setup below makes accepted decisions part of the context every session reads.

A log that drifts is worse than none. A stale record, or a code comment citing a replaced one, reads to an agent as current truth. That's why the CI check matters.

## Conventions this setup installs

- **One decision per file** in a dedicated folder (default `docs/adr/`).
- **File name**: `YYYYMMDDHHMM-<decision-slug>.md`, like a migration. The slug names the *decision*, not the topic: `use-postgresql-as-primary-database`, not `database`.
- **Timestamps, not sequence numbers.** `0001-`, `0002-` collide when two branches add an ADR at the same time. Timestamps don't, and they keep the folder sorted.
- **Statuses**: Proposed, Accepted, Rejected, Deprecated, Superseded (always with a link to the replacing ADR).
- **Immutable.** Once written, only the status changes. A changed decision gets a new ADR that supersedes the old one.
- **Index**: `README.md` in the ADR folder, with a table of date, linked decision, and status. Agents regenerate it.
- **Citations** in code and docs name a record by its file name without `.md`, never by a number.

## Flow

Track progress with these steps, in order.

### 1. Detect an existing setup

Look for any form of ADRs before creating anything (skip `node_modules`, `vendor` and other dependency folders):

- folders: `docs/adr`, `doc/adr`, `docs/adrs`, `adr`, `adrs`, `docs/decisions`, `doc/decisions`, `docs/architecture/decisions`, `architecture/decisions`
- tool config: `.adr-dir` (adr-tools), `.log4brains.yml` (log4brains)
- files named like `*-record-architecture-decisions.md`, `adr-*.md` or `*-adr.md` (case-insensitive)
- markdown files that have both a Status and a Decision heading (Nygard, MADR and similar templates)

**If anything turns up, stop here. This skill is a no-op on such a repo.** Tell the user the project already uses ADRs, and say where (folder, tool, naming scheme), then finish without creating or changing any file. Don't recommend migrating, renaming, adopting this skill's conventions, or dropping their tooling: the team's existing practice wins.

**One exception: this skill's own layout without the check.** The folder holds a `template.md`, a `README.md` with an `## Index` table, and records named `YYYYMMDDHHMM-<slug>.md`, but no `adr.sh` exists in the repo. An earlier version of this skill set the repo up. Don't redo the setup. Take that folder as `<adr-dir>`, run step 3, and if the user wants the check, go to step 9. Its records are already immutable, so leave the first ADR as it is: the bullet step 5 adds is for a fresh setup only. Run the check before reporting. Records written by hand since the setup may fail it, and 9e covers what to do then.

Also grep `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md` and the docs for "ADR" or "decision record". A mention alone, with no records on disk, means the practice was intended but never set up: **don't stop**, continue the setup and carry what the mention says into step 2.

### 2. Pick the folder

If a mention found in step 1 names a folder for ADRs, use it. Otherwise default to `docs/adr/`. Use `doc/adr/` only if the repo already has a `doc/` folder and no `docs/`. Below, `<adr-dir>` means the chosen path relative to the repo root.

### 3. Ask whether to add the CI check

Ask with the agent's structured question tool (`AskUserQuestion` in Claude Code). Without one, ask in chat and wait for the answer. Don't assume a yes.

Before asking, look at the repo so the question is concrete:

- **Which CI runs.** See the table in step 9f.
- **Whether it's a Node project.** A `package.json` at the root means the check also gets `package.json` scripts (step 9b).

The check is one bash script, `adr.sh`, in every project. It needs only bash, git and awk, which CI runners and every macOS or Linux machine have.

Offer two options, the first marked recommended:

- **Add the check (Recommended).** Name the script and where it would run in *this* project's CI, for example "`scripts/adr.sh`, run as a step in your `lint` job in `.github/workflows/ci.yml`". With no CI found, say the check will run locally and that you'll ask which CI to wire it into.
- **Skip it.**

Say in one line what the check does: it fails CI on malformed records, a stale index, dead links in agent instructions, citations of records that don't exist, and edits to merged records.

### 4. Write the template

Copy [assets/template.md](assets/template.md) to `<adr-dir>/template.md` unchanged.

### 5. Write the first ADR

Get the timestamp with `date +%Y%m%d%H%M` and copy [assets/first-adr.md](assets/first-adr.md) to `<adr-dir>/<timestamp>-record-architecture-decisions-with-adrs.md`. Replace `<adr-dir>` inside it. Status is Accepted: setting the log up *is* the decision being taken.

If step 9f ends with the check running in CI, come back and add one more bullet to its Decision list: "`<check>` enforces these rules in CI on every pull request." Take `<check>` from step 9d. If CI doesn't run it, leave the bullet out. Nothing is committed yet, so this edit is still allowed.

### 6. Write the index README

Copy [assets/README.md](assets/README.md) to `<adr-dir>/README.md`.

- **Without the check:** fill the index table by hand. Add one row per ADR in the folder, oldest first, excluding `README.md` and `template.md`. The date column comes from the file name's timestamp (`YYYY-MM-DD`).
- **With the check:** leave the table empty. Step 9e generates it.

### 7. Add the agent-instructions section

Pick the target file:

| Repo has | Edit |
|---|---|
| `CLAUDE.md` that imports `@AGENTS.md` | `AGENTS.md` |
| only `AGENTS.md` | `AGENTS.md` |
| only `CLAUDE.md` | `CLAUDE.md` |
| both, no import between them | ask the user which one (or both) |
| neither | ask the user which file to create; don't pick one |

Append the contents of [assets/agent-instructions.md](assets/agent-instructions.md), replacing every `<adr-dir>`. If the file already mentions ADRs (step 1), leave that text as is and append the section anyway.

Also check for other agent instruction files the project keeps (`.github/copilot-instructions.md`, `.cursor/rules/`, `GEMINI.md`). Mention them in the report; don't edit them unasked.

### 8. Without the check, report

If the user skipped the check, go to step 10.

### 9. Install the check

#### 9a. Copy the script

Copy [assets/adr.sh](assets/adr.sh) to `scripts/adr.sh`, unless the repo keeps its scripts in `script/` or `bin/` and has no `scripts/`.

In the copy, set `ADR_DIRS=(<adr-dir>)`. Change nothing else. Run `chmod +x` on it.

#### 9b. Add package.json scripts (Node only)

Add these to `scripts` in the root `package.json`, with the path from 9a. Don't overwrite a key that already exists; if one does, tell the user and use a free name.

```json
"adr:check": "bash scripts/adr.sh",
"adr:index": "bash scripts/adr.sh --fix",
"adr:new": "bash scripts/adr.sh new"
```

Edit the JSON as text and keep its formatting.

#### 9c. Point the index at the script

In `<adr-dir>/README.md`, replace the blockquote under "Regenerate this table…" with:

```markdown
> Generated by <index>. Don't edit it by hand: change the records, then run it.
```

#### 9d. Extend the agent instructions

Append [assets/agent-instructions-check.md](assets/agent-instructions-check.md) right after the section from step 7. Replace the placeholders:

| Placeholder | Node (run with the repo's package manager, read from its lockfile) | Other |
|---|---|---|
| `<check>` | `` `npm run adr:check` `` / `` `pnpm adr:check` `` / `` `yarn adr:check` `` / `` `bun run adr:check` `` | `` `scripts/adr.sh` `` |
| `<new>` | `` `npm run adr:new -- "<decision title>"` `` / `` `pnpm adr:new "<decision title>"` `` / … | `` `scripts/adr.sh new "<decision title>"` `` |
| `<index>` | `` `npm run adr:index` `` / `` `pnpm adr:index` `` / … | `` `scripts/adr.sh --fix` `` |

#### 9e. Run it

Run the index command once to fill the table, then the check. It must pass on everything this skill wrote.

If it fails on files that were there before, don't fix them silently and don't loosen the script. Typical causes are a dead link in `README.md` or `AGENTS.md`, or an "ADR 3" mention left from an earlier attempt. List each violation for the user and say CI will go red on them once 9f wires the check in. Offer to fix them.

#### 9f. Wire it into the project's CI

The skill ships no CI file. Write the job for this project, in its CI system and its own style.

**Find what runs CI:**

| Found | CI |
|---|---|
| `.github/workflows/*.yml` or `*.yaml` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI |
| `bitbucket-pipelines.yml` | Bitbucket Pipelines |
| `.circleci/config.yml`, `Jenkinsfile`, `.buildkite/`, `azure-pipelines.yml` | that system |
| nothing | none |

With no CI, don't pick one: ask which CI the project uses, or whether the check stays local for now.

Find the default branch with `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`), or `gh repo view --json defaultBranchRef`. Fall back to `main` and say so.

**Read the pipeline before drafting.**

- **Placement.** Where do its lint-type checks live? If there's a `lint` or `checks` job, add a step there. If the project keeps one file per check, add a file next to them.
- **Conventions to copy:** how actions or orbs are referenced (tags, pinned SHAs), runner labels or images, triggers and branch filters, job and step naming, concurrency or cancel settings, required-check names if branch protection lists them.
- **Watch for:** `paths:` filters that would skip the check, depth-1 checkouts, and images without bash.

**Draft the job** to the requirements in [references/check.md](references/check.md#wiring-it-into-ci):

- run on every pull request and on pushes to `<default-branch>`;
- plain check on the default branch, `--base` on pull requests, with the base and the fetch depth that fit this CI;
- bash and git only, calling `bash <script>` directly, with no runtime setup or install.

**Confirm with the question tool before writing.** Use the exact change as the preview: the new file, or the diff of the file you're editing.

Offer:

- "Add it as shown (Recommended)";
- "Leave CI to me" (then give the user the two commands and the base to use);
- a free-text option to change something.

**Write it, then validate.** Run the project's CI linter if one is installed (`actionlint`, `circleci config validate`). If none is, say so in the report.

### 10. Report

List every file created or changed and anything skipped and why. If the check was installed, give the commands to run it locally, where it runs in CI, and what CI now enforces. [references/check.md](references/check.md) has the full list, if the user asks. Do not commit.

## Gotchas

- `date` uses local time. That's fine: the timestamp only orders files and avoids collisions, it is not an audit trail.
- Do not seed ADRs for decisions you infer from the code ("uses PostgreSQL", "uses React"). Without the real context and alternatives, they are guesses dressed as records. Offer to write them with the user instead.
- Do not add a status column value that isn't in the ADR file. The index mirrors the files; the files are the source of truth.
- A superseded ADR keeps its file. Its status line becomes `Superseded by [<new title>](./<new-file>.md)`, and nothing else in it changes.
- The index is regenerated from the files, not hand-merged. When two branches both add rows, resolve the conflict by regenerating.
- The check reads every `YYYYMMDDHHMM-<slug>` token in the repo as a citation, and every "ADR" followed by a number as a numbered one. Write examples in docs with placeholders (`YYYYMMDDHHMM-<decision-slug>`), as the assets do, or the check will fail them.
- On a checkout of the branch head instead of a merge commit, `--base` must be the merge base, not the target branch tip. Otherwise records merged after the branch was cut look deleted. See [references/check.md](references/check.md#picking---base).
- `adr.sh` must stay portable: bash 3.2 (macOS), POSIX awk (BSD awk on macOS, mawk on Ubuntu), no gawk or GNU-only flags. After changing it, run `node --test adr-setup/tests/adr.test.mjs`, once with `ADR_TEST_BASH=/bin/bash` on macOS and once on Linux. Node is only the test runner.

## Further reading

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions), Michael Nygard
- [Architecture Decision Records](https://architecture-decision-record.github.io/): overview, templates, examples
- [ADR writing guide](https://github.com/architecture-decision-record/architecture-decision-record/blob/main/skills/architecture-decision-record-skill/reference/writing-guide.md)
- [Stale docs are prompt injection you wrote yourself](https://blog.codeminer42.com/stale-docs-are-prompt-injection-you-wrote-yourself/), the case for the check
