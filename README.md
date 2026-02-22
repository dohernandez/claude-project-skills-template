# claude-project-skills-template

Template repository for organizing [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills using the multi-YAML pattern. Ships with 12 ready-to-use development workflow skills and tooling for validation and auditing.

## What's Included

**12 skills** covering the full development lifecycle:

| Skill | Kind | Purpose |
|-------|------|---------|
| `commit` | action | Conventional commit messages with intelligent staging |
| `workflow` | workflow | Branch lifecycle (start / status / finish) |
| `workflow-setup` | helper | Branch creation and context initialization |
| `workflow-finish` | utility | Post-merge cleanup |
| `pr-create` | workflow | Pull request creation with conventional titles |
| `pr-merge` | workflow | PR merging with strict CI validation |
| `bugfix` | methodology | Structured debugging (reproduce → plan → fix → verify) |
| `task` | methodology | Task management and implementation tracking |
| `linear` | integration | Linear issue management |
| `setup` | helper | Project setup and environment verification |
| `create-skill` | meta | Scaffold new skills from the multi-YAML pattern |
| `docs-refresh` | gate | Keep docs in sync with skill files |

**Tooling:**

- Semantic skill auditor enforcing multi-YAML compliance
- Per-skill validation runner
- PostToolUse hook for edit-time checks
- Task runner integration ([Task](https://taskfile.dev))

## Multi-YAML Pattern

Each skill is a folder under `.claude/skills/` with four canonical files:

```
.claude/skills/commit/
├── SKILL.md              # Thin frontmatter + pointers (what Claude reads)
├── skill.yaml            # Rules: patterns, procedure, ownership, anti-patterns
├── collaboration.yaml    # Dependencies, composition sequences, triggers
└── sharp-edges.yaml      # Common pitfalls with detection and fixes
```

**Why separate files?** Automation reads YAML; humans read Markdown. Keeping rules in `skill.yaml` makes them machine-parseable while `SKILL.md` stays concise for Claude's context window.

## Getting Started

### Use as a template

1. Click **Use this template** on GitHub (or clone manually)
2. Update skill descriptions and scopes in each `skill.yaml` to match your project
3. Edit `CLAUDE.md` to describe your project
4. Run the audit to verify everything is wired up:

```bash
task claude:audit-skills
```

### Add a new skill

Use the built-in meta skill:

```
/create-skill
```

Or manually create the four files under `.claude/skills/<name>/`.

### Available commands

```bash
task claude:list-skills                        # List all skills
task claude:audit-skills                       # Check multi-YAML compliance
task claude:audit-skills -- --strict           # Fail on warnings too
task claude:validate-skill -- --skill <name>   # Validate a single skill
```

## Requirements

- [Task](https://taskfile.dev) (task runner)
- Bash 3.2+
- [yq](https://github.com/mikefarah/yq) (optional, improves YAML parsing)

## License

MIT
