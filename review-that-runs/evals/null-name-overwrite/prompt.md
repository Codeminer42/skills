---
description: Node merge where a null from the second source wipes a good name
tags: [core, bug, node]
runs: 3
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Bash, Write, Edit, Skill, TodoWrite]
---

Review PR #63 for me. The repo is `app/`, the PR is the `feature` branch on `origin`, and its commit message is the PR title and description.
