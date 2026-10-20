---
name: taskfile-namespaces
description: "Methodology to audit and regroup Taskfile (go-task) namespaces: inventory every task, find its users, give one membership rule, rename through forwarding shims, and wrap the scripts CI runs. Use when task groups grow messy or CI calls scripts directly."
user-invocable: false
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
hooks:
  Stop:
    - type: command
      command: "task claude:validate-skill -- --skill taskfile-namespaces"
---

# Taskfile Namespaces

## Purpose

Method to clean up the task groups of a repository that runs every command through `task`. It finds what each task does and who calls it. It then gives one membership rule, a full old-to-new name map, and a migration that keeps every caller working.

## Quick Reference

- **Inventory:** `task --list-all --json` plus a YAML parse (internal tasks, task-to-task calls)
- **Users:** search every file for each full task name; sort hits by caller kind
- **Verdicts:** keep · rename · move · merge · internal · remove (remove needs zero callers)
- **Rule:** subject namespaces, plus a few verb namespaces for whole-repo work
- **CI group:** one task for each script that a workflow runs
- **Rename:** forwarding shims, never task aliases (an alias stays in its own namespace)
- **Guard:** a check that every `task <name>` in the repo resolves

```bash
task --list-all --json > tasks.json        # every public task
task --dry <name> -- PROBE                  # see what a task really runs
```

## Key Principle

A task name is an interface. Hooks, CI, docs, skills and other repos call it. Change a name only with a shim and a guard, and never change a CI job name or a hook id.

## Automation

See `skill.yaml` for the patterns, anti-patterns and the procedure.
See `collaboration.yaml` for boundaries with other skills.
See `sharp-edges.yaml` for go-task and GitHub Actions traps.
