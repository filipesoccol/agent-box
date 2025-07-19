# AGENT BOX



## Quick Start

1. **Clone and navigate to the repository:**
   ```bash
   git clone git@github.com:filipesoccol/agent-box.git
   cd agent-box
   ```

## Alternative Docker Commands

**Build the image manually:**
```bash
docker build -t shh-dev .
```

**Run Container passing your local git credentials**

```bash
docker run -it --rm \
   -v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK \
   -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK \
   shh-dev /bin/bash
```

## Docker Environment Features

- **Ultra Lightweight**: Based on Alpine Linux with Node.js 20 (~40MB total)
- **IDE Integration**: Use ANY IDE Containers for seamless development
- **Isolated Environment**: Completely isolated Node.js environment with no external port exposure
- **Secure Development**: All development happens inside the container without access to your machine files
