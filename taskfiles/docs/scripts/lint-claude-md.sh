#!/bin/bash
set -euo pipefail

# ============================================================================
# LINT CLAUDE.MD
# ============================================================================
# Validates quantifiable rules for CLAUDE.md structure and content.
#
# Checks:
#   - Line count warning (>120 lines)
#   - Directory tree characters (├ └ │) — ERROR
#   - Missing "Built with:" in first 15 lines — ERROR
#   - Missing SKILLS_TABLE markers — ERROR
#   - Banned headings (Getting Started, Installation, etc.) — ERROR
#
# Usage:
#   ./lint-claude-md.sh
#   ./lint-claude-md.sh --debug
#   ./lint-claude-md.sh --file /path/to/CLAUDE.md
#
# Options:
#   --file PATH   Path to CLAUDE.md (default: PROJECT_ROOT/CLAUDE.md)
#   --debug       Enable debug logging
#   --help        Show help message
#
# Outputs:
#   Exit code 0 if all checks pass, 1 if any ERROR check fails
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
readonly ERR_FILE_NOT_FOUND=4

# Thresholds
readonly MAX_LINE_COUNT=120
readonly BUILT_WITH_SCAN_LINES=15

# Markers
readonly START_MARKER="SKILLS_TABLE_START"
readonly END_MARKER="SKILLS_TABLE_END"

# Banned headings (regex alternation)
readonly BANNED_HEADINGS="^## (Customizing|Getting Started|Contributing|Installation)"

# ============================================================================
# SOURCE SHARED FUNCTIONS
# ============================================================================
SCRIPT_SHARED_DIR="$PROJECT_ROOT/taskfiles/scripts"
source "$SCRIPT_SHARED_DIR/logger.sh"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================
CLAUDE_MD_FILE="${PROJECT_ROOT}/CLAUDE.md"
DEBUG_MODE="${DEBUG_MODE:-false}"

ERROR_COUNT=0
WARNING_COUNT=0

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

die() {
    log_error "$1"
    exit "${2:-$ERR_GENERAL}"
}

record_error() {
    log_error "$1"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

record_warning() {
    log_warning "$1"
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Validate CLAUDE.md structure and content rules.

Options:
    --file PATH   Path to CLAUDE.md (default: PROJECT_ROOT/CLAUDE.md)
    --debug       Enable debug logging
    -h, --help    Show this help message

Checks:
    - Line count >$MAX_LINE_COUNT (WARNING)
    - Directory tree characters (ERROR)
    - Missing "Built with:" in first $BUILT_WITH_SCAN_LINES lines (ERROR)
    - Missing SKILLS_TABLE markers (ERROR)
    - Banned headings (ERROR)

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --file)
                CLAUDE_MD_FILE="$2"
                shift 2
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
# VALIDATION FUNCTIONS
# ============================================================================

validate_file_exists() {
    if [[ ! -f "$CLAUDE_MD_FILE" ]]; then
        die "CLAUDE.md not found: $CLAUDE_MD_FILE" $ERR_FILE_NOT_FOUND
    fi
    log_debug "Linting: $CLAUDE_MD_FILE"
}

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

check_line_count() {
    local line_count
    line_count=$(wc -l < "$CLAUDE_MD_FILE" | tr -d ' ')
    log_debug "Line count: $line_count (max: $MAX_LINE_COUNT)"

    if [[ "$line_count" -gt "$MAX_LINE_COUNT" ]]; then
        record_warning "Line count is $line_count (target: <=$MAX_LINE_COUNT). Consider moving content to docs/."
    else
        log_success "Line count: $line_count (<=$MAX_LINE_COUNT)"
    fi
}

check_directory_tree_chars() {
    local tree_lines
    tree_lines=$(grep -n '[├└│]' "$CLAUDE_MD_FILE" 2>/dev/null || true)

    if [[ -n "$tree_lines" ]]; then
        record_error "Directory tree characters found (use dirs-only format instead):"
        while IFS= read -r line; do
            log_error "  $line"
        done <<< "$tree_lines"
    else
        log_success "No directory tree characters"
    fi
}

check_built_with() {
    local head_content
    head_content=$(head -n "$BUILT_WITH_SCAN_LINES" "$CLAUDE_MD_FILE")

    if echo "$head_content" | grep -q "Built with:"; then
        log_success "\"Built with:\" found in first $BUILT_WITH_SCAN_LINES lines"
    else
        record_error "Missing \"Built with:\" declaration in first $BUILT_WITH_SCAN_LINES lines"
    fi
}

check_skills_table_markers() {
    local has_start has_end
    has_start=$(grep -c "$START_MARKER" "$CLAUDE_MD_FILE" 2>/dev/null || echo "0")
    has_end=$(grep -c "$END_MARKER" "$CLAUDE_MD_FILE" 2>/dev/null || echo "0")

    if [[ "$has_start" -eq 0 ]]; then
        record_error "Missing <!-- $START_MARKER --> marker"
    fi
    if [[ "$has_end" -eq 0 ]]; then
        record_error "Missing <!-- $END_MARKER --> marker"
    fi
    if [[ "$has_start" -gt 0 ]] && [[ "$has_end" -gt 0 ]]; then
        log_success "SKILLS_TABLE markers present"
    fi
}

check_banned_headings() {
    local banned_lines
    banned_lines=$(grep -nE "$BANNED_HEADINGS" "$CLAUDE_MD_FILE" 2>/dev/null || true)

    if [[ -n "$banned_lines" ]]; then
        record_error "Banned headings found (move to README.md or docs/):"
        while IFS= read -r line; do
            log_error "  $line"
        done <<< "$banned_lines"
    else
        log_success "No banned headings"
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    echo ""
    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        log_error "CLAUDE.md lint: $ERROR_COUNT error(s), $WARNING_COUNT warning(s)"
        return 1
    elif [[ "$WARNING_COUNT" -gt 0 ]]; then
        log_warning "CLAUDE.md lint: 0 errors, $WARNING_COUNT warning(s)"
        return 0
    else
        log_success "CLAUDE.md lint: all checks passed"
        return 0
    fi
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    parse_arguments "$@"
    validate_file_exists

    log_info "Linting CLAUDE.md..."

    check_line_count
    check_directory_tree_chars
    check_built_with
    check_skills_table_markers
    check_banned_headings

    print_summary
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================
main "$@"
