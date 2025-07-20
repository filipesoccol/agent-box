# Security Features

OpenCode Box implements multiple security layers to protect your development environment:

## Container Security

- **Read-only root filesystem**: Prevents malicious code from modifying system files
- **Capability dropping**: Removes all unnecessary Linux capabilities
- **No privilege escalation**: Prevents containers from gaining additional privileges
- **Resource limits**: CPU, memory, and process limits prevent resource exhaustion
- **Secure temporary directories**: `/tmp` and `/var/tmp` mounted with `noexec` and `nosuid`

## Network Security

- **SSH host key verification**: GitHub's official SSH host keys are pre-installed and verified
- **Trusted domains only**: Only allows cloning from GitHub, GitLab, Bitbucket, and Azure DevOps
- **Protocol restrictions**: Only HTTPS, SSH, and Git protocols are permitted

## Input Validation

- **Repository URL validation**: Validates and sanitizes all repository URLs
- **Branch name validation**: Prevents command injection through branch names
- **Character filtering**: Removes dangerous characters that could be used for attacks

## SSH Security

- **Read-only SSH socket**: SSH authentication socket is mounted read-only
- **SSH agent validation**: Verifies SSH agent is running and accessible before starting
- **Secure SSH configuration**: Proper SSH client configuration with host key checking

## Git Security

- **Shallow cloning**: Uses `--depth 1` to limit clone size and reduce attack surface
- **Timeout protection**: All Git operations have timeouts to prevent hanging
- **Branch validation**: Validates branch names before checkout operations

## File System Security

- **Non-root user**: All operations run as unprivileged `developer` user
- **Secure permissions**: OpenCode directories created with restrictive permissions (700)
- **Volume isolation**: Temporary state stored in isolated Docker volumes

## Process Security

- **Signal handling**: Graceful shutdown on SIGINT/SIGTERM
- **Process limits**: Maximum 1024 processes per container
- **Automatic cleanup**: Containers and volumes automatically removed after use

## Monitoring and Logging

- **Comprehensive logging**: All operations logged with appropriate levels
- **Error handling**: Detailed error messages without exposing sensitive information
- **Requirement validation**: Pre-flight checks for Docker, Git, and SSH agent

## Best Practices

1. **Keep Docker updated**: Ensure you're running the latest Docker version
2. **Use SSH keys**: Always use SSH key authentication, never passwords
3. **Verify repositories**: Only clone repositories from trusted sources
4. **Monitor logs**: Review container logs for any suspicious activity
5. **Regular updates**: Keep OpenCode Box updated to the latest version

## Reporting Security Issues

If you discover a security vulnerability, please report it to:
- Email: filipe.soccol@gmail.com
- Subject: "OpenCode Box Security Issue"

Please do not create public GitHub issues for security vulnerabilities.