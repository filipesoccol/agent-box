#!/bin/bash

# Entrypoint script for Agent Box container
# This script runs inside the container to clone the repository and start OpenCode

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info "Agent Box container started"
print_info "Repository URL: $REPO_URL"
print_info "Repository Name: $REPO_NAME"
print_info "Repository Branch: $REPO_BRANCH"

# Change to workspace directory
cd /workspace

# Clone the repository
print_info "Cloning repository: $REPO_NAME"
if [ -d "$REPO_NAME" ]; then
    print_warning "Directory $REPO_NAME already exists, removing it..."
    rm -rf "$REPO_NAME"
fi

git clone "$REPO_URL" "$REPO_NAME" || {
    print_error "Failed to clone repository"
    exit 1
}

print_success "Repository cloned successfully"

# Change to the repository directory
cd "$REPO_NAME"
print_info "Working in: $(pwd)"

# Checkout to the specified branch if needed
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$REPO_BRANCH" ]; then
    print_info "Switching to branch: $REPO_BRANCH"
    git checkout "$REPO_BRANCH" 2>/dev/null || git checkout -b "$REPO_BRANCH" || {
        print_error "Failed to checkout branch $REPO_BRANCH"
        exit 1
    }
fi

# Start OpenCode
print_info "Starting OpenCode..."
opencode