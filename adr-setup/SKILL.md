---
name: adr-setup
description: Set up Architecture Decision Records (ADRs) in a repository. Creates the ADR folder, the template, an index README, a first ADR recording the adoption, and adds a section to AGENTS.md or CLAUDE.md so agents check existing decisions and record new ones while they work. Offers a CI check (a bash script, wired into package.json scripts in Node projects, plus a GitHub Actions workflow) that fails on malformed records, a stale index, dead links in agent instructions, citations of records that don't exist, and edits to merged records. Does nothing if the repo already uses ADRs, except offer the check to a repo this skill set up. Use when asked to set up ADRs, start using architecture decision records, add a decision log, bootstrap docs/adr, or add an ADR check or lint to CI.
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

**One exception: this skill's own layout without the check.** The folder holds a `template.md`, a `README.md` with an `## Index` table, and records named `YYYYMMDDHHMM-<slug>.md`, but no `adr.sh` exists in the repo. An earlier version of this skill set the repo up. Don't redo the setup. Take that folder as `<adr-dir>`, run step 3, and if the user wants the check, go to step 9. Its records are already immutable, so leave the first ADR as it is: the bullet step 5 adds is for a fresh setup only. Run the check before reporting. Records written by hand since the setup may fail it, and 9g covers what to do then.

Also grep `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md` and the docs for "ADR" or "decision record". A mention alone, with no records on disk, means the practice was intended but never set up: **don't stop**, continue the setup and carry what the mention says into step 2.

### 2. Pick the folder

If a mention found in step 1 names a folder for ADRs, use it. Otherwise default to `docs/adr/`. Use `doc/adr/` only if the repo already has a `doc/` folder and no `docs/`. Below, `<adr-dir>` means the chosen path relative to the repo root.

### 3. Ask whether to add the CI check

Ask with the agent's structured question tool (`AskUserQuestion` in Claude Code). Without one, ask in chat and wait for the answer. Don't assume a yes.

Before asking, look at the repo so the question is concrete:

- **Which CI runs.** See step 9a.
- **Whether it's a Node project.** A `package.json` at the root means the check also gets `package.json` scripts (step 9c).

The check is one bash script, `adr.sh`, in every project. It needs only bash, git and awk, which GitHub's runners and every macOS or Linux machine have.

Offer two options, the first marked recommended:

- **Add the check (Recommended).** Name the script and the CI file it would add, for example "`scripts/adr.sh` plus `.github/workflows/adr.yml`".
- **Skip it.**

Say in one line what the check does: it fails CI on malformed records, a stale index, dead links in agent instructions, citations of records that don't exist, and edits to merged records.

### 4. Write the template

Copy [assets/template.md](assets/template.md) to `<adr-dir>/template.md` unchanged.

### 5. Write the first ADR

Get the timestamp with `date +%Y%m%d%H%M` and copy [assets/first-adr.md](assets/first-adr.md) to `<adr-dir>/<timestamp>-record-architecture-decisions-with-adrs.md`. Replace `<adr-dir>` inside it. Status is Accepted: setting the log up *is* the decision being taken.

If the user chose the check, add one more bullet to its Decision list: "`<check>` enforces these rules in CI on every pull request." Take `<check>` from step 9f.

### 6. Write the index README

Copy [assets/README.md](assets/README.md) to `<adr-dir>/README.md`.

- **Without the check:** fill the index table by hand. Add one row per ADR in the folder, oldest first, excluding `README.md` and `template.md`. The date column comes from the file name's timestamp (`YYYY-MM-DD`).
- **With the check:** leave the table empty. Step 9g generates it.

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

#### 9a. Confirm how CI is set up

Find what runs CI:

| Found | CI |
|---|---|
| `.github/workflows/*.yml` or `*.yaml` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI |
| `.circleci/`, `bitbucket-pipelines.yml`, `azure-pipelines.yml`, `Jenkinsfile`, `.buildkite/` | other |
| nothing | none; `git remote get-url origin` on `github.com` means GitHub Actions is available |

Find the default branch with `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`), or `gh repo view --json defaultBranchRef`. Fall back to `main` and say so.

For GitHub Actions, read the existing workflows and copy their conventions into the new one:

- how they reference actions: a tag like `actions/checkout@v4`, or a pinned SHA with a version comment;
- the `runs-on` label (self-hosted runners included). A self-hosted runner needs bash and git; say so in the confirmation.

Then confirm with the question tool before writing anything. Show what you found and what you will add, with the workflow file as the preview:

- the CI system and the file you'll create (`.github/workflows/adr.yml`; if that file exists, ask for another name);
- the triggers: pull requests, and pushes to `<default-branch>`;
- the script path and the commands CI runs.

Offer: "Add it as shown (Recommended)", "Script only, I'll wire CI myself", and a free-text option to change something.

For **GitLab CI**, the job goes into `.gitlab-ci.yml`, their main pipeline file. Show the job from [references/check.md](references/check.md#gitlab-ci) and ask before appending it. For **other** CI systems, don't edit their pipeline config. Install the script, and give the user the two commands to wire (see [references/check.md](references/check.md#any-other-ci)).

#### 9b. Copy the script

Copy [assets/adr.sh](assets/adr.sh) to `scripts/adr.sh`, unless the repo keeps its scripts in `script/` or `bin/` and has no `scripts/`.

In the copy, set `ADR_DIRS=(<adr-dir>)`. Change nothing else. Run `chmod +x` on it.

#### 9c. Add package.json scripts (Node only)

Add these to `scripts` in the root `package.json`, with the path from 9b. Don't overwrite a key that already exists; if one does, tell the user and use a free name.

```json
"adr:check": "bash scripts/adr.sh",
"adr:index": "bash scripts/adr.sh --fix",
"adr:new": "bash scripts/adr.sh new"
```

Edit the JSON as text and keep its formatting.

#### 9d. Add the workflow (GitHub Actions)

Copy [assets/github-workflow.yml](assets/github-workflow.yml) to `.github/workflows/adr.yml`. Replace `<default-branch>` and `<script>` (the path from 9b), and apply the conventions from 9a. CI calls the script directly, not through a package manager, so the job needs no Node or install step, even in a Node project.

Leave the pull-request step at `--base HEAD^1` and `fetch-depth: 2`. The `pull_request` checkout is a merge commit, and its first parent is the base branch tip.

#### 9e. Point the index at the script

In `<adr-dir>/README.md`, replace the blockquote under "Regenerate this table…" with:

```markdown
> Generated by <index>. Don't edit it by hand: change the records, then run it.
```

#### 9f. Extend the agent instructions

Append [assets/agent-instructions-check.md](assets/agent-instructions-check.md) right after the section from step 7. Replace the placeholders:

| Placeholder | Node (run with the repo's package manager, read from its lockfile) | Other |
|---|---|---|
| `<check>` | `` `npm run adr:check` `` / `` `pnpm adr:check` `` / `` `yarn adr:check` `` / `` `bun run adr:check` `` | `` `scripts/adr.sh` `` |
| `<new>` | `` `npm run adr:new -- "<decision title>"` `` / `` `pnpm adr:new "<decision title>"` `` / … | `` `scripts/adr.sh new "<decision title>"` `` |
| `<index>` | `` `npm run adr:index` `` / `` `pnpm adr:index` `` / … | `` `scripts/adr.sh --fix` `` |

#### 9g. Run it

Run the index command once to fill the table, then the check. It must pass on everything this skill wrote.

If it fails on files that were there before, don't fix them silently and don't loosen the script. Typical causes are a dead link in `README.md` or `AGENTS.md`, or an "ADR 3" mention left from an earlier attempt. List each violation for the user and say CI will stay red until they're fixed. Offer to fix them.

### 10. Report

List every file created or changed and anything skipped and why. If the check was installed, give the commands to run it locally and what CI now enforces. [references/check.md](references/check.md) has the full list, if the user asks. Do not commit.

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
