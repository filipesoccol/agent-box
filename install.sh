#!/bin/bash

# AgentBox Installation Script
# This script installs agentbox as a global npm package

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info "Installing AgentBox globally..."

# Check if npm is available
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Install the package globally
npm install -g .

print_success "AgentBox installed successfully!"
print_info "You can now run 'agentbox' from any git repository directory."
print_info ""
print_info "Usage:"
print_info "  cd /path/to/your/git/project"
print_info "  agentbox"
print_info ""
print_info "Make sure you have:"
print_info "  - SSH agent running with your git credentials"
print_info "  - OpenCode configuration in ~/.local/share/opencode or ~/.config/opencode"
