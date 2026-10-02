# review-that-runs evals

Behavioural tests for the skill, run with [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals).

Each case gives the agent a small repository with an open "PR" and grades the review it writes. The bugs are adapted from findings in real reviews, re-implemented from scratch in neutral domains, so we know the right answer for every case.

## Cases

| Case | Stack | What a good review does |
|---|---|---|
| `readonly-clone-bypass` | Node | Finds that `clone()` drops the read-only guard on an audit log |
| `null-name-overwrite` | Node | Finds a `null` name from a second source overwriting a good one |
| `empty-bulk-insert` | Node | Finds the crash when there is nothing extra to insert |
| `empty-insert-all-ruby` | Ruby | Finds `insert_all([])` raising when every member is already known |
| `migration-missing-doc` | Node | Flags the doc block AGENTS.md requires on every migration, and invents no bug |
| `house-rule-no-comments` | Ruby | Does not flag stripped comments, because the house rule requires it |
| `clean-change` | Python | Finds nothing to block |

The last two guard against false alarms. A review that "finds" a bug in a correct change fails them.

## How a case is built

`scaffold.sh` calls `_shared/make-repo.sh`, which builds two things in the run's empty workspace:

- `origin.git/`, a bare remote with `main` (from `fixture/base/`) and `feature` (base plus `fixture/change/`, minus any paths listed in `fixture/deleted`).
- `app/`, a clone sitting on `main`, like a developer's checkout.

The feature commit's message is `fixture/pr.md`: the first line is the PR title, the rest is its description. No code host is involved.

Every fixture runs on a bare runner, with nothing to install: Python's stdlib `unittest`, `node --test`, and the minitest and rake that ship with Ruby.

## Graders

Free checks come from the transcript:

- the skill fired;
- a worktree was used;
- the project's own test runner ran;
- no Node tooling ran in a Python repo;
- nothing was posted.

LLM-judged checks read the notes file:

- the planted bug was found and called a real bug;
- its proof line is `*Verified:*` and describes something that ran;
- the notes follow the template;
- nothing else is falsely called a bug.

## Running

In CI, label a PR `run-evals`. The workflow runs this suite against the base and PR versions of the skill and fails on a regression; see `.github/workflows/skill-evals.yml`.

Locally:

```bash
claude plugin eval ./review-that-runs --scaffold --trust-plugin \
  --allow-tools Bash Write Edit --ablation none --runs 3 \
  --model claude-sonnet-5-5 --max-cost-usd 40
```

Each run is a full review session, so a full local pass is 21 sessions.

On macOS with Docker Desktop installed, the eval sandbox refuses to grant Bash, because Docker Desktop puts symlinks in `~/.docker/cli-plugins/`. Run the suite in CI, or on a machine without them.

## Adding a case

1. Start from a finding the PR's author accepted and fixed. A finding the team argued down is not ground truth, and a case built on it punishes the review that disagrees. A rejected finding can still become a no-bug case, where flagging it is the mistake.
2. Copy a case directory.
3. Write `fixture/base/` and `fixture/change/` with exactly one known problem, or none.
4. Before committing, build the repo with `scaffold.sh` in a scratch directory and prove the problem by running something.

Keep fixtures free of anything taken from a client codebase. Carry over the shape of the bug, never the names, domain or code.
