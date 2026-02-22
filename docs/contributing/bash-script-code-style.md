# Bash Script Code Style

> Derived from analysis of the `consensus-*.sh` script family in [genlayer-node](https://github.com/YeagerAI/genlayer-node).

## Core Requirements

- `#!/bin/bash` + `set -euo pipefail` always (except library files that are only `source`d)
- ALL logic inside functions — no inline code
- `main "$@"` as the last line
- Script header documentation block (purpose, usage, options, env vars, examples, outputs)

## Acceptable Top-Level Code

1. Shebang + safety settings
2. Header documentation block
3. `readonly` constants and `SCRIPT_DIR`/`PROJECT_ROOT`
4. `source` statements for shared libraries
5. Global variable declarations with env-var defaults
6. Function definitions
7. `trap` statements
8. `main "$@"` (last line only)

## Script Template

```bash
#!/bin/bash
set -euo pipefail

# ============================================================================
# SCRIPT NAME
# ============================================================================
# Description of what this script does
#
# Usage:
#   ./script-name.sh [OPTIONS]
#
# Options:
#   --option-name VALUE   Description of option
#   --flag                Description of flag
#   --debug               Enable debug logging
#   --help                Show help message
#
# Environment Variables:
#   REQUIRED_VAR          Description
#   DEBUG_MODE            Enable debug logging (true/false)
#
# Examples:
#   ./script-name.sh --option-name foo
#   ./script-name.sh --flag --debug
#
# Outputs:
#   - Description of files/state modified
#
# ============================================================================

# ============================================================================
# CONSTANTS
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

# Exit codes
readonly SUCCESS=0
readonly ERR_GENERAL=1
readonly ERR_INVALID_ARGS=2
readonly ERR_MISSING_DEPS=3
readonly ERR_FILE_NOT_FOUND=4

# Default values
readonly DEFAULT_NETWORK="genlayerTestnet"
readonly DEFAULT_GROUP="default"

# ============================================================================
# SOURCE SHARED FUNCTIONS
# ============================================================================
SCRIPT_SHARED_DIR="$PROJECT_ROOT/scripts/shared"
source "$SCRIPT_SHARED_DIR/logger.sh"
source "$SCRIPT_SHARED_DIR/utils.sh"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================
GROUP="${DEFAULT_GROUP}"
NETWORK="${DEFAULT_NETWORK}"
DEBUG_MODE="${DEBUG_MODE:-false}"

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================
validate_arguments() {
    if [[ -z "$REQUIRED_VAR" ]]; then
        die "Required var not specified (use --option-name)" $ERR_INVALID_ARGS
    fi
    return $SUCCESS
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Short description of script purpose.

Options:
    --option-name VALUE   Description
    --flag                Description
    --debug               Enable debug logging
    -h, --help            Show this help message

Examples:
    $SCRIPT_NAME --option-name foo
    $SCRIPT_NAME --flag --debug

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --option-name)
                OPTION_VAR="$2"
                shift 2
                ;;
            --flag)
                FLAG_VAR="true"
                shift
                ;;
            --debug)
                DEBUG_MODE="true"
                export DEBUG_MODE
                shift
                ;;
            -h|--help)
                show_usage
                exit $SUCCESS
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "Unknown option: $1" $ERR_INVALID_ARGS
                ;;
            *)
                break
                ;;
        esac
    done
}

# ============================================================================
# CORE FUNCTIONS
# ============================================================================
# Business logic here

# ============================================================================
# MAIN FUNCTION
# ============================================================================
main() {
    parse_arguments "$@"
    validate_dependencies
    validate_arguments
    # Main logic
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================
main "$@"
```

## Library Files (Sourced, Not Executed)

Library files like `consensus-share.sh` follow different rules:

- **No** `set -euo pipefail` (the caller sets this)
- **No** `main "$@"` entry point
- Guard against re-sourcing with `if [[ -z "${VAR:-}" ]]` checks
- Set `SCRIPT_DIR` and `PROJECT_ROOT` only if not already set by the caller

```bash
#!/bin/bash
# ============================================================================
# SHARED FUNCTIONS LIBRARY
# ============================================================================
# Description of what this library provides
# ============================================================================

# Only set if not already set by calling script
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# Source dependencies
source "$PROJECT_ROOT/scripts/shared/logger.sh"
source "$PROJECT_ROOT/scripts/shared/utils.sh"

# Functions follow...
```

## Section Headers

Use `# ====` banners to group functions into logical sections. The standard order:

1. **CONSTANTS** — `readonly` values, exit codes, default values
2. **SOURCE SHARED FUNCTIONS** — `source` statements
3. **GLOBAL VARIABLES** — mutable state with env-var defaults
4. **VALIDATION FUNCTIONS** — `validate_arguments`, `validate_environment`
5. **ARGUMENT PARSING** — `show_usage`, `parse_arguments`
6. **CORE FUNCTIONS** — business logic
7. **MAIN FUNCTION** — `main()`
8. **SCRIPT ENTRY POINT** — `main "$@"`

```bash
# ============================================================================
# SECTION NAME
# ============================================================================
```

## Function Rules

- Max **50 lines** per function; single responsibility
- Group with `# ====` section headers
- Categories: Constants, Logging, Utility, Validation, Input, Core Logic, Output

## Naming

| Type | Convention | Example |
|------|-----------|---------|
| Functions | verb_noun (snake_case) | `validate_arguments`, `execute_deploy` |
| Constants | UPPER_SNAKE + `readonly` | `readonly MAX_RETRIES=3` |
| Local vars | lower_snake + `local` | `local file_path="$1"` |
| Globals | UPPER_SNAKE | `DEBUG_MODE="${DEBUG_MODE:-false}"` |
| Files | kebab-case | `consensus-deploy.sh` |
| Exit codes | `ERR_` prefix + `readonly` | `readonly ERR_INVALID_ARGS=2` |
| Skip flags | `SKIP_` prefix, `--skip-` CLI | `SKIP_COMPILE="${SKIP_COMPILE:-false}"` |

## Error Handling

- `die()` for error + exit (not `log_error` + `return`)
- Named exit codes: `SUCCESS=0`, `ERR_GENERAL=1`, `ERR_INVALID_ARGS=2`, `ERR_MISSING_DEPS=3`, `ERR_FILE_NOT_FOUND=4`
- Always check: `cd "$dir" || die "Cannot access directory"`
- Cleanup via `trap "rm -rf '$temp_dir'" EXIT`
- Use `set +e` / `set -e` blocks when capturing exit codes from commands that may fail

```bash
set +e
make deploy 2>&1 | while IFS= read -r line; do
    echo "$line"
done
local exit_code=${PIPESTATUS[0]}
set -e

if [[ "$exit_code" -ne 0 ]]; then
    die "Deploy failed"
fi
```

## Variables

- Always quote: `"$var"`, `"${files[@]}"`
- Defaults from env vars: `GROUP="${GROUP:-default}"`
- Required params: `"${1:?Error: missing}"`
- Avoid subshell variable loss: `while read < file` not `cat | while`
- Preserve caller values: `CONSENSUS_SOURCE="${CONSENSUS_SOURCE:-}"`

## PROJECT_ROOT Detection

Support both regular repos and git worktrees:

```bash
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Prefer git root when available (handles worktrees)
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -n "$GIT_ROOT" ]]; then
    PROJECT_ROOT="$GIT_ROOT"
fi
export PROJECT_ROOT
```

When called from other scripts (library pattern):

```bash
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
else
    readonly PROJECT_ROOT="${PROJECT_ROOT}"
fi
```

## Standard Patterns

### Argument Parsing

`while`/`case` loop with `--help`, `--debug`, `--` separator, and unknown option handling:

```bash
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --valued-option)
                VAR="$2"
                shift 2
                ;;
            --boolean-flag)
                FLAG="true"
                shift
                ;;
            --debug)
                DEBUG_MODE="true"
                export DEBUG_MODE
                shift
                ;;
            -h|--help)
                show_usage
                exit $SUCCESS
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "Unknown option: $1" $ERR_INVALID_ARGS
                ;;
            *)
                break
                ;;
        esac
    done
}
```

### Skip-Flag Pattern

Scripts use `--skip-*` flags paired with `SKIP_*` env vars for orchestration:

```bash
# Global declarations with env-var fallback
SKIP_COMPILE="${SKIP_COMPILE:-false}"
SKIP_VERIFICATION="${SKIP_VERIFICATION:-false}"

# In parse_arguments
--skip-compile)
    SKIP_COMPILE="true"
    shift
    ;;

# In main logic
if [[ "$SKIP_COMPILE" == "false" ]]; then
    compile_contracts
fi
```

### show_usage Pattern

Mirror the header documentation, reference `$SCRIPT_NAME`, use heredoc:

```bash
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Short description.

Options:
    --option VALUE   Description (default: $DEFAULT_VALUE)
    --debug          Enable debug logging
    -h, --help       Show this help message

Examples:
    $SCRIPT_NAME --option foo
    $SCRIPT_NAME --option bar --debug

EOF
}
```

### Calling Mode Pattern

Scripts support both standalone (interactive) and called-from-parent modes:

```bash
# Preserve existing environment variables if already set by calling script
CONSENSUS_SOURCE="${CONSENSUS_SOURCE:-}"
SELECTED_REF="${SELECTED_REF:-}"
TEMP_DIR="${TEMP_DIR:-}"

# In main(), check if already set
if [[ -z "${CONSENSUS_SOURCE:-}" ]]; then
    log_info "Getting consensus source..."
    consensus_source  # interactive prompt
else
    log_info "Using provided consensus source: $CONSENSUS_SOURCE"
fi
```

### Preflight Check Pattern

Collect all results before failing (unlike deploy scripts that die on first error):

```bash
PREFLIGHT_PASSES=()
PREFLIGHT_FAILURES=()
PREFLIGHT_WARNINGS=()

record_pass()  { PREFLIGHT_PASSES+=("$1"); }
record_fail()  { PREFLIGHT_FAILURES+=("${1}|${2:-}"); }
record_warn()  { PREFLIGHT_WARNINGS+=("${1}|${2:-}"); }

# Run all checks, then print summary and exit
print_summary() {
    # Display all results
    if [[ ${#PREFLIGHT_FAILURES[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}
```

### Make Command Builder Pattern

Build commands incrementally for external tool invocation:

```bash
local make_cmd="make deploy"
make_cmd="$make_cmd SET=$SUBNET"
make_cmd="$make_cmd NETWORK=$NETWORK"
make_cmd="$make_cmd SKIP_SANITY_VERIFICATION=$SKIP_VERIFY"

log_debug "Executing: $make_cmd"

if $make_cmd; then
    log_success "Deploy completed!"
    return $SUCCESS
else
    log_error "Deploy failed!"
    return $ERR_GENERAL
fi
```

## Shared Functions

Source from `$PROJECT_ROOT/scripts/shared/`:

| File | Functions |
|------|-----------|
| `logger.sh` | `log_info`, `log_error`, `log_warning`, `log_debug`, `log_success` |
| `utils.sh` | `die`, `cleanup`, `validate_dependencies` |
| `interactive.sh` | `prompt_yes_no`, `show_menu` |

Domain-specific shared functions live alongside their scripts (e.g., `consensus-share.sh`, `consensus_source.sh`).

## JSON Processing

- Use `jq` for all JSON operations
- Validate schema before processing:

```bash
if ! jq -e 'type == "array"' "$file" >/dev/null 2>&1; then
    die "Not a JSON array: $file"
fi

local count
count=$(jq 'length' "$file" 2>/dev/null) || count=0
```

## Logging Configuration

- `DEBUG_MODE="${DEBUG_MODE:-false}"` declared as a global
- `--debug` flag sets `DEBUG_MODE="true"` and exports it
- Use structured log messages with configuration summaries:

```bash
log_info "Starting process...
Configuration:
  Subnet: $SUBNET
  Network: $NETWORK
  Skip verification: $SKIP_VERIFY"
```

## Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| Inline logic at top level | Wrap in functions, call from `main()` |
| `log_error` + `return 1` for fatal errors | `die "message" $ERR_CODE` |
| `cat file \| while read` | `while read < file` |
| Unquoted variables | `"$var"` always |
| Hardcoded paths | Derive from `SCRIPT_DIR` / `PROJECT_ROOT` |
| `exit 1` without context | `die "Descriptive error" $ERR_CODE` |
| `set -e` with piped commands | `set +e` block + `PIPESTATUS` |
| Re-sourcing without guards | `if [[ -z "${VAR:-}" ]]` guards in libraries |
| Associative arrays | Parallel arrays for portability |
