# Contributing Skills

Thank you for contributing to Codeminer42's skills collection. This guide walks you through creating and submitting a new skill.

## Quick Start

1. Copy the template:
   ```bash
   cp -r _template my-skill-name
   ```
2. Edit `my-skill-name/SKILL.md` — update the frontmatter and write your instructions.
3. Test the skill locally.
4. Open a pull request.

## Skill Structure

Each skill is a self-contained directory at the repository root:

```
my-skill-name/
├── SKILL.md              # Required: YAML frontmatter + instructions
├── scripts/              # Optional: executable code the agent can run
├── references/           # Optional: detailed documentation loaded on demand
└── assets/               # Optional: templates, data files, images
```

## SKILL.md Format

```yaml
---
name: my-skill-name
description: Clear description of what this skill does and when to use it.
license: MIT
metadata:
  author: your-github-username
  version: "1.0"
---

Instructions that the agent follows when this skill activates.
```

### Naming Rules

- **Directory name** must match the `name` field in frontmatter.
- 1-64 characters. Lowercase letters, numbers, and hyphens only.
- Must not start or end with a hyphen. No consecutive hyphens.
- Use descriptive, specific names: `rails-api-testing` not `testing`.

### Writing Good Descriptions

The `description` field is how agents decide whether to activate your skill. It should:

- Describe **what** the skill does and **when** to use it.
- Include specific keywords and trigger phrases.
- Be 1-1024 characters.

**Good:** "Ruby and Rails coding conventions. Use when writing, reviewing, or refactoring Ruby or Rails code."

**Poor:** "Ruby stuff."

### Writing Good Instructions

- Focus on what the agent does not already know.
- Keep SKILL.md under 500 lines. Move detailed reference material to `references/`.
- Provide defaults, not menus. When multiple approaches work, recommend one.
- Include gotchas — environment-specific facts that defy reasonable assumptions.
- Use concrete examples. Input/output examples are more reliable than prose.

## Testing Your Skill

Before submitting, install and test your skill locally:

```bash
# For Claude Code
cp -r my-skill-name/ ~/.claude/skills/
```

Then verify the skill activates on relevant prompts and produces the expected behavior.

### Checklist

- [ ] `SKILL.md` has valid YAML frontmatter with `name` and `description`.
- [ ] The `name` field matches the directory name exactly.
- [ ] The description clearly explains when to use the skill.
- [ ] Instructions are specific, actionable, and grounded in real expertise.
- [ ] Any scripts are self-contained and include error handling.
- [ ] No secrets, credentials, or internal-only URLs are included.

## Submitting a Pull Request

1. Create a branch: `git checkout -b add-skill/my-skill-name`
2. Add your skill directory at the repository root.
3. Update the **Available Skills** table in `README.md`.
4. Open a pull request with:
   - A clear title: "Add skill: my-skill-name"
   - A description of what the skill does and why it is useful.
   - Evidence that you have tested the skill.
