#!/bin/bash

set -e

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_FILE="deploy_$(date +%Y%m%d).log"

# Simple logging
log() {
    local msg="$1"
    local color="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${color}[$timestamp] $msg${NC}" | tee -a "$LOG_FILE"
}


info() { log "$1" "$BLUE"; }
success() { log "$1" "$GREEN"; }
warn() { log "$1" "$YELLOW"; }
fail() { log "$1" "$RED"; }


# Cleanup function
cleanup() {
    echo "Cleaning up...\n"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
    fi
    success "Cleanup done"
}

trap cleanup EXIT


