#!/bin/bash
set -euo pipefail

# ============================================================================
# AUDIT SKILLS
# ============================================================================
# Semantic skill auditor: Enforces multi-YAML pattern compliance.
#
# This goes beyond check-skill-yaml (syntax + basic structure) to enforce
# semantic policies based on skill kind.
#
# Skill kinds and required files:
#   - gate/scaffolder/meta/frontend: SKILL.md, skill.yaml, collaboration.yaml, sharp-edges.yaml
#   - helper: SKILL.md, skill.yaml, collaboration.yaml (sharp-edges.yaml optional)
#
# Checks performed:
#   A) skill.yaml exists and declares kind
#   B) Required files present based on kind
#   C) Stop hook discipline (non-helpers must have Stop hook)
#   D) Collaboration reference integrity - all referenced skills exist
#   E) No patterns in SKILL.md (for non-helpers)
#   F) All skills documented in CLAUDE.md (discoverability)
#
# Upstream Skills Guide Constraints (STRICT):
#   G) Name: max 64 chars, lowercase + hyphens + underscores only, no reserved words
#   H) Description: non-empty, max 200 chars
#
# Best Practices Checks (WARN-ONLY):
#   I) SKILL.md conciseness: warn if >100 lines
#   J) Progressive disclosure: non-helpers should have rules in skill.yaml, not SKILL.md
#   K) Workflow checklist: gate/scaffolder should have procedure section in skill.yaml
#
# Usage:
#     ./audit-skills.sh
#     ./audit-skills.sh --strict
#     ./audit-skills.sh --debug
#
# INPUTS:
# Optional:
#   --strict         Fail on warnings
#   --debug          Enable debug logging
#   --help           Show usage information
#
# OUTPUTS:
#   Exit code 0 on success, 1 on failure
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

# Skill prefix (empty = no prefix required)
readonly SKILL_PREFIX=""

# Valid skill kinds
readonly VALID_KINDS="gate scaffolder helper frontend meta"

# Upstream Skills Guide Constraints
readonly NAME_MAX_LENGTH=64
readonly DESCRIPTION_MAX_LENGTH=200
readonly SKILLMD_MAX_LINES=100

# Reserved names (built-in commands)
readonly RESERVED_NAMES="help config settings permissions doctor clear compact context cost init listen login logout mcp memory model pr-comments resume review terminal-setup vim bug ide"

# Default values
STRICT_MODE=false

# Global arrays for errors and warnings
ERRORS=()
WARNINGS=()

# All skill names (for reference checking)
ALL_SKILLS=()

# Collaboration references (bash 3.2 compatibility: must be initialized globally)
COLLAB_SKILL_REFS=()

# ============================================================================
# SOURCE SHARED FUNCTIONS
# ============================================================================
SCRIPT_SHARED_DIR="$PROJECT_ROOT/taskfiles/scripts"

# Source the shared logger functions
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

Semantic skill auditor: Enforces multi-YAML pattern compliance.

Options:
    --strict    Fail on warnings
    --debug     Enable debug logging
    --help      Show this help message

Examples:
    # Default warn mode
    $SCRIPT_NAME

    # Strict mode (fail on any issue)
    $SCRIPT_NAME --strict

EOF
}

# Check if a value is in a space-separated list
is_in_list() {
    local value="$1"
    local list="$2"
    for item in $list; do
        if [[ "$item" == "$value" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if yq is available
has_yq() {
    command -v yq >/dev/null 2>&1
}

# ============================================================================
# YAML PARSING FUNCTIONS
# ============================================================================

# Parse YAML frontmatter from SKILL.md
# Sets: FM_NAME, FM_DESCRIPTION, FM_HOOKS_STOP (newline-separated commands)
parse_skillmd_frontmatter() {
    local skill_dir="$1"
    local skillmd="$skill_dir/SKILL.md"

    # Reset frontmatter variables
    FM_NAME=""
    FM_DESCRIPTION=""
    FM_HOOKS_STOP=""

    if [[ ! -f "$skillmd" ]]; then
        return 1
    fi

    # Extract frontmatter (between --- and ---)
    local frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$skillmd" | sed '1d;$d')

    if [[ -z "$frontmatter" ]]; then
        return 1
    fi

    if has_yq; then
        FM_NAME=$(echo "$frontmatter" | yq '.name // ""' 2>/dev/null || echo "")
        FM_DESCRIPTION=$(echo "$frontmatter" | yq '.description // ""' 2>/dev/null || echo "")
        # Get Stop hook commands
        FM_HOOKS_STOP=$(echo "$frontmatter" | yq '.hooks.Stop[].command // ""' 2>/dev/null || echo "")
    else
        # Basic parsing
        FM_NAME=$(echo "$frontmatter" | grep -E '^name:' | sed 's/^name:[[:space:]]*//' | sed 's/^"//;s/"$//')
        FM_DESCRIPTION=$(echo "$frontmatter" | grep -E '^description:' | sed 's/^description:[[:space:]]*//' | sed 's/^"//;s/"$//')
        # Basic Stop hook extraction (limited) - look for command in Stop block
        FM_HOOKS_STOP=$(echo "$frontmatter" | grep -A5 'Stop:' | grep 'command:' | sed 's/.*command:[[:space:]]*//' | sed 's/^"//;s/"$//')
    fi

    return 0
}

# Parse skill.yaml
# Sets: SKILL_YAML_NAME, SKILL_YAML_KIND, SKILL_YAML_DESCRIPTION
parse_skill_yaml() {
    local skill_dir="$1"
    local skill_yaml="$skill_dir/skill.yaml"

    # Reset variables
    SKILL_YAML_NAME=""
    SKILL_YAML_KIND=""
    SKILL_YAML_DESCRIPTION=""
    SKILL_YAML_HAS_PROCEDURE=false

    if [[ ! -f "$skill_yaml" ]]; then
        return 1
    fi

    if has_yq; then
        SKILL_YAML_NAME=$(yq '.name // ""' "$skill_yaml" 2>/dev/null || echo "")
        SKILL_YAML_KIND=$(yq '.kind // ""' "$skill_yaml" 2>/dev/null || echo "")
        SKILL_YAML_DESCRIPTION=$(yq '.description // ""' "$skill_yaml" 2>/dev/null || echo "")
        # Check for procedure sections
        local proc
        proc=$(yq '.procedure // .analysis_procedure // .scaffolding_procedure // ""' "$skill_yaml" 2>/dev/null || echo "")
        if [[ -n "$proc" ]] && [[ "$proc" != "null" ]]; then
            SKILL_YAML_HAS_PROCEDURE=true
        fi
    else
        # Basic parsing
        SKILL_YAML_NAME=$(grep -E '^name:' "$skill_yaml" | head -1 | sed 's/^name:[[:space:]]*//' | sed 's/^"//;s/"$//')
        SKILL_YAML_KIND=$(grep -E '^kind:' "$skill_yaml" | head -1 | sed 's/^kind:[[:space:]]*//' | sed 's/^"//;s/"$//')
        SKILL_YAML_DESCRIPTION=$(grep -E '^description:' "$skill_yaml" | head -1 | sed 's/^description:[[:space:]]*//' | sed 's/^"//;s/"$//')
        # Check for procedure sections
        if grep -qE '^(procedure|analysis_procedure|scaffolding_procedure):' "$skill_yaml"; then
            SKILL_YAML_HAS_PROCEDURE=true
        fi
    fi

    return 0
}

# Parse collaboration.yaml references
# Sets: COLLAB_SKILL_REFS (array of all referenced skill names)
parse_collaboration_yaml() {
    local skill_dir="$1"
    local collab_yaml="$skill_dir/collaboration.yaml"

    COLLAB_SKILL_REFS=()

    if [[ ! -f "$collab_yaml" ]]; then
        return 1
    fi

    if has_yq; then
        # Get dependencies[].skill
        local deps
        deps=$(yq '.dependencies[].skill // ""' "$collab_yaml" 2>/dev/null || echo "")
        while IFS= read -r ref; do
            if [[ -n "$ref" ]] && [[ "$ref" != "null" ]]; then
                COLLAB_SKILL_REFS+=("$ref")
            fi
        done <<< "$deps"

        # Get composition[].sequence[]
        local seqs
        seqs=$(yq '.composition[].sequence[]' "$collab_yaml" 2>/dev/null || echo "")
        while IFS= read -r ref; do
            if [[ -n "$ref" ]] && [[ "$ref" != "null" ]]; then
                COLLAB_SKILL_REFS+=("$ref")
            fi
        done <<< "$seqs"

        # Get triggers[].suggest
        local triggers
        triggers=$(yq '.triggers[].suggest // ""' "$collab_yaml" 2>/dev/null || echo "")
        while IFS= read -r ref; do
            if [[ -n "$ref" ]] && [[ "$ref" != "null" ]]; then
                COLLAB_SKILL_REFS+=("$ref")
            fi
        done <<< "$triggers"
    else
        # Basic parsing - look for skill: references
        while IFS= read -r line; do
            if [[ "$line" =~ skill:[[:space:]]*([a-zA-Z0-9_-]+) ]]; then
                COLLAB_SKILL_REFS+=("${BASH_REMATCH[1]}")
            fi
            if [[ "$line" =~ suggest:[[:space:]]*([a-zA-Z0-9_-]+) ]]; then
                COLLAB_SKILL_REFS+=("${BASH_REMATCH[1]}")
            fi
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*$ ]]; then
                # Could be a sequence item
                COLLAB_SKILL_REFS+=("${BASH_REMATCH[1]}")
            fi
        done < "$collab_yaml"
    fi

    return 0
}

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

# Get required files for a skill kind
get_required_files() {
    local kind="$1"
    case "$kind" in
        gate|scaffolder|meta|frontend)
            echo "SKILL.md skill.yaml collaboration.yaml sharp-edges.yaml"
            ;;
        helper)
            echo "SKILL.md skill.yaml collaboration.yaml"
            ;;
        *)
            echo "SKILL.md skill.yaml"
            ;;
    esac
}

# Check A) skill.yaml exists and declares kind
# Returns kind or empty string, adds to ERRORS
check_skill_kind() {
    local skill_dir="$1"
    local skill
    skill=$(basename "$skill_dir")

    if [[ ! -f "$skill_dir/skill.yaml" ]]; then
        ERRORS+=("$skill: Missing skill.yaml (required for all skills)")
        return 1
    fi

    parse_skill_yaml "$skill_dir"

    if [[ -z "$SKILL_YAML_NAME" ]]; then
        ERRORS+=("$skill: skill.yaml failed to parse or missing name")
        return 1
    fi

    # Check name matches folder
    if [[ "$SKILL_YAML_NAME" != "$skill" ]]; then
        ERRORS+=("$skill: skill.yaml name '$SKILL_YAML_NAME' must match folder name '$skill'")
    fi

    # Get kind
    if [[ -z "$SKILL_YAML_KIND" ]]; then
        ERRORS+=("$skill: skill.yaml missing 'kind' field")
        return 1
    fi

    if ! is_in_list "$SKILL_YAML_KIND" "$VALID_KINDS"; then
        ERRORS+=("$skill: skill.yaml kind '$SKILL_YAML_KIND' not valid (must be one of: $VALID_KINDS)")
        return 1
    fi

    echo "$SKILL_YAML_KIND"
    return 0
}

# Check B) Required files present based on kind
check_required_files() {
    local skill_dir="$1"
    local kind="$2"
    local skill
    skill=$(basename "$skill_dir")

    local required
    required=$(get_required_files "$kind")

    for filename in $required; do
        if [[ ! -f "$skill_dir/$filename" ]]; then
            ERRORS+=("$skill: Missing $filename (required for kind '$kind')")
        fi
    done
}

# Check C) Stop hook discipline
check_stop_hook_discipline() {
    local skill_dir="$1"
    local kind="$2"
    local skill
    skill=$(basename "$skill_dir")

    # Helpers don't need Stop hooks
    if [[ "$kind" == "helper" ]]; then
        return 0
    fi

    parse_skillmd_frontmatter "$skill_dir" || return 0

    if [[ -z "$FM_HOOKS_STOP" ]]; then
        ERRORS+=("$skill: No Stop hook defined (required for kind '$kind')")
        return 0
    fi

    local expected="task claude:validate-skill -- --skill $skill"
    if [[ "$FM_HOOKS_STOP" != *"$expected"* ]]; then
        ERRORS+=("$skill: Stop hook must call '$expected'")
    fi
}

# Check D) Collaboration reference integrity
check_collaboration_references() {
    local skill_dir="$1"
    local skill
    skill=$(basename "$skill_dir")

    if [[ ! -f "$skill_dir/collaboration.yaml" ]]; then
        return 0
    fi

    parse_collaboration_yaml "$skill_dir"

    # Bash 3.2 compatible: check length before iterating over array
    if [[ ${#COLLAB_SKILL_REFS[@]} -gt 0 ]]; then
        for ref in "${COLLAB_SKILL_REFS[@]}"; do
            local found=false
            for s in "${ALL_SKILLS[@]}"; do
                if [[ "$s" == "$ref" ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == false ]]; then
                ERRORS+=("$skill: collaboration.yaml references non-existent skill '$ref'")
            fi
        done
    fi
}

# Check E) No patterns in SKILL.md (for non-helpers)
check_no_patterns_in_skillmd() {
    local skill_dir="$1"
    local kind="$2"
    local skill
    skill=$(basename "$skill_dir")

    # Helpers are allowed to have patterns
    if [[ "$kind" == "helper" ]]; then
        return 0
    fi

    local skillmd="$skill_dir/SKILL.md"
    if [[ ! -f "$skillmd" ]]; then
        return 0
    fi

    local content
    content=$(cat "$skillmd")

    # Pattern indicators
    if echo "$content" | grep -qiE '##[[:space:]]*Patterns[[:space:]]*Enforced'; then
        WARNINGS+=("$skill: SKILL.md contains pattern list (move to skill.yaml, keep SKILL.md thin)")
        return 0
    fi

    if echo "$content" | grep -qiE '##[[:space:]]*Anti-?patterns'; then
        WARNINGS+=("$skill: SKILL.md contains pattern list (move to skill.yaml, keep SKILL.md thin)")
        return 0
    fi
}

# Check F) All skills documented in CLAUDE.md
check_documented_in_claudemd() {
    local claudemd="$PROJECT_ROOT/CLAUDE.md"

    if [[ ! -f "$claudemd" ]]; then
        return 0
    fi

    local content
    content=$(cat "$claudemd")

    for skill in "${ALL_SKILLS[@]}"; do
        if [[ "$content" != *"\`$skill\`"* ]]; then
            ERRORS+=("$skill: Not documented in CLAUDE.md (add to '### Skill kinds' section)")
        fi
    done
}

# Check G) Upstream name constraints
check_upstream_name_constraints() {
    local skill_dir="$1"
    local skill
    skill=$(basename "$skill_dir")

    parse_skillmd_frontmatter "$skill_dir" || return 0

    local name="$FM_NAME"

    # Check name length
    if [[ ${#name} -gt $NAME_MAX_LENGTH ]]; then
        ERRORS+=("$skill: name '$name' exceeds max length (${#name} > $NAME_MAX_LENGTH)")
    fi

    # Check name characters (lowercase, hyphens, underscores)
    if [[ -n "$name" ]] && ! [[ "$name" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        ERRORS+=("$skill: name '$name' contains invalid characters (use lowercase, hyphens, underscores only)")
    fi

    # Check reserved names
    if is_in_list "$name" "$RESERVED_NAMES"; then
        ERRORS+=("$skill: name '$name' is reserved (conflicts with built-in command)")
    fi
}

# Check H) Upstream description constraints
check_upstream_description_constraints() {
    local skill_dir="$1"
    local skill
    skill=$(basename "$skill_dir")

    parse_skillmd_frontmatter "$skill_dir" || return 0

    local description="$FM_DESCRIPTION"

    # Check description is non-empty
    if [[ -z "$description" ]] || [[ -z "${description// /}" ]]; then
        ERRORS+=("$skill: description is empty (required by skills guide)")
    fi

    # Check description length
    if [[ ${#description} -gt $DESCRIPTION_MAX_LENGTH ]]; then
        ERRORS+=("$skill: description exceeds max length (${#description} > $DESCRIPTION_MAX_LENGTH)")
    fi
}

# Check I) SKILL.md conciseness
check_skillmd_conciseness() {
    local skill_dir="$1"
    local skill
    skill=$(basename "$skill_dir")

    local skillmd="$skill_dir/SKILL.md"
    if [[ ! -f "$skillmd" ]]; then
        return 0
    fi

    local line_count
    line_count=$(wc -l < "$skillmd" | tr -d ' ')

    if [[ $line_count -gt $SKILLMD_MAX_LINES ]]; then
        WARNINGS+=("$skill: SKILL.md is $line_count lines (best practice: <$SKILLMD_MAX_LINES). This is a signal, not a correctness issue. Consider moving details to skill.yaml.")
    fi
}

# Check K) Workflow checklist (procedure section)
check_procedure_section() {
    local skill_dir="$1"
    local kind="$2"
    local skill
    skill=$(basename "$skill_dir")

    # Only check gate, scaffolder, meta
    if [[ "$kind" != "gate" ]] && [[ "$kind" != "scaffolder" ]] && [[ "$kind" != "meta" ]]; then
        return 0
    fi

    parse_skill_yaml "$skill_dir"

    if [[ "$SKILL_YAML_HAS_PROCEDURE" == false ]]; then
        WARNINGS+=("$skill: kind '$kind' should have a procedure section in skill.yaml (workflow checklist best practice)")
    fi
}

# ============================================================================
# MAIN AUDIT FUNCTION
# ============================================================================

audit_skill() {
    local skill_dir="$1"
    local skill
    skill=$(basename "$skill_dir")

    # Check skill.yaml exists and get kind
    local kind
    kind=$(check_skill_kind "$skill_dir") || return 0

    # Check required files for kind
    check_required_files "$skill_dir" "$kind"

    # Check Stop hook discipline
    check_stop_hook_discipline "$skill_dir" "$kind"

    # Check collaboration references
    check_collaboration_references "$skill_dir"

    # Check no patterns in SKILL.md
    check_no_patterns_in_skillmd "$skill_dir" "$kind"

    # Upstream Skills Guide Constraints (STRICT)
    check_upstream_name_constraints "$skill_dir"
    check_upstream_description_constraints "$skill_dir"

    # Best Practices Checks (WARN-ONLY)
    check_skillmd_conciseness "$skill_dir"
    check_procedure_section "$skill_dir" "$kind"
}

# ============================================================================
# MAIN FUNCTIONS
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --strict)
                STRICT_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                export DEBUG_MODE
                shift
                ;;
            --help|-h)
                show_usage
                exit $SUCCESS
                ;;
            *)
                die "Unknown option: $1" $ERR_INVALID_ARGS
                ;;
        esac
    done
}

main() {
    # Parse command line arguments
    parse_arguments "$@"

    local skills_dir="$PROJECT_ROOT/.claude/skills"

    if [[ ! -d "$skills_dir" ]]; then
        echo "No .claude/skills directory found"
        exit $ERR_GENERAL
    fi

    # Collect all skill names and directories
    local skill_dirs=()

    for skill_dir in "$skills_dir"/*/; do
        [[ ! -d "$skill_dir" ]] && continue

        local skill
        skill=$(basename "$skill_dir")

        # Check prefix requirement (skip if SKILL_PREFIX is empty)
        if [[ -n "$SKILL_PREFIX" ]] && [[ "$skill" != ${SKILL_PREFIX}* ]]; then
            if [[ "$STRICT_MODE" == true ]]; then
                ERRORS+=("$skill: Directory does not start with '$SKILL_PREFIX' prefix (required)")
            else
                WARNINGS+=("$skill: Directory does not start with '$SKILL_PREFIX' prefix (should be renamed or removed)")
            fi
            continue
        fi

        if [[ ! -f "$skill_dir/SKILL.md" ]]; then
            continue
        fi

        ALL_SKILLS+=("$skill")
        skill_dirs+=("$skill_dir")
    done

    # Audit each skill
    for skill_dir in "${skill_dirs[@]}"; do
        audit_skill "$skill_dir"
    done

    # Check CLAUDE.md documentation
    check_documented_in_claudemd

    # Report results
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo "Warnings (${#WARNINGS[@]}):"
        for w in "${WARNINGS[@]}"; do
            echo "  - $w"
        done
        echo ""
    fi

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo "Errors (${#ERRORS[@]}):"
        for e in "${ERRORS[@]}"; do
            echo "  - $e"
        done
        exit $ERR_GENERAL
    fi

    if [[ "$STRICT_MODE" == true ]] && [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo "Strict mode: treating warnings as errors"
        exit $ERR_GENERAL
    fi

    echo "Audit passed: ${#skill_dirs[@]} skill(s) checked, ${#WARNINGS[@]} warning(s)"
    exit $SUCCESS
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================
main "$@"
