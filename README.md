# Codeminer42 Skills

A collection of [Agent Skills](https://agentskills.io) by [Codeminer42](https://codeminer42.com) — reusable capabilities that help AI coding agents perform specialized tasks more effectively.

## Available Skills

| Skill | Description |
|-------|-------------|
| *No skills published yet. See [Contributing](./CONTRIBUTING.md) to add one.* | |

## Installation

Install all skills from this repository:

```bash
npx skills add Codeminer42/skills
```

Install a specific skill:

```bash
npx skills add Codeminer42/skills --skill skill-name
```

### Manual Installation

For Claude Code, copy a skill directory directly:

```bash
cp -r skill-name/ ~/.claude/skills/
```

## What Are Agent Skills?

Skills are folders of instructions, scripts, and resources that AI agents can discover and use to perform better at specific tasks. They follow the open [Agent Skills specification](https://agentskills.io/specification) and work across compatible agents including Claude Code, GitHub Copilot, Cursor, and others.

Each skill contains at minimum a `SKILL.md` file with YAML frontmatter (name and description) followed by markdown instructions.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on creating and submitting new skills.

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.
