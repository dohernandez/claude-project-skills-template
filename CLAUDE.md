# claude-project-skills-template

Template repository for organizing Claude Code skills using the multi-YAML pattern. Provides a ready-to-use set of development workflow skills and tooling for skill validation and auditing.

## Project Structure

```
.claude/
  skills/              # All skills live here (one folder per skill)
  hooks/
    check-skill-structure.sh   # PostToolUse hook — validates skills on edit
taskfiles/
  claude/
    Taskfile.yaml      # Skill management tasks (validate, audit, list)
    scripts/
      validate-skill.sh    # Run validations from a skill's validations.yaml
      audit-skills.sh      # Semantic auditor for multi-YAML compliance
      check-skill-yaml.sh  # Syntax checker
  scripts/
    logger.sh          # Shared logging utilities
Taskfile.yaml          # Root task runner config
CLAUDE.md              # This file
docs/
  contributing/
    bash-script-code-style.md  # Shell script conventions
```

## Skills

Each skill is a folder under `.claude/skills/` containing four canonical files:

| File | Purpose |
|------|---------|
| `SKILL.md` | Thin frontmatter + pointers — what Claude reads first |
| `skill.yaml` | Canonical rules: patterns, procedure, ownership, anti-patterns |
| `collaboration.yaml` | Dependencies, composition sequences, triggers |
| `sharp-edges.yaml` | Common pitfalls with detection hints and fixes |

### Skill Kinds

| Kind | Description |
|------|-------------|
| action | Single-purpose automation |
| workflow | Multi-step development lifecycle |
| methodology | Structured approach/process |
| gate | Pre-requisite checkers |
| helper | Utility skills (no Stop hook required) |
| utility | Small operational helpers |
| meta | Skills for managing other skills |
| integration | External service connectors |

### Available Skills

- `commit` — Git commits with conventional message format and intelligent staging
- `workflow` — Development lifecycle automation (start/status/finish branches)
- `workflow-setup` — Create branch and initialize workflow context
- `workflow-finish` — Post-merge cleanup (branch deletion, context removal)
- `pr-create` — Create pull requests with conventional titles
- `pr-merge` — Merge pull requests with strict CI validation
- `bugfix` — Structured debugging process (reproduce, plan, fix, verify)
- `task` — Task management and implementation tracking
- `linear` — Linear issue integration
- `setup` — Project setup and environment verification
- `create-skill` — Scaffold new skills using the multi-YAML pattern
- `docs-refresh` — Keep CLAUDE.md and docs in sync with actual skill files

## Commands

```bash
task claude:list-skills                          # List all skills
task claude:audit-skills                         # Audit multi-YAML compliance
task claude:audit-skills -- --strict             # Audit with strict mode
task claude:validate-skill -- --skill <name>     # Validate a specific skill
```

## Conventions

### Commits

Follow Conventional Commits: `<type>(<scope>): <subject>`

- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Title <= 50 characters, imperative mood, specific subjects
- No AI attribution, no ticket references, no emojis
- Never commit directly to main/master

### Skill Naming

- Lowercase + hyphens + underscores only
- Max 64 characters
- Must match folder name and SKILL.md frontmatter `name:`
- Cannot use reserved words (help, config, settings, etc.)

### SKILL.md Authoring

- Keep SKILL.md thin — purpose, quick reference, pointers to YAML files
- Put patterns and anti-patterns in `skill.yaml`, not SKILL.md
- Non-helper skills must define a Stop hook that runs validation
- Target < 100 lines

## Contributing

- [Bash Script Code Style](docs/contributing/bash-script-code-style.md) — conventions for shell scripts (derived from the consensus-*.sh family)

## Customizing This Template

1. Clone this repo
2. Update skill descriptions and scopes to match your project
3. Add project-specific skills with `/create-skill`
4. Run `task claude:audit-skills` to verify compliance
5. Update this CLAUDE.md to reflect your project
