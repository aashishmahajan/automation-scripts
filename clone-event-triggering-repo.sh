#!/bin/bash

# Read Bamboo variables
REPO_NAME=${bamboo.triggered.repo}
BRANCH_NAME=${bamboo.triggered.branch}

# Ensure the variables are not empty
if [[ -z "$REPO_NAME" || -z "$BRANCH_NAME" ]]; then
    echo "Error: Triggered repository or branch not found!"
    exit 1
fi

# Define the repository URL (replace this with your actual repo URL pattern)
REPO_URL="git@bitbucket.org:your-org/$REPO_NAME.git"

# Clone the repository and checkout the branch
echo "Cloning repository $REPO_URL and checking out branch $BRANCH_NAME..."
git clone -b "$BRANCH_NAME" "$REPO_URL" || {
    echo "Error: Failed to clone repository or branch does not exist."
    exit 1
}

# Navigate to the repository
cd "$REPO_NAME"

# Pull latest changes
git pull origin "$BRANCH_NAME"
