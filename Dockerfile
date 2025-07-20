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

# Configure SSH for GitHub (skip host key verification for convenience)
RUN echo "Host github.com" > /home/developer/.ssh/config && \
    echo "  StrictHostKeyChecking no" >> /home/developer/.ssh/config && \
    echo "  UserKnownHostsFile /dev/null" >> /home/developer/.ssh/config && \
    chown developer:developer /home/developer/.ssh/config && \
    chmod 600 /home/developer/.ssh/config

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

# Create a wrapper script that can handle SSH socket permissions
USER root
RUN echo '#!/bin/bash' > /app/wrapper.sh && \
    echo 'set -e' >> /app/wrapper.sh && \
    echo '# Fix SSH socket permissions if needed' >> /app/wrapper.sh && \
    echo 'if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then' >> /app/wrapper.sh && \
    echo '    SOCKET_DIR=$(dirname "$SSH_AUTH_SOCK")' >> /app/wrapper.sh && \
    echo '    chown -R developer:developer "$SOCKET_DIR" 2>/dev/null || true' >> /app/wrapper.sh && \
    echo '    chown developer:developer "$SSH_AUTH_SOCK" 2>/dev/null || true' >> /app/wrapper.sh && \
    echo 'fi' >> /app/wrapper.sh && \
    echo '# Fix OpenCode directory permissions' >> /app/wrapper.sh && \
    echo 'mkdir -p /home/developer/.local/share/opencode' >> /app/wrapper.sh && \
    echo 'mkdir -p /home/developer/.local/state' >> /app/wrapper.sh && \
    echo 'mkdir -p /home/developer/.config/opencode' >> /app/wrapper.sh && \
    echo 'chown -R developer:developer /home/developer/.local' >> /app/wrapper.sh && \
    echo 'chown -R developer:developer /home/developer/.config' >> /app/wrapper.sh && \
    echo '# Switch to developer user and run entrypoint' >> /app/wrapper.sh && \
    echo 'exec su -c "/app/entrypoint.sh" developer' >> /app/wrapper.sh && \
    chmod +x /app/wrapper.sh

CMD ["tail", "-f", "/dev/null"]