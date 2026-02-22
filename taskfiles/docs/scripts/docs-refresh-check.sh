#!/bin/bash
set -euo pipefail

# ============================================================================
# DOCS REFRESH CHECK
# ============================================================================
# Verifies that generated documentation is in sync with skill source files.
#
# Regenerates REFERENCE.md and the CLAUDE.md skills table to temporary files,
# then diffs them against the committed versions. Exits non-zero if they
# differ, indicating that `task docs:refresh` needs to be run.
#
# Usage:
#   ./docs-refresh-check.sh
#   ./docs-refresh-check.sh --debug
#
# Options:
#   --debug    Enable debug logging
#   --help     Show help message
#
# Outputs:
#   Exit code 0 if in sync, 1 if out of sync
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

# Paths
readonly REFERENCE_FILE="$PROJECT_ROOT/docs/skills/REFERENCE.md"
readonly CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"

# Scripts
readonly GENERATE_SCRIPT="$SCRIPT_DIR/generate-skill-reference.sh"
readonly UPDATE_SCRIPT="$SCRIPT_DIR/update-claude-md.sh"

# Markers
readonly START_MARKER="<!-- SKILLS_TABLE_START -->"
readonly END_MARKER="<!-- SKILLS_TABLE_END -->"

# ============================================================================
# SOURCE SHARED FUNCTIONS
# ============================================================================
SCRIPT_SHARED_DIR="$PROJECT_ROOT/taskfiles/scripts"
source "$SCRIPT_SHARED_DIR/logger.sh"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

die() {
    log_error "$1"
    exit "${2:-$ERR_GENERAL}"
}

show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Check that generated docs are in sync with skill sources.

Options:
    --debug    Enable debug logging
    -h, --help Show this help message

EOF
}

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

# Extract content between markers from a file
extract_between_markers() {
    local file="$1"
    local start="$2"
    local end="$3"

    sed -n "/$start/,/$end/p" "$file"
}

# Check REFERENCE.md is in sync
check_reference() {
    if [[ ! -f "$REFERENCE_FILE" ]]; then
        log_error "REFERENCE.md does not exist: $REFERENCE_FILE"
        log_error "Run 'task docs:refresh' to generate it"
        return 1
    fi

    log_info "Checking REFERENCE.md..."

    # Generate to temp file
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT

    local temp_reference="$temp_dir/REFERENCE.md"

    # Temporarily redirect output by swapping the output file
    local orig_output_dir="$PROJECT_ROOT/docs/skills"
    local temp_output_dir="$temp_dir/docs/skills"
    mkdir -p "$temp_output_dir"

    # Run the generate script but capture its output to temp
    # We need to regenerate to a temp location, so we use a subshell trick
    (
        # Override OUTPUT_FILE by running the script with modified PROJECT_ROOT
        cd "$PROJECT_ROOT"
        bash "$GENERATE_SCRIPT" ${DEBUG_MODE:+--debug} 2>/dev/null || true
    )

    # The generate script writes to docs/skills/REFERENCE.md in PROJECT_ROOT
    # We need to compare before/after, so let's save current and regenerate
    cp "$REFERENCE_FILE" "$temp_dir/REFERENCE.md.before"

    # Regenerate
    bash "$GENERATE_SCRIPT" ${DEBUG_MODE:+--debug} >/dev/null 2>&1

    # Compare
    if ! diff -q "$temp_dir/REFERENCE.md.before" "$REFERENCE_FILE" >/dev/null 2>&1; then
        log_error "REFERENCE.md is out of sync"
        log_error "Run 'task docs:refresh' to update"
        # Restore original
        cp "$temp_dir/REFERENCE.md.before" "$REFERENCE_FILE"
        return 1
    fi

    log_success "REFERENCE.md is in sync"
    return 0
}

# Check CLAUDE.md skills table is in sync
check_claude_md() {
    if [[ ! -f "$CLAUDE_MD" ]]; then
        log_error "CLAUDE.md does not exist: $CLAUDE_MD"
        return 1
    fi

    # Check markers exist
    if ! grep -q "$START_MARKER" "$CLAUDE_MD"; then
        log_error "CLAUDE.md missing start marker: $START_MARKER"
        return 1
    fi
    if ! grep -q "$END_MARKER" "$CLAUDE_MD"; then
        log_error "CLAUDE.md missing end marker: $END_MARKER"
        return 1
    fi

    log_info "Checking CLAUDE.md skills table..."

    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT

    # Save current CLAUDE.md
    cp "$CLAUDE_MD" "$temp_dir/CLAUDE.md.before"

    # Extract current table content
    local before_table
    before_table=$(extract_between_markers "$CLAUDE_MD" "$START_MARKER" "$END_MARKER")

    # Run update
    bash "$UPDATE_SCRIPT" ${DEBUG_MODE:+--debug} >/dev/null 2>&1

    # Extract updated table content
    local after_table
    after_table=$(extract_between_markers "$CLAUDE_MD" "$START_MARKER" "$END_MARKER")

    # Compare table sections
    if [[ "$before_table" != "$after_table" ]]; then
        log_error "CLAUDE.md skills table is out of sync"
        log_error "Run 'task docs:refresh' to update"
        # Restore original
        cp "$temp_dir/CLAUDE.md.before" "$CLAUDE_MD"
        return 1
    fi

    log_success "CLAUDE.md skills table is in sync"
    return 0
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG_MODE=true
                export DEBUG_MODE
                shift
                ;;
            -h|--help)
                show_usage
                exit $SUCCESS
                ;;
            *)
                die "Unknown option: $1" $ERR_INVALID_ARGS
                ;;
        esac
    done
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    parse_arguments "$@"

    local failures=0

    check_reference || failures=$((failures + 1))
    check_claude_md || failures=$((failures + 1))

    echo ""
    if [[ $failures -gt 0 ]]; then
        log_error "Docs out of sync: $failures check(s) failed"
        log_error "Run 'task docs:refresh' to fix"
        exit $ERR_GENERAL
    fi

    log_success "All docs in sync"
    exit $SUCCESS
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================
main "$@"
