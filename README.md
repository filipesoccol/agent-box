# AGENT BOX

A secure, lightweight Docker environment for AI-assisted development with OpenCode. This NPM tool provides an isolated environment where you can clone repositories and work with OpenCode while keeping your main system secure.

## Installation

Install AgentBox globally as an NPM package:

```bash
# Clone the repository
git clone git@github.com:filipesoccol/agent-box.git
cd agent-box

# Install globally
./install.sh
```

Or install manually:

```bash
npm install -g .
```

## Quick Start

1. **Navigate to any git repository:**
   ```bash
   cd /path/to/your/git/project
   ```

2. **Run AgentBox:**
   ```bash
   agentbox
   ```

That's it! AgentBox will automatically:
- Build the Docker image (if not already built)
- Copy your SSH credentials securely to the container
- Copy OpenCode configurations from `~/.local/share/opencode` and `~/.config/opencode`
- Clone the current repository inside the container
- Checkout to the current branch
- Start OpenCode in the isolated environment

## Features

✅ **All AGENT.md Requirements Implemented:**
- ✅ NPM global tool that works in any project directory
- ✅ Builds Docker image automatically if it doesn't exist
- ✅ Runs container instance with proper configuration
- ✅ Copies GitHub user credentials (fails if not found)
- ✅ Copies OpenCode config folders (`~/.local/share/opencode` and `~/.config/opencode`)
- ✅ Clones the current repository inside container
- ✅ Checks out to current branch from host machine

✅ **Container Properties:**
- ✅ Node.js 20 Alpine base image
- ✅ OpenCode installed with `npm install -g opencode-ai`
- ✅ Non-sudoer user (`developer`) created

## Requirements

- Node.js (v16 or higher) and npm
- Docker installed and running  
- SSH agent with your Git credentials loaded
- Git configured on your host machine

## Setup SSH Agent

```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add your SSH key
ssh-add ~/.ssh/id_rsa  # or your specific key file
```

## Usage Examples

```bash
# Navigate to any git project and start AgentBox
cd ~/my-projects/react-app
agentbox

# Works with any git repository
cd ~/my-projects/node-server
agentbox
```
