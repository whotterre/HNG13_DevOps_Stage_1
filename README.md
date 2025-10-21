# DevOps HNG 13 Internship Stage 1 submission: Automated Deployment Script

This repository contains the submission for the HNG DevOps Intern Stage 1 task.

The project is a single, robust Bash script (`deploy.sh`) designed to completely automate the deployment of a Dockerized application from a Git repository to a remote Linux server. It handles everything from environment setup to Nginx reverse proxy configuration.

## Features

  * **Interactive Setup:** Prompts the user for all necessary credentials (Git URL, PAT, SSH details, App Port).
  * **Environment Provisioning:** Automatically installs and configures Docker, Docker Compose, and Nginx on the remote server (idempotent).
  * **Automated Deployment:**
      * Clones or pulls the latest changes from the specified Git branch.
      * Transfers project files to the remote server using `rsync`.
      * Builds the Docker image and starts the container.
  * **Reverse Proxy Configuration:** Dynamically creates and enables an Nginx config to proxy traffic from port 80 to the running application container.
  * **Robust & Idempotent:** Includes comprehensive error handling (`set -e`), logging (to `deploy_YYYYMMDD.log`), and is safe to re-run. It gracefully stops and removes old containers before deploying new ones.

## Prerequisites

Before running the script, you will need:

  * A remote Linux server (tested on Ubuntu).
  * SSH key-based access to the server. Your SSH user must have `sudo` privileges.
  * A Git repository containing a Dockerized application (must have a `Dockerfile`).
  * A Git Personal Access Token (PAT) with `repo` (read) access.

## Usage

1.  Clone this repository:

    ```bash
    git clone https://github.com/username/repo-name.git
    cd repo-name
    ```

2.  Make the script executable:

    ```bash
    chmod +x deploy.sh
    ```

3.  Run the script and follow the interactive prompts:

    ```bash
    ./deploy.sh
    ```

The script will ask for the following:

  * Git Repository URL
  * Git Personal Access Token
  * Branch Name
  * Remote Server IP
  * Remote SSH User
  * Path to your SSH Private Key
  * Your application's internal port (e.g., `8080`, `3000`)

Upon successful execution, your application will be built, deployed, and accessible via the server's IP address on port 80.
