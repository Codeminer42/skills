# The ADR check

The check is `scripts/adr.sh`, one bash script for every kind of project. It needs bash, git and a POSIX awk, nothing else. In a Node project, `package.json` scripts call it.

It exists because a decision log that drifts from the code is worse than none. An agent reads a stale record, or a comment citing one, as current truth: stale docs are prompt injection you wrote yourself. The check makes drift fail CI instead of failing quietly in the next session.

## What it guarantees

On every pull request, and on every push to the default branch:

- **Every record is well formed.** It has a valid name, a title, the four sections, and a status the index can show.
- **The index tells the truth.** Each folder's README lists every record, oldest first, with the status the file declares.
- **Agent guides don't point at nothing.** Every relative link in a file an agent reads as instructions resolves.
- **Citations name real records.** Anywhere in the repo, a reference to a record names one that exists. A reference to a superseded or deprecated record is flagged at its line.
- **Merged records stay immutable** (pull requests only). A record on the base branch keeps its text, moves its status only forward, and is never deleted or renamed.

## What it checks, and where

| Check | Reads | Fails when | Warns when |
|---|---|---|---|
| Names | every `.md` in each `ADR_DIRS` folder, except `README.md` and `template.md` | a file isn't `YYYYMMDDHHMM-<decision-slug>.md` with a real date and time | |
| Records | each record | no `# ` title, the template's `{{…}}` title left in, a missing `## Status`, `## Context`, `## Decision` or `## Consequences`, an empty or unknown status | |
| Supersession | `Superseded by [title](./file.md)` statuses | the target isn't a record in the same folder, is the record itself, is older, or is Proposed or Rejected | |
| Index | the `## Index` table in each folder's `README.md` | a row is missing, stale (date, title or status), lists a file that isn't a record, or is out of order. `--fix` rewrites it | |
| Folders | every file in the repo | a folder named `adr`, `adrs` or `decisions` holds records but isn't in `ADR_DIRS`; a listed folder is missing or holds no records (so the check can't pass on nothing) | |
| Links | records, ADR READMEs, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (at any depth), the root `README.md` and `CONTRIBUTING.md`, `.github/copilot-instructions.md`, `.cursor/rules/`, `.claude/**/*.md` | a relative link (inline or reference-style) doesn't resolve. URLs, anchors, comments and code are skipped | |
| Citations | every text file git tracks or would track, minus dependencies, lockfiles and files over 1 MB | a `YYYYMMDDHHMM-<slug>` token names no record, or something like `ADR-3` or `ADR 0012` cites a record by a number the layout doesn't have | outside the ADR folders, a citation names a superseded record (and the warning names its replacement) or a deprecated one |
| History (`--base`) | records in `ADR_DIRS` at the base commit | a merged record is deleted or renamed, changes outside its Status section, moves its status backwards or off a final status, or changes which record superseded it | a new record runs over 800 words |

Allowed status moves for a merged record:

- Proposed → Accepted or Rejected
- Accepted → Deprecated or Superseded
- Deprecated → Superseded

Rejected and Superseded are final.

Warnings don't fail the run. In GitHub Actions they print as `::warning` annotations, so they show on the diff line.

## Commands

| Command | `package.json` script (Node projects) | Does |
|---|---|---|
| `scripts/adr.sh` | `adr:check` | check |
| `scripts/adr.sh --base <commit>` | | check, plus history against `<commit>` |
| `scripts/adr.sh --fix` | `adr:index` | regenerate every index, then check |
| `scripts/adr.sh new "<title>"` | `adr:new` | copy the template to a timestamped file, set its title, regenerate the index |

With more than one folder in `ADR_DIRS`, `new` takes `--dir <folder>`.

## Wiring it into CI

The skill ships no CI file. The agent writes the job for the project's own CI, in that project's style. Whatever the system, the job has to do these things:

- **Run on every pull or merge request, and on every push to the default branch.** No path filters: a code-only change can cite a record that doesn't exist.
- **Run the plain check on the default branch**, and `--base <commit>` on a pull request (see below).
- **Have the history `--base` reads.** A depth-1 clone doesn't have the base commit.
- **Need only bash and git.** No language runtime and no dependency install, even in a Node project: call `bash scripts/adr.sh` directly, not the `package.json` script.

### Picking `--base`

`--base` is the commit the pull request merges into, as the checked-out tree sees it. Get this wrong and records merged after the branch was cut look deleted.

- **Checkout is a merge commit** (GitHub Actions on `pull_request`, GitLab merged-results pipelines): pass `HEAD^1`, the target branch tip. A fetch depth of 2 is enough.
- **Checkout is the branch head** (GitLab merge request pipelines, most other CIs): pass the merge base, not the target tip. That needs enough history for the merge base to exist.

### Per system

| CI | Pull request base | History | Notes |
|---|---|---|---|
| GitHub Actions | `HEAD^1` on `pull_request` | `fetch-depth: 2` on `actions/checkout` | `ubuntu-*` runners have bash, git and mawk. If the workflow listens to `pull_request: edited`, only a base change matters to this check. |
| GitLab CI | `$CI_MERGE_REQUEST_DIFF_BASE_SHA` in merge request pipelines | `GIT_DEPTH: 0`, or deep enough for the merge base | The image needs bash and git; Alpine images lack bash. |
| Bitbucket Pipelines | `git merge-base origin/$BITBUCKET_PR_DESTINATION_BRANCH HEAD` | `clone: depth: full`, then fetch the destination branch | |
| CircleCI, Jenkins, Buildkite, Azure | `git merge-base origin/<default-branch> HEAD` after fetching the target branch | whatever the fetch above needs | Check how the pipeline tells a pull request from a branch build before relying on it. |

Before writing anything, read the project's pipeline. Put the check where its other lint-type checks run, and copy its conventions: action refs or pinned SHAs, runner labels or images, triggers, job names, concurrency settings.

## Changing the rules

`ADR_DIRS`, the list of guide files, the word limit and the skipped paths sit at the top of each script.

Editing those settings in a repository is fine. A change to a rule itself belongs upstream in the adr-setup skill.

The skill's tests install the script into throwaway repositories and run it, the way CI does. Node is the test runner only:

```bash
node --test adr-setup/tests/adr.test.mjs                        # with the bash on PATH
ADR_TEST_BASH=/bin/bash node --test adr-setup/tests/adr.test.mjs  # macOS's bash 3.2
```

Run them on macOS and on Linux before merging a change. BSD awk and mawk differ in small ways, and the script has to work under both.
