# OPENCODE BOX

I want to use some kind of Tool for terminal. It would be coded in JS, the idea is to run this code inside any project in my machine, so probably we will need NPM for this tool. Once I call the `opencodebox` it should do the following:

1) Build the image for the container above in case it doesn't exist
2) Run an instance of the container
3) Copy github user credentials inside the container (fail in case no credentials are found)
4) Copy config folders from opencode to the container as same folder `~/.local/share/opencode` and `~/.config/opencode` to the same paths. 
5) Grab project folder github config path and clone the repo inside the container
6) Checkout to the current branch from the host machine inside the project in the container.

The intent is to have some properties builded in the container:

- Install node:20-alpine in there
- Install opencode inside the container with `npm install -g opencode-ai`
- Create a user the container that isn't sudoer

How do I expect to run this tool:

- Inside a github project folder I should be able to just call the `opencodebox` tool and it does all the above automatically

Any additional informations regarding OpenCode ould be found in their docs:

[OpenCode Docs](https://opencode.ai/docs/)
[OpenCode CLI commands](https://opencode.ai/docs/cli/)
[OpenCode - Different modes for different use cases](https://opencode.ai/docs/modes/)
[Set custom instructions for OpenCode](https://opencode.ai/docs/rules/)
[Using the OpenCode JSON config](https://opencode.ai/docs/config/)
[Configuring an LLM provider and model](https://opencode.ai/docs/models/)
[Open Code - Troubleshooting](https://opencode.ai/docs/troubleshooting/)