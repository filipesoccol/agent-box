#!/bin/bash

# Entrypoint script for OpenCode Box container
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

print_info "OpenCode Box container started"

# Validate environment variables
if [ -z "$REPO_URL" ] || [ -z "$REPO_NAME" ] || [ -z "$REPO_BRANCH" ]; then
    print_error "Missing required environment variables (REPO_URL, REPO_NAME, REPO_BRANCH)"
    exit 1
fi

# Basic validation for dangerous characters
if echo "$REPO_URL" | grep -q '[;&|`$(){}[\]<>]'; then
    print_error "Repository URL contains invalid characters"
    exit 1
fi

if echo "$REPO_NAME" | grep -q '[;&|`$(){}[\]<>]'; then
    print_error "Repository name contains invalid characters"
    exit 1
fi

if echo "$REPO_BRANCH" | grep -q '[;&|`$(){}[\]<>~^:?*\\]'; then
    print_error "Branch name contains invalid characters"
    exit 1
fi

print_info "Repository URL: $REPO_URL"
print_info "Repository Name: $REPO_NAME"
print_info "Repository Branch: $REPO_BRANCH"

# Change to workspace directory
cd /workspace

# Clone the repository with timeout and depth limit for security
print_info "Cloning repository: $REPO_NAME"
if [ -d "$REPO_NAME" ]; then
    print_warning "Directory $REPO_NAME already exists, removing it..."
    rm -rf "$REPO_NAME"
fi

# Use timeout and shallow clone for security
timeout 300 git clone --depth 1 --single-branch --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_NAME" || {
    print_error "Failed to clone repository (timeout or error)"
    exit 1
}

print_success "Repository cloned successfully"

# Change to the repository directory
cd "$REPO_NAME"
print_info "Working in: $(pwd)"

# Verify we're on the correct branch (shallow clone should handle this)
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$REPO_BRANCH" ]; then
    print_warning "Current branch ($CURRENT_BRANCH) differs from expected ($REPO_BRANCH)"
    print_info "Attempting to switch to branch: $REPO_BRANCH"
    timeout 60 git checkout "$REPO_BRANCH" 2>/dev/null || timeout 60 git checkout -b "$REPO_BRANCH" || {
        print_error "Failed to checkout branch $REPO_BRANCH"
        exit 1
    }
fi

# Start OpenCode
print_info "Starting OpenCode..."
opencode