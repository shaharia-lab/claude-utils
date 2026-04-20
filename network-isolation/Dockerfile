FROM node:20-slim

RUN npm install -g @anthropic-ai/claude-code

RUN apt-get update && apt-get install -y git curl ca-certificates && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node
WORKDIR /workspace

ENTRYPOINT ["entrypoint.sh"]
