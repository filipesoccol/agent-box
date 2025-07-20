FROM node:20-slim

# Install dependencies in one layer
RUN apt-get update && apt-get install -y \
    git \
    bash \
    openssh-client \
    curl \
    ca-certificates \
    file \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user (without sudo privileges as specified in AGENT.md)
RUN useradd -m -s /bin/bash developer

# Create workspace directory with proper ownership
RUN mkdir -p /workspace && chown developer:developer /workspace

# Create SSH directory with proper permissions for developer user
RUN mkdir -p /home/developer/.ssh && \
    chown developer:developer /home/developer/.ssh && \
    chmod 700 /home/developer/.ssh

# Configure SSH for GitHub with proper host key verification
RUN echo "Host github.com" > /home/developer/.ssh/config && \
    echo "  HostName github.com" >> /home/developer/.ssh/config && \
    echo "  User git" >> /home/developer/.ssh/config && \
    echo "  StrictHostKeyChecking yes" >> /home/developer/.ssh/config && \
    echo "  UserKnownHostsFile /home/developer/.ssh/known_hosts" >> /home/developer/.ssh/config && \
    chown developer:developer /home/developer/.ssh/config && \
    chmod 600 /home/developer/.ssh/config

# Add GitHub's official SSH host keys for security
RUN echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" > /home/developer/.ssh/known_hosts && \
    echo "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=" >> /home/developer/.ssh/known_hosts && \
    echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=" >> /home/developer/.ssh/known_hosts && \
    chown developer:developer /home/developer/.ssh/known_hosts && \
    chmod 644 /home/developer/.ssh/known_hosts

WORKDIR /app

# Install OpenCode globally as specified in AGENT.md
RUN npm install -g opencode-ai

# Copy entrypoint script and set ownership
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown developer:developer /app/entrypoint.sh

# Switch to non-root user
USER developer

# Set default working directory to workspace
WORKDIR /workspace

# Create a secure wrapper script with minimal privilege escalation
USER root
RUN echo '#!/bin/bash' > /app/wrapper.sh && \
    echo 'set -e' >> /app/wrapper.sh && \
    echo '# Validate SSH socket exists and is accessible' >> /app/wrapper.sh && \
    echo 'if [ -n "$SSH_AUTH_SOCK" ]; then' >> /app/wrapper.sh && \
    echo '    if [ ! -S "$SSH_AUTH_SOCK" ]; then' >> /app/wrapper.sh && \
    echo '        echo "ERROR: SSH_AUTH_SOCK is not a valid socket"' >> /app/wrapper.sh && \
    echo '        exit 1' >> /app/wrapper.sh && \
    echo '    fi' >> /app/wrapper.sh && \
    echo 'else' >> /app/wrapper.sh && \
    echo '    echo "ERROR: SSH_AUTH_SOCK not provided"' >> /app/wrapper.sh && \
    echo '    exit 1' >> /app/wrapper.sh && \
    echo 'fi' >> /app/wrapper.sh && \
    echo '# Create OpenCode directories with secure permissions' >> /app/wrapper.sh && \
    echo 'mkdir -p /home/developer/.local/share/opencode' >> /app/wrapper.sh && \
    echo 'mkdir -p /home/developer/.local/state' >> /app/wrapper.sh && \
    echo 'mkdir -p /home/developer/.config/opencode' >> /app/wrapper.sh && \
    echo 'chown -R developer:developer /home/developer/.local' >> /app/wrapper.sh && \
    echo 'chown -R developer:developer /home/developer/.config' >> /app/wrapper.sh && \
    echo 'chmod 700 /home/developer/.local/share/opencode' >> /app/wrapper.sh && \
    echo 'chmod 700 /home/developer/.config/opencode' >> /app/wrapper.sh && \
    echo '# Drop privileges permanently and run entrypoint' >> /app/wrapper.sh && \
    echo 'exec runuser -u developer -- /app/entrypoint.sh' >> /app/wrapper.sh && \
    chmod +x /app/wrapper.sh

CMD ["tail", "-f", "/dev/null"]