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
    Taskfile.yaml      # Skill management tasks (validate, audit, list, reference)
    scripts/
      validate-skill.sh    # Run validations from a skill's validations.yaml
      audit-skills.sh      # Semantic auditor for multi-YAML compliance
      check-skill-yaml.sh  # Syntax checker
  docs/
    Taskfile.yaml      # Documentation generation tasks (refresh, check)
    scripts/
      generate-skill-reference.sh  # Generate docs/skills/REFERENCE.md
      update-claude-md.sh          # Update CLAUDE.md skills table between markers
      docs-refresh-check.sh        # Verify generated docs are in sync
  scripts/
    logger.sh          # Shared logging utilities
Taskfile.yaml          # Root task runner config
CLAUDE.md              # This file
docs/
  skills/
    REFERENCE.md       # Auto-generated skill reference (do not edit)
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

<!-- SKILLS_TABLE_START -->

| Skill | Kind | Description |
|-------|------|-------------|
| `commit` (`/commit`) | action | Execute git commit with conventional commit message analysis, intelligent sta... |
| `pr-create` | workflow | Creates GitHub pull requests with conventional commit-style titles following ... |
| `pr-merge` (`/pr-merge`) | workflow | Merge GitHub pull requests with strict CI validation. Never bypasses failed c... |
| `workflow` (`/workflow`) | workflow | Manage development lifecycle for CI/E2E runner work (start, status, finish). |
| `bugfix` | methodology | Structured debugging methodology for fixing bugs. Ensures bugs are properly u... |
| `task` | methodology | Structured implementation methodology for non-bugfix work (features, chores, ... |
| `docs-refresh` (`/docs-refresh`) | gate | Auto-generate skill reference docs and keep CLAUDE.md skills table in sync. |
| `setup` (`/setup`) | helper | Project setup and environment verification for ci-core-e2e-runner. |
| `workflow-setup` | helper | Setup development branch and workflow context for task-based workflows. |
| `workflow-finish` (`/workflow-finish`) | utility | Cleanup git branches after a PR is merged. Removes local branch, remote branc... |
| `create-skill` (`/create-skill`) | meta | Scaffold a new Claude Code skill using the multi-YAML pattern for ci-core-e2e... |
| `linear` | integration | Create and manage Linear issues using templates for the CI/E2E Runner project. |

<!-- SKILLS_TABLE_END -->

> Full details: [docs/skills/REFERENCE.md](docs/skills/REFERENCE.md)

## Commands

```bash
task claude:list-skills                          # List all skills
task claude:audit-skills                         # Audit multi-YAML compliance
task claude:audit-skills -- --strict             # Audit with strict mode
task claude:validate-skill -- --skill <name>     # Validate a specific skill
task claude:skills-reference                     # Generate docs/skills/REFERENCE.md
task docs:refresh                                # Generate REFERENCE.md + update CLAUDE.md table
task docs:refresh-check                          # Verify generated docs are in sync
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
