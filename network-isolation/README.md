# Claude Code with Docker Network Isolation

Run Claude Code CLI inside a Docker container with network isolation via a Squid proxy. The agent has no direct internet access — all outbound traffic is filtered through an allowlist of approved domains.

Based on: https://shaharia.com/blog/run-claude-code-docker-network-isolation

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Docker Host                                    │
│                                                 │
│  ┌──────────────┐    ┌────────────────────────┐ │
│  │ agent        │    │ proxy (Squid)          │ │
│  │ (isolated    │───▶│ (isolated + internet   │ │
│  │  network)    │    │  networks)             │ │
│  └──────────────┘    └──────────┬─────────────┘ │
│                                 │               │
└─────────────────────────────────┼───────────────┘
                                  │ Allowlisted domains only
                                  ▼
                             Internet
```

- `isolated` network: internal only, no direct internet
- `internet` network: bridge network used by proxy for outbound access
- Agent routes all traffic through proxy on port `3128`

## Allowed Domains

Configured in `squid.conf`. Defaults:

- `*.anthropic.com`
- `*.github.com`
- `*.googleapis.com`
- `registry.npmjs.org`
- `*.sentry.io`
- `*.statsigapi.net`

Edit `squid.conf` to add or remove domains.

## Prerequisites

- Docker and Docker Compose v2
- Claude Code authenticated on the host (`~/.claude` and `~/.claude.json` must exist)

## Directory Structure

```
network-isolation/
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
├── squid.conf
├── workspace/        # default project directory mounted into agent
└── README.md
```

## Usage

### 1. Start the proxy

```bash
docker compose up -d proxy
```

### 2. Run the agent

```bash
WORKSPACE=/path/to/your/project docker compose run --rm agent \
  -p "your prompt here" --dangerously-skip-permissions
```

Use the default `./workspace` directory:

```bash
docker compose run --rm agent \
  -p "list all files in the workspace" --dangerously-skip-permissions
```

### 3. Stop the proxy

```bash
docker compose down
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `WORKSPACE` | `./workspace` | Host path mounted as `/workspace` in the agent |
| `ANTHROPIC_API_KEY` | _(empty)_ | API key (optional if using OAuth via `~/.claude`) |
| `AGENT_CPUS` | `2` | CPU limit for the agent container |
| `AGENT_MEMORY` | `4g` | Memory limit for the agent container |

Example with all variables:

```bash
WORKSPACE=/home/user/myproject \
ANTHROPIC_API_KEY=sk-ant-... \
AGENT_CPUS=4 \
AGENT_MEMORY=8g \
docker compose run --rm agent -p "refactor main.go" --dangerously-skip-permissions
```

## Running Multiple Agents in Parallel

Each `docker compose run` spawns an isolated container. Run them in parallel pointing at different workspaces:

```bash
WORKSPACE=/projects/alpha docker compose run --rm agent -p "fix tests" --dangerously-skip-permissions &
WORKSPACE=/projects/beta  docker compose run --rm agent -p "update docs" --dangerously-skip-permissions &
wait
```

All agent containers share the single proxy instance.

## How Credentials Work

The `entrypoint.sh` copies OAuth credentials from the read-only host mounts into the container's writable home directory at startup:

| Host (read-only) | Container |
|---|---|
| `~/.claude/.credentials.json` | `/root/.claude/.credentials.json` |
| `~/.claude/settings.json` | `/root/.claude/settings.json` |
| `~/.claude.json` | `/root/.claude.json` |

Host credentials are never modified.

## Rebuilding the Image

After changing the `Dockerfile` or `entrypoint.sh`:

```bash
docker compose build agent
```

## Testing Network Isolation

Verify the agent cannot reach the open internet directly:

```bash
# This should FAIL (not in allowlist)
docker compose run --rm agent -p "use curl to fetch https://example.com" --dangerously-skip-permissions

# This should SUCCEED (anthropic.com is allowed)
docker compose run --rm agent -p "print the claude version" --dangerously-skip-permissions
```

Check proxy logs to see filtered traffic:

```bash
docker compose logs proxy
```
