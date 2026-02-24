# claude-project-skills-template

Template repository for organizing Claude Code skills using the multi-YAML pattern with tooling for skill validation and auditing.

Prioritize correctness over cleverness. Ask before architectural changes.

Built with: Bash, Task (go-task), yq, YAML

## Project Structure

```
.claude/skills/     — Skill definitions (one folder per skill)
taskfiles/          — Task runner configs and scripts
docs/               — Generated reference + contributing guides
```

## Skills

<!-- SKILLS_TABLE_START -->

| Skill | Kind | Description |
|-------|------|-------------|
| `commit` (`/commit`) | action | Execute git commit with conventional commit message analysis, intelligent sta... |
| `pr-create` | workflow | Creates GitHub pull requests with conventional commit-style titles following ... |
| `pr-merge` (`/pr-merge`) | workflow | Merge GitHub pull requests with strict CI validation. Never bypasses failed c... |
| `workflow` (`/workflow`) | workflow | Manage development lifecycle for CI/E2E runner work (start, status, finish). |
| `bugfix` | methodology | Structured debugging methodology for fixing bugs. Ensures bugs are properly u... |
| `claude-md` | methodology | Methodology for authoring and maintaining CLAUDE.md. Enforces brevity, releva... |
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
task docs:lint-claude-md                         # Validate CLAUDE.md structure
```

## Git Workflow

**Before committing**, always run:
```bash
task claude:audit-skills
task docs:refresh-check
task docs:lint-claude-md
```
Do not commit if any fail.

**Commit messages** follow [Conventional Commits](https://www.conventionalcommits.org/):
- Format: `<type>(<scope>): <subject>`
- Title: ≤50 chars, specific (avoid "improve", "enhance", "update")
- Body: 1-2 sentences or omit
- NO AI attribution (no Co-Authored-By, no tool references)

Use `/commit` to generate commit messages.

Use `/pr-create` to create pull requests.

Use `/pr-merge` to merge pull requests.

## Conventions

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

### CLAUDE.md Authoring

- 80% relevance rule: every line used in 80%+ of sessions
- Target <120 lines; behavioral instructions near top
- Project structure as key directories only, no file trees
- Reference material lives in docs/ — CLAUDE.md links to it
- Never hand-edit between auto-generated markers
