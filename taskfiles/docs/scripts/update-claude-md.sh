#!/bin/bash
set -euo pipefail

# ============================================================================
# UPDATE CLAUDE.MD
# ============================================================================
# Updates the skills table in CLAUDE.md between HTML marker comments.
#
# Reads all .claude/skills/*/skill.yaml files and generates a markdown table
# that replaces content between <!-- SKILLS_TABLE_START --> and
# <!-- SKILLS_TABLE_END --> markers in CLAUDE.md.
#
# Usage:
#   ./update-claude-md.sh
#   ./update-claude-md.sh --debug
#
# Options:
#   --debug    Enable debug logging
#   --help     Show help message
#
# Outputs:
#   - CLAUDE.md (updated between markers)
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
readonly CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
readonly SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

# Markers
readonly START_MARKER="<!-- SKILLS_TABLE_START -->"
readonly END_MARKER="<!-- SKILLS_TABLE_END -->"

# Kind display order
readonly KIND_ORDER="action workflow methodology gate helper utility meta integration"

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

Update the skills table in CLAUDE.md between marker comments.

Options:
    --debug    Enable debug logging
    -h, --help Show this help message

EOF
}

# Check if yq is available
has_yq() {
    command -v yq >/dev/null 2>&1
}

# Read a YAML field
yaml_field() {
    local file="$1"
    local field="$2"
    local default="${3:-}"

    if has_yq; then
        local val
        val=$(yq ".$field // \"\"" "$file" 2>/dev/null || echo "")
        if [[ -z "$val" ]] || [[ "$val" == "null" ]]; then
            echo "$default"
        else
            echo "$val"
        fi
    else
        local val
        val=$(grep -E "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//;s/"$//' || echo "")
        if [[ -z "$val" ]]; then
            echo "$default"
        else
            echo "$val"
        fi
    fi
}

# Read user-invocable from SKILL.md frontmatter
read_user_invocable() {
    local skill_dir="$1"
    local skillmd="$skill_dir/SKILL.md"

    if [[ ! -f "$skillmd" ]]; then
        echo "false"
        return
    fi

    local frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$skillmd" | sed '1d;$d')

    if [[ -z "$frontmatter" ]]; then
        echo "false"
        return
    fi

    if has_yq; then
        local val
        val=$(echo "$frontmatter" | yq '.["user-invocable"] // false' 2>/dev/null || echo "false")
        echo "$val"
    else
        local val
        val=$(echo "$frontmatter" | grep -E '^user-invocable:' | sed 's/^user-invocable:[[:space:]]*//' || echo "false")
        if [[ -z "$val" ]]; then
            echo "false"
        else
            echo "$val"
        fi
    fi
}

# ============================================================================
# TABLE GENERATION
# ============================================================================

# Parallel arrays for skills
TABLE_NAMES=()
TABLE_KINDS=()
TABLE_DESCS=()
TABLE_INVOCABLE=()

# Load skill data for table
load_skills_for_table() {
    if [[ ! -d "$SKILLS_DIR" ]]; then
        die "Skills directory not found: $SKILLS_DIR"
    fi

    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ ! -d "$skill_dir" ]] && continue

        local skill_yaml="$skill_dir/skill.yaml"
        [[ ! -f "$skill_yaml" ]] && continue

        local name
        name=$(basename "$skill_dir")

        local kind desc invocable
        kind=$(yaml_field "$skill_yaml" "kind" "unknown")
        desc=$(yaml_field "$skill_yaml" "description" "" | tr '\n' ' ' | sed 's/  */ /g;s/^ *//;s/ *$//')
        invocable=$(read_user_invocable "$skill_dir")

        TABLE_NAMES+=("$name")
        TABLE_KINDS+=("$kind")
        TABLE_DESCS+=("$desc")
        TABLE_INVOCABLE+=("$invocable")
    done
}

# Generate the table content (without markers)
generate_table() {
    echo "| Skill | Kind | Description |"
    echo "|-------|------|-------------|"

    # Emit in kind order
    for kind in $KIND_ORDER; do
        # Collect indices for this kind, sorted by name
        local entries=()

        for ((i = 0; i < ${#TABLE_NAMES[@]}; i++)); do
            if [[ "${TABLE_KINDS[$i]}" == "$kind" ]]; then
                entries+=("${TABLE_NAMES[$i]}:$i")
            fi
        done

        [[ ${#entries[@]} -eq 0 ]] && continue

        # Sort entries by name
        IFS=$'\n' entries=($(sort <<< "${entries[*]}")); unset IFS

        for entry in "${entries[@]}"; do
            local idx="${entry##*:}"
            local name="${TABLE_NAMES[$idx]}"
            local desc="${TABLE_DESCS[$idx]}"
            local invocable="${TABLE_INVOCABLE[$idx]}"

            # Truncate description for table readability
            if [[ ${#desc} -gt 80 ]]; then
                desc="${desc:0:77}..."
            fi

            # Format name - show as invocable command if applicable
            local name_display
            if [[ "$invocable" == "true" ]]; then
                name_display="\`$name\` (\`/$name\`)"
            else
                name_display="\`$name\`"
            fi

            echo "| $name_display | $kind | $desc |"
        done
    done

    # Handle any skills with unknown kinds
    for ((i = 0; i < ${#TABLE_NAMES[@]}; i++)); do
        local kind="${TABLE_KINDS[$i]}"
        local found=false
        for k in $KIND_ORDER; do
            if [[ "$k" == "$kind" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == false ]]; then
            local name="${TABLE_NAMES[$i]}"
            local desc="${TABLE_DESCS[$i]}"
            if [[ ${#desc} -gt 80 ]]; then
                desc="${desc:0:77}..."
            fi
            echo "| \`$name\` | $kind | $desc |"
        fi
    done
}

# ============================================================================
# CLAUDE.MD UPDATE
# ============================================================================

update_claude_md() {
    if [[ ! -f "$CLAUDE_MD" ]]; then
        die "CLAUDE.md not found at $CLAUDE_MD"
    fi

    # Check markers exist
    if ! grep -q "$START_MARKER" "$CLAUDE_MD"; then
        die "Start marker not found in CLAUDE.md: $START_MARKER"
    fi
    if ! grep -q "$END_MARKER" "$CLAUDE_MD"; then
        die "End marker not found in CLAUDE.md: $END_MARKER"
    fi

    log_info "Updating skills table in CLAUDE.md"

    # Generate the new table content
    local table_content
    table_content=$(generate_table)

    # Build the replacement file
    local temp_file
    temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT

    local in_markers=false

    while IFS= read -r line; do
        if [[ "$line" == "$START_MARKER" ]]; then
            echo "$line" >> "$temp_file"
            echo "" >> "$temp_file"
            echo "$table_content" >> "$temp_file"
            echo "" >> "$temp_file"
            in_markers=true
            continue
        fi

        if [[ "$line" == "$END_MARKER" ]]; then
            echo "$line" >> "$temp_file"
            in_markers=false
            continue
        fi

        if [[ "$in_markers" == false ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$CLAUDE_MD"

    # Replace the original file
    cp "$temp_file" "$CLAUDE_MD"

    log_success "Updated CLAUDE.md skills table (${#TABLE_NAMES[@]} skills)"
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

    load_skills_for_table

    if [[ ${#TABLE_NAMES[@]} -eq 0 ]]; then
        die "No skills found in $SKILLS_DIR"
    fi

    update_claude_md
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================
main "$@"
