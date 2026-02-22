---
name: docs-refresh
description: Keep CLAUDE.md and project documentation in sync with actual skill files and project structure. Use when user says /docs-refresh.
user-invocable: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Edit
  - Write
hooks:
  Stop:
    - type: command
      command: "task claude:validate-skill -- --skill docs-refresh"
---

# Docs Refresh

## Purpose

Keep CLAUDE.md and project documentation in sync with the actual skill files and project structure. This is a manual review-and-update process -- there is no task runner or generated reference file. The human-maintained CLAUDE.md is the single source of truth for project-level Claude instructions.

## Quick Reference

- **Manages**: `CLAUDE.md` (skills listing, repository structure, commands)
- **Sources**: `.claude/skills/*/SKILL.md`, `.claude/skills/*/skill.yaml`, `.github/workflows/*.yml`, `scripts/*.sh`
- **No task runner**: All updates are manual edits to CLAUDE.md

## What to Update

### Skills Listing in CLAUDE.md

When skills are added, removed, or renamed:
1. Scan `.claude/skills/*/skill.yaml` for current skill inventory
2. Compare with what CLAUDE.md documents
3. Add missing skills, remove stale entries, update descriptions

### Repository Structure

When files are added or removed:
1. Check `.github/workflows/` for workflow files
2. Check `scripts/` for shell scripts
3. Update the "Repository Structure" section in CLAUDE.md

### Commands Section

When the E2E pipeline or runner setup changes:
1. Review `scripts/run-e2e.sh` and `scripts/setup-runner.sh`
2. Update the "Commands" section in CLAUDE.md if commands changed

## Procedure

1. **Inventory skills**: `ls .claude/skills/` and read each `skill.yaml`
2. **Compare with CLAUDE.md**: Check if all skills are documented
3. **Update CLAUDE.md**: Add missing skills, remove deleted ones, fix descriptions
4. **Check structure**: Verify the Repository Structure section matches actual files
5. **Review commands**: Ensure documented commands match actual scripts

## Automation
See `skill.yaml` for the full procedure and patterns.
See `sharp-edges.yaml` for common failure modes.
