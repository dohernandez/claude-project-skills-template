#!/bin/bash
set -euo pipefail

# ============================================================================
# GENERATE SKILL REFERENCE
# ============================================================================
# Deterministically generates docs/skills/REFERENCE.md from skill.yaml files.
#
# Reads all .claude/skills/*/skill.yaml files, extracts metadata, and produces
# a structured reference document grouped by skill kind.
#
# Usage:
#   ./generate-skill-reference.sh
#   ./generate-skill-reference.sh --debug
#
# Options:
#   --debug    Enable debug logging
#   --help     Show help message
#
# Outputs:
#   - docs/skills/REFERENCE.md (generated)
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

# Output paths
readonly OUTPUT_DIR="$PROJECT_ROOT/docs/skills"
readonly OUTPUT_FILE="$OUTPUT_DIR/REFERENCE.md"

# Skills directory
readonly SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

# Kind display order
readonly KIND_ORDER="action workflow methodology gate helper utility meta integration"

# ============================================================================
# SOURCE SHARED FUNCTIONS
# ============================================================================
SCRIPT_SHARED_DIR="$PROJECT_ROOT/taskfiles/scripts"
source "$SCRIPT_SHARED_DIR/logger.sh"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

# Parallel arrays for skill data
SKILL_NAMES=()
SKILL_KINDS=()
SKILL_DESCRIPTIONS=()
SKILL_VERSIONS=()
SKILL_SEVERITIES=()
SKILL_TAGS=()
SKILL_PURPOSES=()
SKILL_WHEN_TO_USE=()
SKILL_USER_INVOCABLE=()
SKILL_OWNS=()
SKILL_ANTI_PATTERNS=()
SKILL_SHARP_EDGES=()

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

Generate docs/skills/REFERENCE.md from skill.yaml files.

Options:
    --debug    Enable debug logging
    -h, --help Show this help message

EOF
}

# Check if yq is available
has_yq() {
    command -v yq >/dev/null 2>&1
}

# ============================================================================
# YAML PARSING FUNCTIONS
# ============================================================================

# Read a YAML field using yq with fallback to basic grep
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

# Read a YAML array field as newline-separated values
yaml_array() {
    local file="$1"
    local field="$2"

    if has_yq; then
        yq ".${field}[]? // empty" "$file" 2>/dev/null || echo ""
    else
        # Basic parsing: look for lines starting with "  - " after the field
        local in_field=false
        while IFS= read -r line; do
            local trimmed
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$line" =~ ^${field}: ]]; then
                in_field=true
                continue
            fi

            if [[ "$in_field" == true ]]; then
                if [[ "$trimmed" =~ ^-[[:space:]]+(.*) ]]; then
                    local val="${BASH_REMATCH[1]}"
                    echo "$val" | sed 's/^"//;s/"$//'
                elif [[ -n "$trimmed" ]] && ! [[ "$trimmed" =~ ^- ]]; then
                    break
                fi
            fi
        done < "$file"
    fi
}

# Read a multi-line YAML string field (block scalar)
yaml_block() {
    local file="$1"
    local field="$2"

    if has_yq; then
        local val
        val=$(yq ".$field // \"\"" "$file" 2>/dev/null || echo "")
        if [[ "$val" == "null" ]] || [[ -z "$val" ]]; then
            echo ""
        else
            echo "$val"
        fi
    else
        yaml_field "$file" "$field" ""
    fi
}

# Read sharp-edges.yaml edge IDs and descriptions
# Sets EDGE_IDS and EDGE_DESCRIPTIONS arrays
read_sharp_edges() {
    local file="$1"

    local edges=""
    if has_yq; then
        local count
        count=$(yq '.edges | length' "$file" 2>/dev/null || echo "0")
        if [[ "$count" == "null" ]]; then
            count=0
        fi

        for ((i = 0; i < count; i++)); do
            local eid edesc
            eid=$(yq ".edges[$i].id // \"\"" "$file" 2>/dev/null)
            edesc=$(yq ".edges[$i].description // \"\"" "$file" 2>/dev/null)
            if [[ -n "$eid" ]] && [[ "$eid" != "null" ]]; then
                if [[ -n "$edges" ]]; then
                    edges="${edges}|||"
                fi
                edges="${edges}${eid}: ${edesc}"
            fi
        done
    else
        local in_edges=false
        local current_id=""
        local current_desc=""

        while IFS= read -r line; do
            local trimmed
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$trimmed" == "edges:" ]]; then
                in_edges=true
                continue
            fi

            if [[ "$in_edges" == true ]]; then
                if [[ "$trimmed" =~ ^-[[:space:]]*id:[[:space:]]*(.*) ]]; then
                    if [[ -n "$current_id" ]]; then
                        if [[ -n "$edges" ]]; then
                            edges="${edges}|||"
                        fi
                        edges="${edges}${current_id}: ${current_desc}"
                    fi
                    current_id="${BASH_REMATCH[1]}"
                    current_id=$(echo "$current_id" | sed 's/^"//;s/"$//')
                    current_desc=""
                elif [[ "$trimmed" =~ ^description:[[:space:]]*(.*) ]]; then
                    current_desc="${BASH_REMATCH[1]}"
                    current_desc=$(echo "$current_desc" | sed 's/^"//;s/"$//')
                fi
            fi
        done < "$file"

        if [[ -n "$current_id" ]]; then
            if [[ -n "$edges" ]]; then
                edges="${edges}|||"
            fi
            edges="${edges}${current_id}: ${current_desc}"
        fi
    fi

    echo "$edges"
}

# Read anti-pattern IDs and descriptions from skill.yaml
read_anti_patterns() {
    local file="$1"

    local patterns=""
    if has_yq; then
        local count
        count=$(yq '.anti_patterns | length' "$file" 2>/dev/null || echo "0")
        if [[ "$count" == "null" ]]; then
            count=0
        fi

        for ((i = 0; i < count; i++)); do
            local pid pdesc
            pid=$(yq ".anti_patterns[$i].id // \"\"" "$file" 2>/dev/null)
            pdesc=$(yq ".anti_patterns[$i].description // \"\"" "$file" 2>/dev/null)
            if [[ -n "$pid" ]] && [[ "$pid" != "null" ]]; then
                if [[ -n "$patterns" ]]; then
                    patterns="${patterns}|||"
                fi
                patterns="${patterns}${pid}: ${pdesc}"
            fi
        done
    else
        local in_anti=false
        local current_id=""
        local current_desc=""

        while IFS= read -r line; do
            local trimmed
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$trimmed" == "anti_patterns:" ]]; then
                in_anti=true
                continue
            fi

            if [[ "$in_anti" == true ]]; then
                if [[ "$trimmed" =~ ^-[[:space:]]*id:[[:space:]]*(.*) ]]; then
                    if [[ -n "$current_id" ]]; then
                        if [[ -n "$patterns" ]]; then
                            patterns="${patterns}|||"
                        fi
                        patterns="${patterns}${current_id}: ${current_desc}"
                    fi
                    current_id="${BASH_REMATCH[1]}"
                    current_id=$(echo "$current_id" | sed 's/^"//;s/"$//')
                    current_desc=""
                elif [[ "$trimmed" =~ ^description:[[:space:]]*(.*) ]]; then
                    current_desc="${BASH_REMATCH[1]}"
                    current_desc=$(echo "$current_desc" | sed 's/^"//;s/"$//')
                fi
            fi
        done < "$file"

        if [[ -n "$current_id" ]]; then
            if [[ -n "$patterns" ]]; then
                patterns="${patterns}|||"
            fi
            patterns="${patterns}${current_id}: ${current_desc}"
        fi
    fi

    echo "$patterns"
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
        val=$(echo "$frontmatter" | grep -E '^user-invocable:' | sed 's/^user-invocable:[[:space:]]*//' | sed 's/^"//;s/"$//' || echo "false")
        if [[ -z "$val" ]]; then
            echo "false"
        else
            echo "$val"
        fi
    fi
}

# ============================================================================
# DATA LOADING
# ============================================================================

# Load all skill data into parallel arrays
load_all_skills() {
    if [[ ! -d "$SKILLS_DIR" ]]; then
        die "Skills directory not found: $SKILLS_DIR"
    fi

    for skill_dir in "$SKILLS_DIR"/*/; do
        [[ ! -d "$skill_dir" ]] && continue

        local skill_yaml="$skill_dir/skill.yaml"
        [[ ! -f "$skill_yaml" ]] && continue

        local name
        name=$(basename "$skill_dir")
        log_debug "Loading skill: $name"

        local kind description version severity tags purpose when_to_use
        kind=$(yaml_field "$skill_yaml" "kind" "unknown")
        description=$(yaml_field "$skill_yaml" "description" "" | tr '\n' ' ' | sed 's/  */ /g;s/^ *//;s/ *$//')
        version=$(yaml_field "$skill_yaml" "version" "")
        severity=$(yaml_field "$skill_yaml" "severity" "")
        tags=$(yaml_array "$skill_yaml" "tags" | tr '\n' ', ' | sed 's/, *$//')
        purpose=$(yaml_block "$skill_yaml" "purpose")
        when_to_use=$(yaml_field "$skill_yaml" "when_to_use" "" | tr '\n' ' ' | sed 's/  */ /g;s/^ *//;s/ *$//')

        local user_invocable
        user_invocable=$(read_user_invocable "$skill_dir")

        local owns
        owns=$(yaml_array "$skill_yaml" "owns" | tr '\n' '|||')

        local anti_patterns=""
        anti_patterns=$(read_anti_patterns "$skill_yaml")

        local sharp_edges=""
        local edges_file="$skill_dir/sharp-edges.yaml"
        if [[ -f "$edges_file" ]]; then
            sharp_edges=$(read_sharp_edges "$edges_file")
        fi

        SKILL_NAMES+=("$name")
        SKILL_KINDS+=("$kind")
        SKILL_DESCRIPTIONS+=("$description")
        SKILL_VERSIONS+=("$version")
        SKILL_SEVERITIES+=("$severity")
        SKILL_TAGS+=("$tags")
        SKILL_PURPOSES+=("$purpose")
        SKILL_WHEN_TO_USE+=("$when_to_use")
        SKILL_USER_INVOCABLE+=("$user_invocable")
        SKILL_OWNS+=("$owns")
        SKILL_ANTI_PATTERNS+=("$anti_patterns")
        SKILL_SHARP_EDGES+=("$sharp_edges")
    done

    log_debug "Loaded ${#SKILL_NAMES[@]} skills"
}

# ============================================================================
# GENERATION FUNCTIONS
# ============================================================================

# Get display label for a kind
get_kind_label() {
    local kind="$1"
    case "$kind" in
        action)       echo "Actions" ;;
        workflow)      echo "Workflows" ;;
        methodology)   echo "Methodologies" ;;
        gate)          echo "Gates" ;;
        helper)        echo "Helpers" ;;
        utility)       echo "Utilities" ;;
        meta)          echo "Meta" ;;
        integration)   echo "Integrations" ;;
        *)             echo "Other ($kind)" ;;
    esac
}

# Get kind description
get_kind_description() {
    local kind="$1"
    case "$kind" in
        action)       echo "Single-purpose automation skills" ;;
        workflow)      echo "Multi-step development lifecycle skills" ;;
        methodology)   echo "Structured approach and process skills" ;;
        gate)          echo "Pre-requisite checker skills" ;;
        helper)        echo "Utility skills (no Stop hook required)" ;;
        utility)       echo "Small operational helpers" ;;
        meta)          echo "Skills for managing other skills" ;;
        integration)   echo "External service connector skills" ;;
        *)             echo "Uncategorized skills" ;;
    esac
}

# Get the "when to use" text for a skill
get_when_to_use() {
    local idx="$1"
    local when="${SKILL_WHEN_TO_USE[$idx]}"

    # Use when_to_use field if available
    if [[ -n "$when" ]]; then
        echo "$when"
        return
    fi

    # Fall back to description
    echo "${SKILL_DESCRIPTIONS[$idx]}"
}

# Get indices for skills of a given kind, sorted by name
get_skills_by_kind() {
    local kind="$1"
    local indices=()

    for ((i = 0; i < ${#SKILL_NAMES[@]}; i++)); do
        if [[ "${SKILL_KINDS[$i]}" == "$kind" ]]; then
            indices+=("$i")
        fi
    done

    # Sort by name
    local sorted=()
    for idx in "${indices[@]}"; do
        sorted+=("${SKILL_NAMES[$idx]}:$idx")
    done

    # Shell sort by name
    IFS=$'\n' sorted=($(sort <<< "${sorted[*]}")); unset IFS

    for entry in "${sorted[@]}"; do
        echo "${entry##*:}"
    done
}

# Emit the header section
emit_header() {
    cat << 'HEADER'
# Skills Reference

> Auto-generated from `.claude/skills/*/skill.yaml` files.
> Do not edit manually — run `task claude:skills-reference` to regenerate.

HEADER
}

# Emit the skill pattern section (canonical files + kinds)
emit_skill_pattern() {
    cat << 'PATTERN'
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

PATTERN
}

# Emit the overview table
emit_overview_table() {
    echo "## Overview"
    echo ""
    echo "| Skill | Kind | Description | Invocable |"
    echo "|-------|------|-------------|-----------|"

    # Emit in kind order
    for kind in $KIND_ORDER; do
        local indices
        indices=$(get_skills_by_kind "$kind")
        [[ -z "$indices" ]] && continue

        while IFS= read -r idx; do
            local name="${SKILL_NAMES[$idx]}"
            local desc="${SKILL_DESCRIPTIONS[$idx]}"
            local invocable="${SKILL_USER_INVOCABLE[$idx]}"
            local inv_display="no"
            if [[ "$invocable" == "true" ]]; then
                inv_display="yes"
            fi
            # Truncate description for table
            if [[ ${#desc} -gt 80 ]]; then
                desc="${desc:0:77}..."
            fi
            echo "| \`$name\` | $kind | $desc | $inv_display |"
        done <<< "$indices"
    done

    echo ""
}

# Emit a single skill detail section
emit_skill_detail() {
    local idx="$1"
    local name="${SKILL_NAMES[$idx]}"
    local kind="${SKILL_KINDS[$idx]}"
    local desc="${SKILL_DESCRIPTIONS[$idx]}"
    local version="${SKILL_VERSIONS[$idx]}"
    local severity="${SKILL_SEVERITIES[$idx]}"
    local tags="${SKILL_TAGS[$idx]}"
    local purpose="${SKILL_PURPOSES[$idx]}"
    local invocable="${SKILL_USER_INVOCABLE[$idx]}"
    local owns="${SKILL_OWNS[$idx]}"
    local anti_patterns="${SKILL_ANTI_PATTERNS[$idx]}"
    local sharp_edges="${SKILL_SHARP_EDGES[$idx]}"

    echo "### \`$name\`"
    echo ""

    # Metadata line
    local meta_parts=()
    meta_parts+=("**Kind:** $kind")
    if [[ -n "$version" ]]; then
        meta_parts+=("**Version:** $version")
    fi
    if [[ -n "$severity" ]]; then
        meta_parts+=("**Severity:** $severity")
    fi
    if [[ "$invocable" == "true" ]]; then
        meta_parts+=("**Invocable:** \`/$name\`")
    fi

    local meta_line=""
    for part in "${meta_parts[@]}"; do
        if [[ -n "$meta_line" ]]; then
            meta_line="${meta_line} | "
        fi
        meta_line="${meta_line}${part}"
    done
    echo "$meta_line"
    echo ""

    # Description
    echo "$desc"
    echo ""

    # When to use
    local when
    when=$(get_when_to_use "$idx")
    if [[ -n "$when" ]] && [[ "$when" != "$desc" ]]; then
        echo "**When to use:** $when"
        echo ""
    fi

    # Tags
    if [[ -n "$tags" ]]; then
        echo "**Tags:** $tags"
        echo ""
    fi

    # Owns
    if [[ -n "$owns" ]]; then
        echo "**Owns:**"
        local IFS_BAK="$IFS"
        IFS='|||'
        read -ra owns_arr <<< "$owns"
        IFS="$IFS_BAK"
        for own in "${owns_arr[@]}"; do
            own=$(echo "$own" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$own" ]]; then
                echo "- $own"
            fi
        done
        echo ""
    fi

    # Anti-patterns
    if [[ -n "$anti_patterns" ]]; then
        echo "**Anti-patterns:**"
        local IFS_BAK="$IFS"
        IFS='|||'
        read -ra ap_arr <<< "$anti_patterns"
        IFS="$IFS_BAK"
        for ap in "${ap_arr[@]}"; do
            ap=$(echo "$ap" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$ap" ]]; then
                echo "- $ap"
            fi
        done
        echo ""
    fi

    # Sharp edges
    if [[ -n "$sharp_edges" ]]; then
        echo "**Sharp edges:**"
        local IFS_BAK="$IFS"
        IFS='|||'
        read -ra se_arr <<< "$sharp_edges"
        IFS="$IFS_BAK"
        for se in "${se_arr[@]}"; do
            se=$(echo "$se" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$se" ]]; then
                echo "- $se"
            fi
        done
        echo ""
    fi
}

# Emit all skill details grouped by kind
emit_skill_details() {
    echo "## Skill Details"
    echo ""

    for kind in $KIND_ORDER; do
        local indices
        indices=$(get_skills_by_kind "$kind")
        [[ -z "$indices" ]] && continue

        local label
        label=$(get_kind_label "$kind")
        local kind_desc
        kind_desc=$(get_kind_description "$kind")

        echo "---"
        echo ""
        echo "## $label"
        echo ""
        echo "> $kind_desc"
        echo ""

        while IFS= read -r idx; do
            emit_skill_detail "$idx"
        done <<< "$indices"
    done
}

# Emit footer
emit_footer() {
    echo "---"
    echo ""
    echo "*Generated by \`task claude:skills-reference\`*"
}

# Generate the full REFERENCE.md
generate_reference() {
    mkdir -p "$OUTPUT_DIR"

    log_info "Generating $OUTPUT_FILE"

    {
        emit_header
        emit_skill_pattern
        emit_overview_table
        emit_skill_details
        emit_footer
    } > "$OUTPUT_FILE"

    log_success "Generated $OUTPUT_FILE (${#SKILL_NAMES[@]} skills)"
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

    load_all_skills

    if [[ ${#SKILL_NAMES[@]} -eq 0 ]]; then
        die "No skills found in $SKILLS_DIR"
    fi

    generate_reference
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================
main "$@"
