#!/usr/bin/env node

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const url = require('url');

// Simple colored output functions
const log = {
    info: (msg) => console.log(`\x1b[34m[INFO]\x1b[0m ${msg}`),
    success: (msg) => console.log(`\x1b[32m[SUCCESS]\x1b[0m ${msg}`),
    warning: (msg) => console.log(`\x1b[33m[WARNING]\x1b[0m ${msg}`),
    error: (msg) => console.log(`\x1b[31m[ERROR]\x1b[0m ${msg}`)
};

// Security validation functions
function validateRepositoryUrl(repoUrl) {
    if (!repoUrl || typeof repoUrl !== 'string') {
        throw new Error('Repository URL is required and must be a string');
    }

    // Remove any potential command injection characters
    const sanitized = repoUrl.trim();

    // Check for dangerous characters that could be used for command injection
    const dangerousChars = /[;&|`$(){}[\]<>]/;
    if (dangerousChars.test(sanitized)) {
        throw new Error('Repository URL contains invalid characters');
    }

    // Validate URL format
    try {
        const parsedUrl = new URL(sanitized);

        // Only allow specific protocols
        if (!['https:', 'ssh:', 'git:'].includes(parsedUrl.protocol)) {
            throw new Error('Only HTTPS, SSH, and Git protocols are allowed');
        }

        // Validate hostname for trusted Git providers
        const trustedHosts = [
            'github.com',
            'gitlab.com',
            'bitbucket.org',
            'dev.azure.com',
            'ssh.dev.azure.com'
        ];

        if (!trustedHosts.includes(parsedUrl.hostname)) {
            throw new Error(`Untrusted hostname: ${parsedUrl.hostname}. Only ${trustedHosts.join(', ')} are allowed`);
        }

        return sanitized;
    } catch (urlError) {
        // Try SSH format (git@github.com:user/repo.git)
        const sshPattern = /^git@([a-zA-Z0-9.-]+):([a-zA-Z0-9._/-]+)\.git$/;
        const sshMatch = sanitized.match(sshPattern);

        if (sshMatch) {
            const hostname = sshMatch[1];
            const trustedSshHosts = ['github.com', 'gitlab.com', 'bitbucket.org'];

            if (!trustedSshHosts.includes(hostname)) {
                throw new Error(`Untrusted SSH hostname: ${hostname}`);
            }
            return sanitized;
        }

        throw new Error('Invalid repository URL format');
    }
}

function validateBranchName(branchName) {
    if (!branchName || typeof branchName !== 'string') {
        throw new Error('Branch name is required and must be a string');
    }

    const sanitized = branchName.trim();

    // Check for dangerous characters and git-specific invalid characters
    const invalidChars = /[;&|`$(){}[\]<>~^:?*\\\s]/;
    if (invalidChars.test(sanitized)) {
        throw new Error('Branch name contains invalid characters');
    }

    // Additional git branch name validation
    if (sanitized.startsWith('-') || sanitized.endsWith('.') || sanitized.includes('..')) {
        throw new Error('Invalid branch name format');
    }

    // Limit length to prevent buffer overflow attacks
    if (sanitized.length > 250) {
        throw new Error('Branch name too long');
    }

    return sanitized;
}

function validateRepoName(repoName) {
    if (!repoName || typeof repoName !== 'string') {
        throw new Error('Repository name is required and must be a string');
    }

    const sanitized = repoName.trim();

    // Only allow alphanumeric, hyphens, underscores, and dots
    const validPattern = /^[a-zA-Z0-9._-]+$/;
    if (!validPattern.test(sanitized)) {
        throw new Error('Repository name contains invalid characters');
    }

    // Prevent directory traversal
    if (sanitized.includes('..') || sanitized.startsWith('.')) {
        throw new Error('Invalid repository name format');
    }

    // Limit length
    if (sanitized.length > 100) {
        throw new Error('Repository name too long');
    }

    return sanitized;
}

function checkRequirements() {
    log.info('Checking system requirements...');

    // Check if Docker is installed and accessible
    try {
        const dockerVersion = execSync('docker --version', { encoding: 'utf8', timeout: 5000 });
        log.info(`Docker found: ${dockerVersion.trim()}`);
    } catch (error) {
        log.error('Docker is not installed, not in PATH, or not accessible');
        log.error('Please install Docker and ensure it\'s running');
        process.exit(1);
    }

    // Check Docker daemon is running
    try {
        execSync('docker info', { stdio: 'ignore', timeout: 5000 });
        log.info('Docker daemon is running');
    } catch (error) {
        log.error('Docker daemon is not running. Please start Docker');
        process.exit(1);
    }

    // Check if we're in a git repository
    try {
        execSync('git rev-parse --git-dir', { stdio: 'ignore', timeout: 5000 });
        log.info('Git repository detected');
    } catch (error) {
        log.error('Not in a git repository. Please run opencodebox from inside a git project.');
        process.exit(1);
    }

    // Check SSH agent or credentials
    if (!process.env.SSH_AUTH_SOCK) {
        log.error('SSH agent not found. Please start ssh-agent and add your SSH keys.');
        if (process.platform === 'darwin') {
            log.info('On macOS, try: eval "$(ssh-agent -s)" && ssh-add --apple-use-keychain ~/.ssh/id_rsa');
        } else {
            log.info('Run: eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa');
        }
        process.exit(1);
    }

    // Verify SSH agent is accessible
    try {
        if (!fs.existsSync(process.env.SSH_AUTH_SOCK)) {
            throw new Error('SSH socket does not exist');
        }
        log.info('SSH agent is accessible');
    } catch (error) {
        log.error(`SSH agent socket is not accessible: ${error.message}`);
        if (process.platform === 'darwin') {
            log.info('On macOS, SSH agent issues are common. Try restarting your terminal or running:');
            log.info('eval "$(ssh-agent -s)" && ssh-add --apple-use-keychain');
        }
        process.exit(1);
    }

    log.success('All requirements satisfied');
}

function getRepoInfo() {
    try {
        // Get remote URL
        const remoteUrl = execSync('git config --get remote.origin.url', { encoding: 'utf8' }).trim();

        // Get current branch
        const currentBranch = execSync('git branch --show-current', { encoding: 'utf8' }).trim();

        // Get repository name from URL
        const repoName = path.basename(remoteUrl, '.git');

        // Validate all inputs
        const validatedUrl = validateRepositoryUrl(remoteUrl);
        const validatedBranch = validateBranchName(currentBranch);
        const validatedName = validateRepoName(repoName);

        return {
            url: validatedUrl,
            name: validatedName,
            branch: validatedBranch
        };
    } catch (error) {
        log.error(`Failed to get repository information: ${error.message}`);
        process.exit(1);
    }
}

function buildDockerImage() {
    const imageName = 'opencode-box';

    // Check if image exists
    try {
        const images = execSync(`docker images ${imageName} --format "{{.Repository}}"`, { encoding: 'utf8' });
        if (images.includes(imageName)) {
            log.info(`Docker image '${imageName}' already exists, skipping build`);
            return;
        }
    } catch (error) {
        // Image doesn't exist, proceed with build
    }

    log.info('Building Docker image...');
    try {
        const dockerfilePath = path.join(__dirname, '..', 'Dockerfile');
        const contextPath = path.dirname(dockerfilePath);

        execSync(`docker build -t ${imageName} "${contextPath}"`, {
            stdio: 'inherit',
            cwd: contextPath
        });
        log.success('Docker image built successfully');
    } catch (error) {
        log.error('Failed to build Docker image');
        process.exit(1);
    }
}

function findOpenCodeConfigs() {
    const homeDir = os.homedir();
    const potentialPaths = [
        path.join(homeDir, '.local', 'share', 'opencode'),
        path.join(homeDir, '.config', 'opencode'),
        path.join(homeDir, '.shared', 'opencode'), // Alternative path mentioned by user
        path.join(homeDir, '.opencode'),
        path.join(homeDir, '.local', 'opencode'),
        path.join(homeDir, '.config', 'opencode-ai')
    ];

    const foundConfigs = [];

    potentialPaths.forEach(configPath => {
        if (fs.existsSync(configPath)) {
            log.success(`Found OpenCode config at: ${configPath}`);
            foundConfigs.push(configPath);
        }
    });

    if (foundConfigs.length === 0) {
        log.warning('No OpenCode configuration directories found');
    }

    return {
        localShare: foundConfigs.find(p => p.includes('.local/share/opencode')),
        config: foundConfigs.find(p => p.includes('.config/opencode')),
        alternative: foundConfigs.find(p => p.includes('.shared/opencode')),
        all: foundConfigs
    };
} function runContainer(repoInfo) {
    // Use timestamp to ensure unique container names for each run
    const timestamp = Date.now();
    const containerName = `opencode-box-container-${timestamp}`;

    log.info('Starting container with secure credential forwarding...');

    const dockerArgs = [
        'run', '-it', '--rm',  // --rm ensures automatic cleanup when container exits
        '--name', containerName,
        // Security hardening
        '--security-opt', 'no-new-privileges:true',  // Prevent privilege escalation
        '--cap-drop', 'ALL',  // Drop all capabilities
        '--cap-add', 'DAC_OVERRIDE',  // Only add necessary capabilities for file access
        '--cap-add', 'SETGID',  // Add capability for SSH socket access
        '--cap-add', 'SETUID',  // Add capability for user switching if needed
        '--cap-add', 'CHOWN',   // Add capability for changing file ownership
        // Network security
        '--network', 'bridge',  // Use default bridge network
        // SSH and Git configuration - mount SSH socket and directory
        '-v', `${process.env.SSH_AUTH_SOCK}:/ssh-agent`,  // Mount to a predictable path
        '-e', 'SSH_AUTH_SOCK=/ssh-agent',  // Set the socket path inside container
        // Environment variables (validated inputs)
        '-e', `REPO_URL=${repoInfo.url}`,
        '-e', `REPO_NAME=${repoInfo.name}`,
        '-e', `REPO_BRANCH=${repoInfo.branch}`
    ];

    // Conditionally mount SSH directory if it exists
    const sshDir = path.join(os.homedir(), '.ssh');
    if (fs.existsSync(sshDir)) {
        dockerArgs.push('-v', `${sshDir}:/host-ssh:ro`);
        log.info('Mounting SSH directory for fallback key access');
    }

    // Conditionally mount git config if it exists
    const gitConfig = path.join(os.homedir(), '.gitconfig');
    if (fs.existsSync(gitConfig)) {
        dockerArgs.push('-v', `${gitConfig}:/home/node/.gitconfig:ro`);
    }

    // Find and copy OpenCode config files from host to container
    const openCodeConfigs = findOpenCodeConfigs();

    // Mount host config directories as read-only so they can be copied inside container
    if (openCodeConfigs.localShare) {
        dockerArgs.push('-v', `${openCodeConfigs.localShare}:/tmp/host-opencode-local-share:ro`);
        dockerArgs.push('-e', 'HOST_OPENCODE_LOCAL_SHARE=/tmp/host-opencode-local-share');
        log.info(`Will copy OpenCode local/share config from: ${openCodeConfigs.localShare}`);
    }

    if (openCodeConfigs.config) {
        dockerArgs.push('-v', `${openCodeConfigs.config}:/tmp/host-opencode-config:ro`);
        dockerArgs.push('-e', 'HOST_OPENCODE_CONFIG=/tmp/host-opencode-config');
        log.info(`Will copy OpenCode config from: ${openCodeConfigs.config}`);
    }

    if (openCodeConfigs.all.length === 0) {
        log.warning('No OpenCode configurations found on host - container will start with default settings');
    }

    // Create dedicated writable volumes for container operation
    const stateVolume = `opencode-box-state-${timestamp}`;
    const workspaceVolume = `opencode-box-workspace-${timestamp}`;

    dockerArgs.push('-v', `${stateVolume}:/home/node/.local/state`);
    dockerArgs.push('-v', `${workspaceVolume}:/workspace`);

    // Add the image and command
    dockerArgs.push('opencode-box', '/app/entrypoint.sh');

    try {
        log.info(`Starting OpenCode environment...`);
        log.info(`Repository: ${repoInfo.name} (${repoInfo.branch})`);

        const child = spawn('docker', dockerArgs, {
            stdio: 'inherit',
            detached: false
        });

        child.on('exit', (code) => {
            if (code === 0) {
                log.success('OpenCode Box session completed successfully');
            } else {
                log.error(`OpenCode Box session ended with exit code ${code}`);
            }

            // Clean up the temporary volumes
            const volumes = [stateVolume, workspaceVolume];
            volumes.forEach(volume => {
                try {
                    execSync(`docker volume rm ${volume}`, { stdio: 'pipe', timeout: 10000 });
                    log.info(`Cleaned up temporary volume: ${volume}`);
                } catch (cleanupError) {
                    log.warning(`Failed to clean up volume ${volume}: ${cleanupError.message}`);
                }
            });
        });

        // Handle process termination gracefully
        process.on('SIGINT', () => {
            log.info('Received SIGINT, stopping container...');
            try {
                execSync(`docker stop ${containerName}`, { stdio: 'pipe', timeout: 10000 });
            } catch (stopError) {
                log.warning('Failed to stop container gracefully');
            }
        });

        process.on('SIGTERM', () => {
            log.info('Received SIGTERM, stopping container...');
            try {
                execSync(`docker stop ${containerName}`, { stdio: 'pipe', timeout: 10000 });
            } catch (stopError) {
                log.warning('Failed to stop container gracefully');
            }
        });
    } catch (error) {
        log.error('Failed to run container');
        console.error(error.message);
        process.exit(1);
    }
}

// Main execution
function main() {
    // Handle help and version flags
    if (process.argv.includes('--help') || process.argv.includes('-h')) {
        console.log(`
OpenCode Box - A secure Docker environment for AI-assisted development with OpenCode

Usage: opencodebox

Requirements:
  - Docker installed and running
  - Git repository (run from inside a git project)
  - SSH agent with credentials loaded

Example:
  cd /path/to/your/git/project
  opencodebox
`);
        return;
    }

    if (process.argv.includes('--version') || process.argv.includes('-v')) {
        console.log('opencodebox version 1.0.0');
        return;
    }

    log.info('Starting OpenCode Box...');

    // Check requirements
    checkRequirements();

    // Get repository information
    const repoInfo = getRepoInfo();

    // Build Docker image if needed
    buildDockerImage();

    // Run container
    runContainer(repoInfo);
}

// Run the tool
main();
