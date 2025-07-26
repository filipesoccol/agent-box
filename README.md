# opencode-box

**A secure, containerized development environment for AI-assisted coding with OpenCode**

OpenCode Box provides an isolated Docker environment where you can safely work with AI-powered development tools while keeping your host system secure. It automatically sets up a complete development environment with your project, credentials, and OpenCode configurations.

## 🚀 Installation

Install OpenCode Box globally via NPM:

```bash
npm install -g opencode-box
```

## ⚡ Quick Start

1. **Navigate to any Git repository:**
   ```bash
   cd /path/to/your/git/project
   ```

2. **Launch OpenCode Box:**
   ```bash
   opencodebox
   ```

**That's it!** OpenCode Box will automatically:
- 🐳 Build the Docker image (if not already built)
- 🔐 Securely forward your SSH/Git credentials to the container
- ⚙️ Copy OpenCode configurations (`~/.local/share/opencode` and `~/.config/opencode`)
- 📂 Clone the current repository inside the container
- 🌿 Checkout to the current branch from your host machine
- 🤖 Start OpenCode in the isolated environment

## 📋 System Requirements

### Required Dependencies
- **Node.js**: v16.0.0 or higher
- **npm**: v7.0.0 or higher (comes with Node.js)
- **Docker**: v20.10.0 or higher (installed and running)
- **Git**: v2.25.0 or higher (configured on host machine)

### Authentication Requirements
- **SSH Agent**: Must be running with Git credentials loaded
- **Git Configuration**: User name and email configured globally
- **Repository Access**: Valid SSH key or credentials for the target repository

### Optional but Recommended
- **OpenCode CLI**: Pre-installed on host machine for easier authentication setup
- **Docker Compose**: v2.0.0 or higher (for advanced configurations)

## 🔧 Prerequisites Setup

### SSH Agent Configuration

SSH agent is **required** for:
- 🔒 SSH-based Git URLs (`git@github.com:user/repo.git`)
- 🏠 Private repository access
- 🔑 SSH-authenticated Git operations

**Setup SSH Agent:**
```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add your SSH key (replace with your key path)
ssh-add ~/.ssh/id_rsa

# Verify key is loaded
ssh-add -l
```

### Git Configuration Verification

Ensure Git is properly configured:
```bash
# Check current configuration
git config --global user.name
git config --global user.email

# Set if not configured
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Docker Setup Verification

Verify Docker is running:
```bash
# Check Docker status
docker --version
docker info

# Test Docker functionality
docker run hello-world
```

## 💡 Usage Examples

### Basic Usage
```bash
# Navigate to any Git project
cd ~/my-projects/react-app
opencodebox
```

### Advanced Scenarios
```bash
# Works with monorepos
cd ~/my-projects/large-monorepo
opencodebox

# Works with private repositories
cd ~/my-projects/private-enterprise-app
opencodebox

# Works with different Git providers
cd ~/my-projects/gitlab-project
opencodebox
```

## 🏗️ Container Architecture

The OpenCode Box container includes:
- **Base Image**: `node:20-alpine` (lightweight and secure)
- **OpenCode CLI**: Globally installed via `npm install -g opencode-ai`
- **Non-root User**: Secure user environment without sudo privileges
- **Isolated Network**: Container networking for security
- **Volume Mounts**: Project files and configuration directories

## 🔍 Troubleshooting

### Common Issues

**SSH Key Not Found:**
```bash
# Ensure SSH agent is running and key is added
ssh-add -l
```

**Docker Permission Denied:**
```bash
# Add user to docker group (Linux)
sudo usermod -aG docker $USER
# Then logout and login again
```

**Git Authentication Failed:**
```bash
# Test SSH connection to GitHub
ssh -T git@github.com
```

**OpenCode Configuration Missing:**
```bash
# Verify OpenCode config exists
ls -la ~/.config/opencode
ls -la ~/.local/share/opencode
```

## 🚧 Roadmap

- [ ] **Volume Mounting**: Mount specific local folders with absolute paths for document/image sharing
- [ ] **Multi-Platform Support**: Enhanced support for Windows and Linux environments
- [ ] **Performance Optimization**: Faster container startup and build times
