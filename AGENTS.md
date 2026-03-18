# Project Conventions

This repository contains Agent Skills published by Codeminer42. Skills follow the open [Agent Skills specification](https://agentskills.io/specification).

## Repository Layout

- Each skill is a directory at the repository root containing at minimum a `SKILL.md` file.
- The `_template/` directory is a starter template, not a publishable skill.
- `CONTRIBUTING.md` contains the full guide for skill authors.

## Skill Naming

- Directory name must match the `name` field in SKILL.md frontmatter.
- Use kebab-case: lowercase letters, numbers, hyphens. 1-64 characters.
- No leading, trailing, or consecutive hyphens.
- Names should be descriptive and specific.

## SKILL.md Structure

- YAML frontmatter must include `name` and `description` (required).
- Include `license: MIT` and `metadata.author` for all new skills.
- Keep the markdown body under 500 lines. Move reference material to `references/`.
- Write instructions that focus on what the agent would not know without the skill.

## Pull Requests

- Branch naming: `add-skill/skill-name` for new skills, `update-skill/skill-name` for updates.
- Always update the Available Skills table in `README.md` when adding or removing a skill.
- One skill per pull request unless skills are closely related.

## Quality Standards

- Skills must be grounded in real expertise, not generic advice.
- Include concrete examples, gotchas, and actionable steps.
- Test skills locally before submitting.
- No secrets, credentials, API keys, or internal-only URLs.
