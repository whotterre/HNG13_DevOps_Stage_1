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

# Step 1: Collect data
# Validation functions for input items
check_url() {  # Validation for GitHub URL input
    local url="$1"
    if [[ -z "$url" ]]; then
        fail "Git URL can't be empty"
        return 1
    fi
    if [[ ! "$url" =~ ^https?:// ]]; then
        fail "URL should start with http:// or https://"
        return 1
    fi
    return 0
}

check_file() {  # Checks if a file exists
    local file="$1"
    local desc="$2"
    if [[ ! -f "$file" ]]; then
        fail "$desc '$file' not found"
        return 1
    fi
    return 0
}

check_port(){  # Validate the input passed for the port number
    local file="$1"
    # Ensure that what is passed is a number
    if ! [[ "$port" =~ ^[0-9]+$]]; then
       fail "Port should be a number"
       return 1
    fi 
    # Ensure that the port number is in the range of 1 - 65535
    if [[ "$port" -lt 1 || "$port" -gt 65535]]; then
       fail "Port should be between 1 and 65535"
       return 1
    fi
    return 0
}

# Part that actually gets input
get_input(){
    # Read GitHub repository URL
    while true; do 
       read -p "GitHub repository URL: " repo_url
       if check_url "$repo_url"; then
          break
       fi
    done
     # Read GitHub Personal Access Token
    while true; do 
       read -sp "GitHub Personal Access Token: "
       echo 
       if [[ -n "$github_pat" ]]; then 
          break
       else 
          fail "PAT field can't be empty"
       fi
    done
    # Read branch name
    read -p "Branch [main]: " branch
    branch=${branch: -main}
    # Collect SSH details
    # Read SSH username
    while true; do 
        read -p "SSH user: " ssh_user
        if [[ -n $ssh_user]]; then 
            break
        else 
            fail "SSH user required"
        fi
    done

    # Read SSH Server IP
    while true; do
        read -p "Server IP: " server_ip
        if [[ -n "$server_ip"]]; then
           break
        else 
           fail "Server IP required"
        fi
    done

    # Read SSH key file
     while true; do
        read -p "SSH key path: " ssh_key
        if check_file "$ssh_key" "SSH key"; then
            break
        fi
    done

    # Read app port (internal container port)
    while true; do 
        read -p "App port: " app_port
        if check_port "$app_port"; then
           break
        fi
    done
}

# Step 2: Clone and setup GitHub repository
# Extract repository details by parsing
parse_repo(){
    local url = "$1"

    # Strip protocol info
    temp="${url#http://}"
    temp="${url#https://}"

    # Remove domain
    temp="${temp#*/}"
    # Get repository name
    repo_name="${temp##*/}"
    repo_name="${repo_name%.git}"
    echo "$repo_name"
}

# Clone or update repository
setup_repo(){
    local url = "$1"
    local pat = "$2"
    local branch = "$3"
    local repo_name = "$4"

    # Add PAT to URL for auth
    local auth_url = "https://${pat}@${url#https://}"
    # If repo clone exists locally, navigate and pull updates to the specified branch
    if [[ -d "$repo_name"]]; then
        info "Repository already exists, pulling latest updates...."
        cd "$repo_name"
        git checkout "$branch" 2>/dev/null || true
        if ! git pull origin "$branch"; then
            fail "Git pull failed"
            return 1
        fi
    else 
    # Otherwise, clone repo
        info "Cloning repo...."
        if ! git clone -b "$branch" "$auth_url"; then
           fail "Clone failed"
           return 1
        fi
        cd "$repo_name"
    fi
    return 0
}


# Step 3: Check for the existence of any Docker config files
check_docker_files(){
    if [[-f "Dockerfile "]]; then 
       success "Found Dockerfile"
       return 0
    elif [[-f "docker-compose.yml"]]; then 
       success "Found docker-compose.yml"
       return 0
    else 
       fail "No Docker config found"
       return 1
    fi
}

# Step 4: Establish connection to Linux via SSH and run a command
run_remote(){
    ssh -i "$ssh_key" -o StrictHostKeyChecking=no "${ssh_user}@${server_ip}" "$cmd"
}

# Step 5: Setup server by installing necessary dependencies
setup_server(){
    info "Setting up server..."
    # Install Docker, Docker Compose and NGINX
    run_remote '
        set -e
        sudo apt-get update
        sudo apt-get install -y docker.io docker-compose nginx"
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker $USER || true
    '
    success "Server setup done"
}

# Step 6: Deploy Dockerized application
copy_to_server(){
    local local_path="$1"
    local remote_path="$2"
    scp -i "$ssh_key" -o StrictHostKeyChecking=no -r "$local_path" "${ssh_user}@${server_ip}:$remote_path"
}
# Copy project files
deploy_app(){
    info "Deploying application..."

    # Copy project to server
    copy_to_server "." "/home/$ssh_user/$repo_name"

    # Build and run 
    if [[ -f "Dockerfile"]]; then 
       run_remote "
          set -e
          cd /home/$ssh_user/$repo_name
          sudo docker build -t app .
          sudo docker rm app || true
          sudo docker run -d --name app -p $app_port:$app_port app
       "
    elif [[ -f "docker-compose.yml"]]; then 
        run_remote "
          set -e 
          cd /home/$ssh_user/$repo_name
          sudo docker-compose down || true
          sudo docker-compose up -d
          "
    fi
    success "App deployed"
}

# Step 7: Configure Nginx as reverse proxy
# Setup nginx
setup_nginx() {
    info "Configuring nginx..."

    local nginx_config="
server {
    listen 80;
    server_name $server_ip;

    location / {
        proxy_pass http://127.0.0.1:$app_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
"

    run_remote "
        set -e
        echo '$nginx_config' | sudo tee /etc/nginx/sites-available/app > /dev/null
        sudo ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/
        sudo nginx -t
        sudo systemctl reload nginx
    "

    success "Nginx configured"
}

# Step 8: Check deployment
check_deployment() {
    info "Checking deployment..."

    # Wait a bit for app to start
    sleep 10

    if run_remote "sudo docker ps | grep app"; then
        success "Container is running"
    else
        fail "Container not running"
        return 1
    fi

    if run_remote "curl -s http://127.0.0.1:$app_port > /dev/null"; then
        success "App responding on port $app_port"
    else
        fail "App not responding"
        return 1
    fi

    if run_remote "curl -s http://$server_ip > /dev/null"; then
        success "Nginx proxy working"
    else
        fail "Nginx proxy failed"
        return 1
    fi

    return 0
}
