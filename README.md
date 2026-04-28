# Codeminer42 Skills

A collection of [Agent Skills](https://agentskills.io) by [Codeminer42](https://codeminer42.com) — reusable capabilities that help AI coding agents perform specialized tasks more effectively.

## Available Skills

| Skill | Description |
|-------|-------------|
| [sherlock](./sherlock/) | Autonomous investigation loop for finding and fixing performance issues, flaky tests, memory leaks, and reliability problems. |
| [privacy-assessment-rails](./privacy-assessment-rails/) | Assess a Rails app's full codebase for compliance with privacy laws, like GDPR and LGPD. |
| [privacy-by-design-rails](./privacy-by-design-rails/) | Privacy-by-design patterns for Rails features that handle personal data — encryption, consent flows, DSAR endpoints, anonymization, and compliance with privacy laws like GDPR and LGPD. |
| [privacy-review-rails](./privacy-review-rails/) | Review uncommitted or recently changed files for privacy-by-design rule violations (based on privacy laws like GDPR and LGPD) before committing. |
| [ship-issue](./ship-issue/) | Autonomous PR pipeline for a GitHub issue — plan, implement with tests, run 3 parallel reviewers (security/SAST, UX, i18n), auto-fix findings, open a PR with a self-review comment. |

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
