#!/usr/bin/env node

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

// Simple colored output functions
const log = {
    info: (msg) => console.log(`\x1b[34m[INFO]\x1b[0m ${msg}`),
    success: (msg) => console.log(`\x1b[32m[SUCCESS]\x1b[0m ${msg}`),
    warning: (msg) => console.log(`\x1b[33m[WARNING]\x1b[0m ${msg}`),
    error: (msg) => console.log(`\x1b[31m[ERROR]\x1b[0m ${msg}`)
};

function checkRequirements() {
    // Check if Docker is installed
    try {
        execSync('docker --version', { stdio: 'ignore' });
    } catch (error) {
        log.error('Docker is not installed or not in PATH');
        process.exit(1);
    }

    // Check if we're in a git repository
    try {
        execSync('git rev-parse --git-dir', { stdio: 'ignore' });
    } catch (error) {
        log.error('Not in a git repository. Please run opencodebox from inside a git project.');
        process.exit(1);
    }

    // Check SSH agent or credentials
    if (!process.env.SSH_AUTH_SOCK) {
        log.error('SSH agent not found. Please start ssh-agent and add your SSH keys.');
        log.info('Run: eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa');
        process.exit(1);
    }
}

function getRepoInfo() {
    try {
        // Get remote URL
        const remoteUrl = execSync('git config --get remote.origin.url', { encoding: 'utf8' }).trim();

        // Get current branch
        const currentBranch = execSync('git branch --show-current', { encoding: 'utf8' }).trim();

        // Get repository name from URL
        const repoName = path.basename(remoteUrl, '.git');

        return {
            url: remoteUrl,
            name: repoName,
            branch: currentBranch
        };
    } catch (error) {
        log.error('Failed to get repository information');
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

    // Find OpenCode configurations to mount directly
    const configs = findOpenCodeConfigs();

    const dockerArgs = [
        'run', '-it', '--rm',  // --rm ensures automatic cleanup when container exits
        '--name', containerName,
        '-v', `${process.env.SSH_AUTH_SOCK}:${process.env.SSH_AUTH_SOCK}`,
        '-e', `SSH_AUTH_SOCK=${process.env.SSH_AUTH_SOCK}`,
        '-v', `${os.homedir()}/.gitconfig:/home/developer/.gitconfig:ro`,
        '-e', `REPO_URL=${repoInfo.url}`,
        '-e', `REPO_NAME=${repoInfo.name}`,
        '-e', `REPO_BRANCH=${repoInfo.branch}`
    ];

    // Add OpenCode configuration volume mounts
    if (configs.localShare) {
        dockerArgs.push('-v', `${configs.localShare}:/home/developer/.local/share/opencode`);
    }

    if (configs.config) {
        dockerArgs.push('-v', `${configs.config}:/home/developer/.config/opencode`);
    }

    // If we have alternative config but no standard config, mount it to the standard location
    if (configs.alternative && !configs.config) {
        dockerArgs.push('-v', `${configs.alternative}:/home/developer/.config/opencode`);
    }

    // Also create a dedicated volume for OpenCode state that the developer user can write to
    const stateVolume = `opencode-box-state-${timestamp}`;
    dockerArgs.push('-v', `${stateVolume}:/home/developer/.local/state`);

    // Add the image and command
    dockerArgs.push('opencode-box', '/app/wrapper.sh');

    try {
        log.info(`Starting OpenCode environment...`);
        log.info(`Repository: ${repoInfo.name} (${repoInfo.branch})`);

        const child = spawn('docker', dockerArgs, {
            stdio: 'inherit',
            detached: false
        });

        child.on('exit', (code) => {
            if (code === 0) {
                log.success('OpenCode Box session completed');
            } else {
                log.error(`OpenCode Box session ended with exit code ${code}`);
            }

            // Clean up the state volume
            try {
                execSync(`docker volume rm ${stateVolume}`, { stdio: 'pipe' });
            } catch (cleanupError) {
                // Silently ignore cleanup errors
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
