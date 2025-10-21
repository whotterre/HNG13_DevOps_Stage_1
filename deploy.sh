#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Stage 1: Collect and validate user input
log "Starting deployment script..."

# Git Repository URL
while true; do
    read -p "Enter Git repository URL: " repo_url
    if [[ -z "$repo_url" ]]; then
        error "Repository URL cannot be empty"
    elif [[ ! "$repo_url" =~ ^https?:// ]]; then
        error "Invalid URL format. Must start with http:// or https://"
    else
        break
    fi
done

# Personal Access Token (hidden input)
while true; do
    read -sp "Enter Personal Access Token: " github_pat
    echo
    if [[ -z "$github_pat" ]]; then
        error "PAT cannot be empty"
    else
        break
    fi
done

# Branch name with default
read -p "Enter branch name [default: main]: " branch_name
branch_name=${branch_name:-main}
log "Using branch: $branch_name"

# SSH Username
while true; do
    read -p "Enter SSH username: " ssh_username
    if [[ -z "$ssh_username" ]]; then
        error "SSH username cannot be empty"
    else
        break
    fi
done

# Server IP Address
while true; do
    read -p "Enter server IP address: " ip_address
    if [[ -z "$ip_address" ]]; then
        error "IP address cannot be empty"
    elif [[ ! "$ip_address" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        error "Invalid IP address format"
    else
        break
    fi
done

# SSH Key Path
while true; do
    read -p "Enter SSH key path: " ssh_key_path
    if [[ -z "$ssh_key_path" ]]; then
        error "SSH key path cannot be empty"
    elif [[ ! -f "$ssh_key_path" ]]; then
        error "SSH key file does not exist at: $ssh_key_path"
    else
        break
    fi
done

# Application Port
while true; do
    read -p "Enter application port: " port
    if [[ -z "$port" ]]; then
        error "Port cannot be empty"
    elif ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error "Port must be a number between 1 and 65535"
    else
        break
    fi
done

log "All parameters collected and validated successfully"