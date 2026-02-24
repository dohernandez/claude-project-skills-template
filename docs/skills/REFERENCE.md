# Skills Reference

> Auto-generated from `.claude/skills/*/skill.yaml` files.
> Do not edit manually — run `task claude:skills-reference` to regenerate.

## Skill Pattern

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

## Overview

| Skill | Kind | Description | Invocable |
|-------|------|-------------|-----------|
| `commit` | action | Execute git commit with conventional commit message analysis, intelligent sta... | yes |
| `pr-create` | workflow | Creates GitHub pull requests with conventional commit-style titles following ... | no |
| `pr-merge` | workflow | Merge GitHub pull requests with strict CI validation. Never bypasses failed c... | yes |
| `workflow` | workflow | Manage development lifecycle for CI/E2E runner work (start, status, finish). | yes |
| `bugfix` | methodology | Structured debugging methodology for fixing bugs. Ensures bugs are properly u... | no |
| `claude-md` | methodology | Methodology for authoring and maintaining CLAUDE.md. Enforces brevity, releva... | no |
| `task` | methodology | Structured implementation methodology for non-bugfix work (features, chores, ... | no |
| `docs-refresh` | gate | Auto-generate skill reference docs and keep CLAUDE.md skills table in sync. | yes |
| `setup` | helper | Project setup and environment verification for ci-core-e2e-runner. | yes |
| `workflow-setup` | helper | Setup development branch and workflow context for task-based workflows. | no |
| `workflow-finish` | utility | Cleanup git branches after a PR is merged. Removes local branch, remote branc... | yes |
| `create-skill` | meta | Scaffold a new Claude Code skill using the multi-YAML pattern for ci-core-e2e... | yes |
| `linear` | integration | Create and manage Linear issues using templates for the CI/E2E Runner project. | no |

## Skill Details

---

## Actions

> Single-purpose automation skills

### `commit`

**Kind:** action | **Version:** 1.0.0 | **Severity:** medium | **Invocable:** `/commit`

Execute git commit with conventional commit message analysis, intelligent staging, and message generation.

**Owns:**

**Anti-patterns:**
- vague-subject: Using vague words like 'improve', 'enhance', 'update'
- ai-attribution: Including Co-Authored-By, 'Generated with', or AI references
- ticket-references: Including 'Fixes #123' or ticket IDs in commit body
- past-tense: Using past tense like 'added', 'fixed', 'updated'
- file-focused: Describing file operations instead of work done
- long-title: Title exceeds 50 characters
- staging-secrets: Staging .env, credentials, or secret files
- amend-after-hook-failure: Using --amend after pre-commit hook fails

**Sharp edges:**
- amend-after-hook-failure: Using git commit --amend after pre-commit hook fails
- staging-secrets: Accidentally staging .env, credentials, or API keys
- vague-commit-message: Using vague words like 'improve', 'enhance', 'update' in title
- ai-attribution-in-commit: Including ANY AI attribution in commit message
- title-too-long: Commit title exceeds 50 characters
- commit-to-main: Committing directly to main/master branch
- force-push-main: Force pushing to main/master branch
- skip-hooks-without-permission: Using --no-verify without explicit user request
- ticket-refs-in-commit: Including ticket references in commit body
- destructive-git-without-request: Running git reset --hard, checkout ., or clean -f unprompted
- adding-extra-sections: Adding structured sections like 'Changes:', 'Files:', bullet lists to commit body

---

## Workflows

> Multi-step development lifecycle skills

### `pr-create`

**Kind:** workflow | **Version:** 1.0.0 | **Severity:** medium

Creates GitHub pull requests with conventional commit-style titles following project conventions.

**Owns:**

**Anti-patterns:**
- pr-from-main: Creating PR while on main branch
- vague-title: Using vague words like 'update', 'improve', 'enhance'
- ai-attribution: Including ANY AI attribution in PR title, body, or commits
- unpushed-pr: Attempting to create PR without pushing branch first
- no-commit-analysis: Creating PR title without reviewing commits

**Sharp edges:**
- gh-cli-not-installed: GitHub CLI (gh) is not installed
- gh-cli-not-authenticated: GitHub CLI is not authenticated
- on-main-branch: Attempting to create PR while on main branch
- uncommitted-changes: Creating PR with uncommitted changes
- no-commits-to-pr: Branch has no commits ahead of main
- title-too-long: PR title exceeds 50 characters
- missing-scope: PR affects specific area but no scope in title
- branch-not-pushed: Branch exists locally but not on remote
- vague-subject: Subject uses vague verbs like 'update', 'improve', 'change'
- ai-attribution-in-title: PR title, body, or commits contain ANY AI attribution

### `pr-merge`

**Kind:** workflow | **Version:** 1.0.0 | **Severity:** high | **Invocable:** `/pr-merge`

Merge GitHub pull requests with strict CI validation. Never bypasses failed checks.

**Owns:**

**Anti-patterns:**
- bypass-failed-checks: Offering to bypass/merge when CI checks have failed
- auto-merge-without-checks: Merging PR without verifying all CI checks have passed
- ignore-in-progress: Merging while checks are still IN_PROGRESS
- force-merge-conflicts: Attempting to merge when DIRTY (conflicts exist)
- skip-behind-update: Merging when BEHIND without updating branch first
- offer-bypass-on-failure: Asking 'bypass anyway?' when a check has failed

**Sharp edges:**
- bypass-failed-check-offered: Offering to bypass merge when a CI check has failed
- merge-while-checks-running: Attempting merge while statusCheckRollup shows IN_PROGRESS
- merge-with-conflicts: Attempting to merge when mergeStateStatus is DIRTY
- stale-branch-merge: Merging when branch is BEHIND main without updating
- no-pr-for-branch: Running /pr-merge on branch with no PR
- pr-already-merged: Running /pr-merge on already merged PR
- pr-closed: Running /pr-merge on closed (not merged) PR
- bypass-review-with-failed-checks: Offering --admin bypass when checks failed (not just review missing)
- gh-cli-not-authenticated: gh CLI not authenticated when trying to merge

### `workflow`

**Kind:** workflow | **Version:** 1.0.0 | **Severity:** medium | **Invocable:** `/workflow`

Manage development lifecycle for CI/E2E runner work (start, status, finish).

**Owns:**

**Anti-patterns:**
- skip-uncommitted-check: Starting new workflow without checking for uncommitted changes
- force-finish-without-confirmation: Deleting branch without verifying PR is merged
- context-not-gitignored: workflow context committed to repo
- skip-planning-step: Starting work without creating implementation plan
- bypass-failed-checks: Offering to bypass/merge when CI checks have failed
- verbatim-learning-storage: Storing user corrections word-for-word without synthesis

**Sharp edges:**
- uncommitted-changes-lost: Starting new workflow with uncommitted changes in working directory
- branch-already-exists: Trying to create a branch that already exists locally or remotely
- context-file-committed: Workflow context files accidentally committed to repository
- pr-not-merged-force-finish: User requests finish but PR is not merged
- orphaned-remote-branch: Local branch deleted but remote branch remains
- main-branch-drift: Main branch has diverged significantly while working on feature
- detached-head-state: Starting workflow while in detached HEAD state

---

## Methodologies

> Structured approach and process skills

### `bugfix`

**Kind:** methodology

Structured debugging methodology for fixing bugs. Ensures bugs are properly understood before fixing, root-caused with evidence, and fixed with minimal changes. Phases: Reproduce -> Plan -> Fix -> Verify

**Owns:**

**Sharp edges:**
- skipping-reproduction: Jumping to fix without reproducing the bug first
- over-engineering-fix: Refactoring or improving code beyond the minimal fix
- changing-code-to-debug: Modifying implementation logic while investigating
- not-verifying-fix: Not confirming the fix actually resolves the bug
- forgetting-to-remove-debug-output: Leaving debug echo/printf statements in scripts
- cant-reproduce-proceeding-anyway: Proceeding to fix when bug can't be reproduced
- related-issue-dismissal: New issues after fix dismissed without analysis

### `claude-md`

**Kind:** methodology | **Version:** 1.0.0 | **Severity:** high

Methodology for authoring and maintaining CLAUDE.md. Enforces brevity, relevance, and structure.

**Owns:**

**Anti-patterns:**
- full-directory-trees:
- inline-reference-tables:
- onboarding-content:
- contributing-single-links:
- duplicate-information:
- over-documenting-structure:

**Sharp edges:**
- file-tree-in-structure: Using box-drawing characters (├ └ │) for directory trees in CLAUDE.md
- line-count-creep: CLAUDE.md grows past ~120 lines
- editing-between-markers: Hand-editing content between SKILLS_TABLE markers
- missing-built-with: CLAUDE.md missing 'Built with:' declaration in first 15 lines
- onboarding-sections: Adding Getting Started, Installation, or Customizing sections
- reference-table-inline: Large reference tables (>5 rows) inline in CLAUDE.md
- infinite-lint-loop: Claude loops trying to fix lint failures without understanding the patterns

### `task`

**Kind:** methodology

Structured implementation methodology for non-bugfix work (features, chores, refactors, docs). Ensures work is properly scoped, planned, implemented following project patterns, and verified before completion. Phases: Scope -> Plan -> Implement -> Verify

**Owns:**

**Sharp edges:**
- coding-before-scope: Starting to write code before scope is clear
- skipping-plan-approval: Implementing without user approval on the plan
- scope-creep: Adding features or improvements not in original scope
- not-reviewing-changes: Skipping the diff review before considering work done
- vague-scope: Scope defined but too vague to implement
- plan-without-files: Plan doesn't specify which files to change

---

## Gates

> Pre-requisite checker skills

### `docs-refresh`

**Kind:** gate | **Version:** 2.0.0 | **Severity:** high | **Invocable:** `/docs-refresh`

Auto-generate skill reference docs and keep CLAUDE.md skills table in sync.

**Owns:**

**Anti-patterns:**
- stale-reference: REFERENCE.md doesn't match current skill.yaml files
- hand-edited-generated: Manually editing REFERENCE.md or content between CLAUDE.md markers
- skip-after-skill-change: Creating or removing a skill without running task docs:refresh
- missing-markers: CLAUDE.md missing SKILLS_TABLE_START/END markers

**Sharp edges:**
- reference-out-of-sync: REFERENCE.md doesn't match current skill.yaml files
- edited-generated-doc: Hand-edited docs/skills/REFERENCE.md or content between CLAUDE.md markers
- missing-markers: CLAUDE.md missing <!-- SKILLS_TABLE_START --> or <!-- SKILLS_TABLE_END --> markers
- forgot-refresh-after-skill-change: Created, renamed, or deleted a skill without running task docs:refresh
- claude-md-missing: CLAUDE.md file doesn't exist
- structure-section-stale: Repository Structure section in CLAUDE.md lists wrong files

---

## Helpers

> Utility skills (no Stop hook required)

### `setup`

**Kind:** helper | **Version:** 1.0.0 | **Invocable:** `/setup`

Project setup and environment verification for ci-core-e2e-runner.

**Owns:**

**Anti-patterns:**
- installing-node: Installing Node.js or npm for this project
- installing-task-runner: Installing Taskfile CLI for this project
- skipping-gh-auth: Trying to work without gh CLI authentication

### `workflow-setup`

**Kind:** helper | **Version:** 1.0.0 | **Severity:** low

Setup development branch and workflow context for task-based workflows.

**Owns:**

**Anti-patterns:**
- create-worktrees: Creating git worktrees for branch setup
- install-npm-packages: Running npm install or yarn install during setup
- open-ide: Attempting to open an IDE or editor during setup
- branch-from-stale-main: Creating branch without fetching and pulling main first
- skip-context-creation: Creating branch but not writing context.json

**Sharp edges:**
- branch-already-exists: Branch already exists in repository
- stale-base-branch: Creating branch from stale main that's behind remote
- uncommitted-changes: Source repo has uncommitted changes when creating branch

---

## Utilities

> Small operational helpers

### `workflow-finish`

**Kind:** utility | **Invocable:** `/workflow-finish`

Cleanup git branches after a PR is merged. Removes local branch, remote branch, and workflow context files. Usage: - /workflow-finish # Current branch - /workflow-finish <branch-name> # Specific branch

**Owns:**

**Sharp edges:**
- deleting-unmerged-pr: Deleting branch when PR is not merged
- deleting-current-branch: Trying to delete the branch you're currently on
- remote-branch-already-deleted: Trying to delete remote branch that was already deleted (by squash merge)
- workflow-context-orphaned: Workflow context exists but branch is already deleted

---

## Meta

> Skills for managing other skills

### `create-skill`

**Kind:** meta | **Version:** 1.0.0 | **Severity:** high | **Invocable:** `/create-skill`

Scaffold a new Claude Code skill using the multi-YAML pattern for ci-core-e2e-runner.

**Owns:**

**Anti-patterns:**
- name-mismatch: SKILL.md frontmatter name differs from folder basename
- restating-canonical-rules-in-skillmd: Copying patterns/anti-patterns from skill.yaml into SKILL.md
- missing-collaboration-yaml: Creating a skill without collaboration.yaml
- missing-sharp-edges: Creating a skill without sharp-edges.yaml

**Sharp edges:**
- name-mismatch: SKILL.md frontmatter name differs from folder basename
- yaml-indentation-breaks-parse: YAML parse fails due to indentation or unquoted colons
- patterns-duplicated-in-skillmd: SKILL.md restates patterns/anti-patterns instead of pointing to YAML
- missing-claudemd-entry: Skill files created but not added to CLAUDE.md

---

## Integrations

> External service connector skills

### `linear`

**Kind:** integration | **Version:** 1.0.0 | **Severity:** medium

Create and manage Linear issues using templates for the CI/E2E Runner project.

**Owns:**

**Anti-patterns:**
- missing-problem-statement: Creating issues without a clear problem statement
- empty-template-sections: Leaving all optional sections with placeholder text
- wrong-team: Creating issues in wrong team
- duplicate-issues: Creating duplicate issues without checking existing ones

---

*Generated by `task claude:skills-reference`*
