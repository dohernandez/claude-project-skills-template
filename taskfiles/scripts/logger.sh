#!/usr/bin/env bash

# ============================================================================
# SHARED LOGGING FUNCTIONS
# ============================================================================
# Consistent logging functions across all scripts
#
# Usage:
#   source this script and use:
#   log_info "message"
#   log_error "Error message"
#   log_debug "Debug (only if DEBUG_MODE=true)"

: "${DEBUG_MODE:=false}"
: "${LOG_SHOW_TIMESTAMP:=true}"
: "${LOG_TIMESTAMP_FORMAT:=%Y-%m-%d %H:%M:%S}"

log_timestamp_prefix() {
    if [[ "${LOG_SHOW_TIMESTAMP:-true}" == "true" ]]; then
        local ts
        ts="$(date +"${LOG_TIMESTAMP_FORMAT}")"
        echo -n "[${ts}] "
    fi
}

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m'

log_info() {
    echo -e "$(log_timestamp_prefix)${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "$(log_timestamp_prefix)${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "$(log_timestamp_prefix)${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "$(log_timestamp_prefix)${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        echo -e "$(log_timestamp_prefix)${GRAY}[DEBUG]${NC} $1" >&2
    fi
}

log() {
    local level="$1"
    local message="$2"

    case "$level" in
        "info"|"INFO") log_info "$message" ;;
        "success"|"SUCCESS") log_success "$message" ;;
        "warning"|"WARNING") log_warning "$message" ;;
        "error"|"ERROR") log_error "$message" ;;
        "debug"|"DEBUG") log_debug "$message" ;;
        *) echo -e "$(log_timestamp_prefix)[UNKNOWN] $message" >&2 ;;
    esac
}
