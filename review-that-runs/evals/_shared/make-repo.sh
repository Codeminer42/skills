#!/usr/bin/env bash
# Builds the repository a review-that-runs eval case reviews, in the current directory:
#
#   origin.git/   bare remote holding `main` and `feature`
#   app/          clone on `main`, the branch the "user" has checked out
#
# `main` is <case>/fixture/base. `feature` is base with <case>/fixture/change copied
# over it, plus any path listed in <case>/fixture/deleted removed. The feature commit's
# message is <case>/fixture/pr.md: first line is the title, the rest is the PR body.
#
# Usage: make-repo.sh <case-dir>
set -euo pipefail

fixture="$(cd "$1" && pwd)/fixture"
work=$(pwd)

export GIT_AUTHOR_NAME="Sam Rivera" GIT_AUTHOR_EMAIL="sam@example.com"
export GIT_COMMITTER_NAME="Sam Rivera" GIT_COMMITTER_EMAIL="sam@example.com"
export GIT_AUTHOR_DATE="2026-03-02T10:00:00Z" GIT_COMMITTER_DATE="2026-03-02T10:00:00Z"

git init -q --bare -b main "$work/origin.git"
git init -q -b main "$work/app"
cd "$work/app"
git remote add origin "$work/origin.git"

cp -R "$fixture/base/." .
git add -A
git commit -q -m "Initial import"
git push -q origin main

git checkout -q -b feature
cp -R "$fixture/change/." .
if [ -f "$fixture/deleted" ]; then
  while IFS= read -r path; do
    if [ -n "$path" ]; then git rm -q -r "$path"; fi
  done < "$fixture/deleted"
fi
git add -A
export GIT_AUTHOR_DATE="2026-03-04T15:30:00Z" GIT_COMMITTER_DATE="2026-03-04T15:30:00Z"
git commit -q -F "$fixture/pr.md"
git push -q origin feature

git checkout -q main
git branch -q -D feature
git fetch -q origin
