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

# Validate SSH socket exists and is accessible
if [ -n "$SSH_AUTH_SOCK" ]; then
    if [ ! -S "$SSH_AUTH_SOCK" ]; then
        print_error "SSH_AUTH_SOCK is not a valid socket"
        exit 1
    fi
    print_info "SSH agent is accessible"
else
    print_error "SSH_AUTH_SOCK not provided"
    exit 1
fi

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

# Copy OpenCode configuration files from host to developer home directory
print_info "Setting up OpenCode configuration..."

# Copy local/share/opencode config if provided
if [ -n "$HOST_OPENCODE_LOCAL_SHARE" ] && [ -d "$HOST_OPENCODE_LOCAL_SHARE" ]; then
    print_info "Copying OpenCode local/share config from host..."
    cp -r "$HOST_OPENCODE_LOCAL_SHARE"/* /home/developer/.local/share/opencode/ 2>/dev/null || {
        print_warning "Failed to copy some files from local/share config (this may be normal)"
    }
    print_success "OpenCode local/share config copied"
else
    print_info "No local/share OpenCode config found on host"
fi

# Copy .config/opencode config if provided  
if [ -n "$HOST_OPENCODE_CONFIG" ] && [ -d "$HOST_OPENCODE_CONFIG" ]; then
    print_info "Copying OpenCode config from host..."
    cp -r "$HOST_OPENCODE_CONFIG"/* /home/developer/.config/opencode/ 2>/dev/null || {
        print_warning "Failed to copy some files from config (this may be normal)"
    }
    print_success "OpenCode config copied"
else
    print_info "No .config OpenCode config found on host"
fi

# Ensure proper ownership of copied files
chown -R developer:developer /home/developer/.local/share/opencode /home/developer/.config/opencode 2>/dev/null || true

print_success "OpenCode configuration setup complete"

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