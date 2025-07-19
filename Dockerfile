FROM node:20-alpine

# Install dependencies in one layer
RUN apk add --no-cache git bash openssh

WORKDIR /app

RUN npm install -g @anthropic-ai/claude-code
RUN claude config set theme dark

CMD ["tail", "-f", "/dev/null"]