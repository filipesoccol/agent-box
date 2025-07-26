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

# Validate and setup SSH access
if [ -z "$SSH_AUTH_SOCK" ]; then
    print_error "SSH_AUTH_SOCK environment variable not set"
    exit 1
fi

if [ ! -S "$SSH_AUTH_SOCK" ]; then
    print_error "SSH_AUTH_SOCK is not a valid socket: $SSH_AUTH_SOCK"
    exit 1
fi

print_info "Setting up SSH access..."

# Detect system type for platform-specific handling
PLATFORM="unknown"
if [ "$(uname)" = "Darwin" ]; then
    PLATFORM="macos"
elif [ "$(uname)" = "Linux" ]; then
    PLATFORM="linux"
fi

# Fix SSH socket permissions if needed
if [ ! -r "$SSH_AUTH_SOCK" ] || [ ! -w "$SSH_AUTH_SOCK" ]; then
    # Try multiple approaches to fix SSH socket access
    FIXED=false
    
    # Approach 1: Add user to socket group (with cross-platform stat)
    SOCKET_GID=""
    if stat -c %g "$SSH_AUTH_SOCK" >/dev/null 2>&1; then
        # GNU stat (Linux)
        SOCKET_GID=$(stat -c %g "$SSH_AUTH_SOCK" 2>/dev/null)
    elif stat -f %g "$SSH_AUTH_SOCK" >/dev/null 2>&1; then
        # BSD stat (macOS)
        SOCKET_GID=$(stat -f %g "$SSH_AUTH_SOCK" 2>/dev/null)
    fi
    
    if [ -n "$SOCKET_GID" ] && [ "$SOCKET_GID" != "0" ]; then
        if sudo usermod -a -G "$SOCKET_GID" node 2>/dev/null; then
            # Try to refresh group membership (platform-specific)
            if [ "$PLATFORM" = "linux" ]; then
                newgrp "$SOCKET_GID" 2>/dev/null || true
            fi
            FIXED=true
        fi
    fi
    
    # Approach 2: Change socket permissions
    if [ "$FIXED" = false ]; then
        if sudo chmod 666 "$SSH_AUTH_SOCK" 2>/dev/null; then
            FIXED=true
        fi
    fi
    
    # Approach 3: Copy SSH keys from host (improved cross-platform)
    if [ "$FIXED" = false ] && [ -d "/host-ssh" ]; then
        # Copy private keys
        for key_file in id_rsa id_ed25519 id_ecdsa id_dsa; do
            if [ -f "/host-ssh/$key_file" ]; then
                cp "/host-ssh/$key_file" /home/node/.ssh/ 2>/dev/null || true
                chmod 600 "/home/node/.ssh/$key_file" 2>/dev/null || true
                FIXED=true
            fi
        done
        
        # Copy public keys
        for pub_file in id_rsa.pub id_ed25519.pub id_ecdsa.pub id_dsa.pub; do
            if [ -f "/host-ssh/$pub_file" ]; then
                cp "/host-ssh/$pub_file" /home/node/.ssh/ 2>/dev/null || true
                chmod 644 "/home/node/.ssh/$pub_file" 2>/dev/null || true
            fi
        done
        
        # Copy known_hosts and config if they exist
        for config_file in known_hosts config; do
            if [ -f "/host-ssh/$config_file" ]; then
                cp "/host-ssh/$config_file" /home/node/.ssh/ 2>/dev/null || true
                chmod 644 "/home/node/.ssh/$config_file" 2>/dev/null || true
            fi
        done
    fi
    
    if [ "$FIXED" = false ]; then
        print_error "Could not establish SSH access"
        print_info "Please ensure SSH agent is running and keys are loaded on the host"
        exit 1
    fi
fi

# Test SSH connection to GitHub
print_info "Verifying GitHub access..."
SSH_OUTPUT=$(timeout 10 ssh -T git@github.com -o ConnectTimeout=5 -o StrictHostKeyChecking=yes -o BatchMode=yes 2>&1 || echo "SSH_FAILED")

if echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    print_success "GitHub SSH access verified"
elif echo "$SSH_OUTPUT" | grep -q "Permission denied"; then
    print_error "GitHub SSH access failed - Permission denied"
    exit 1
elif echo "$SSH_OUTPUT" | grep -q "SSH_FAILED"; then
    print_error "GitHub SSH connection failed"
    exit 1
else
    print_warning "SSH test returned unexpected output, proceeding anyway"
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

# Setup OpenCode configuration
print_info "Setting up OpenCode configuration..."

CONFIG_COPIED=false

# Copy local/share/opencode config if provided
if [ -n "$HOST_OPENCODE_LOCAL_SHARE" ] && [ -d "$HOST_OPENCODE_LOCAL_SHARE" ]; then
    cp -r "$HOST_OPENCODE_LOCAL_SHARE"/* /home/node/.local/share/opencode/ 2>/dev/null || true
    CONFIG_COPIED=true
fi

# Copy .config/opencode config if provided  
if [ -n "$HOST_OPENCODE_CONFIG" ] && [ -d "$HOST_OPENCODE_CONFIG" ]; then
    cp -r "$HOST_OPENCODE_CONFIG"/* /home/node/.config/opencode/ 2>/dev/null || true
    CONFIG_COPIED=true
fi

# Ensure proper ownership of copied files
if [ -d "/home/node/.local/share/opencode" ]; then
    find /home/node/.local/share/opencode -exec chown node:node {} \; 2>/dev/null || true
fi

if [ -d "/home/node/.config/opencode" ]; then
    find /home/node/.config/opencode -exec chown node:node {} \; 2>/dev/null || true
fi

if [ "$CONFIG_COPIED" = true ]; then
    print_success "OpenCode configuration imported from host"
else
    print_info "Using default OpenCode configuration"
fi

# Clone and setup repository
cd /workspace

print_info "Cloning repository: $REPO_NAME ($REPO_BRANCH)"
if [ -d "$REPO_NAME" ]; then
    rm -rf "$REPO_NAME"
fi

# Clone repository with timeout
timeout 300 git clone --depth 1 --single-branch --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_NAME" || {
    print_error "Failed to clone repository"
    exit 1
}

cd "$REPO_NAME"
print_success "Repository ready: $(pwd)"

# Verify branch (shallow clone should handle this automatically)
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$REPO_BRANCH" ]; then
    timeout 60 git checkout "$REPO_BRANCH" 2>/dev/null || timeout 60 git checkout -b "$REPO_BRANCH" || {
        print_error "Failed to checkout branch $REPO_BRANCH"
        exit 1
    }
fi

# Start OpenCode
print_info "Starting OpenCode..."
opencode