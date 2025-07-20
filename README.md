# OPENCODE BOX

A secure, lightweight Docker environment for AI-assisted development with OpenCode. This NPM tool provides an isolated environment where you can clone repositories and work with OpenCode while keeping your main system secure.

## Installation

Install OpenCode Box globally from NPM:

```bash
npm install -g opencode-box
```

## Quick Start

1. **Navigate to any git repository:**
   ```bash
   cd /path/to/your/git/project
   ```

2. **Run OpenCode Box:**
   ```bash
   opencodebox
   ```

That's it! OpenCode Box will automatically:
- Build the Docker image (if not already built)
- Copy your SSH credentials securely to the container
- Copy OpenCode configurations from `~/.local/share/opencode` and `~/.config/opencode`
- Clone the current repository inside the container
- Checkout to the current branch
- Start OpenCode in the isolated environment

## Requirements

- Node.js (v16 or higher) and npm
- Docker installed and running  
- SSH agent with your Git credentials loaded
- Git configured on your host machine
- Opencode installed is optional but this will facilitate your authentication in containers

## Setup SSH Agent

The SSH agent is required when:

- Working with SSH-based Git URLs (like git@github.com:user/repo.git)
- Accessing private repositories
- Your Git remote is configured to use SSH authentication

```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add your SSH key
ssh-add ~/.ssh/id_rsa  # or your specific key file
```

## Usage Examples

```bash
# Navigate to any git project and start OpenCode Box
cd ~/my-projects/react-app
opencodebox

# Works with any git repository
cd ~/my-projects/node-server
opencodebox
```

## TODO

- Mount a specific local folder in container with same absolute path to be able to share images/documents with the AI.