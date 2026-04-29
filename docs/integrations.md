# Integrations

Agent-Elno-specific configuration snippets for common external systems.
These are not setup guides — they cover only what Agent-Elno requires from each integration.

> **Reverse proxy?** If you place a reverse proxy in front of the services, update
> `PublicUrl.Api` and `PublicUrl.App` in `system-config/system.json` to the external HTTPS URLs.
> See [Public URL After Proxying](#important-public-url-after-proxying) for details.

---

## Generic (Ollama, LiteLLM, and other OpenAI-compatible providers)

Use type `Generic` for any endpoint that speaks the OpenAI `/v1/chat/completions` API —
this includes Ollama, LiteLLM, vLLM, LocalAI, and similar.

**Ollama:**

```json
{
  "name": "Ollama",
  "description": "Local Ollama instance",
  "type": "Generic",
  "baseUrl": "http://localhost:11434",
  "apiKey": "",
  "isActive": true,
  "supportedModels": ["qwen2.5:14b", "nomic-embed-text"]
}
```

**LiteLLM proxy:**

```json
{
  "name": "LiteLLM",
  "description": "LiteLLM proxy",
  "type": "Generic",
  "baseUrl": "http://localhost:4000",
  "apiKey": "your-litellm-master-key",
  "isActive": true,
  "supportedModels": ["gpt-4o-mini", "qwen2.5:14b"]
}
```

**Notes:**
- `baseUrl` must be the root of the OpenAI-compatible API — `/v1` is appended automatically if missing
- `apiKey` can be empty for local instances that don't require authentication
- `supportedModels` is used to match a requested model to a server — list all models you want to use
- For embeddings, set `Kernel.Embedding.Server` in `kernel.json` to this server's name

---

## OpenAI

```json
{
  "name": "OpenAI",
  "description": "OpenAI API",
  "type": "OpenAi",
  "baseUrl": "https://api.openai.com",
  "apiKey": "sk-...",
  "isActive": true,
  "supportedModels": ["gpt-4.1", "gpt-4o-mini"]
}
```

---

## Anthropic API

The legal-on-server route to Claude — calls go to `api.anthropic.com` over HTTPS using the API key.
Use this on any shared / production host.

```json
{
  "name": "Anthropic",
  "description": "Anthropic Claude API",
  "type": "Anthropic",
  "baseUrl": "https://api.anthropic.com",
  "apiKey": "sk-ant-...",
  "isActive": true,
  "supportedModels": ["claude-opus-4-7", "claude-sonnet-4-6", "claude-haiku-4-5"]
}
```

---

## Claude Code CLI

The Claude Code CLI route lets the platform invoke Claude **without an API key** by spawning the
local `claude` binary, piggybacking on its own login (typically a Claude paid subscription).

> **⚠️ Personal-machine only.** Per Anthropic's Terms of Service, the subscription-tied
> `claude` CLI login is permitted on **your own developer machine** — not on a shared or
> production server. For server installs, use the **Anthropic API** server type above instead.
> The CLI route is intended for users who run Agent-Elno locally on the same workstation
> they already use Claude Code on.

The default config ships a disabled placeholder at `config/servers/claude-cli.json` — fill it
in and flip `isActive` to `true` once the prerequisites below are met.

### Prerequisites on the host

1. Install Claude Code on the same machine where the API runs and ensure it is on `PATH`
   (`which claude` should resolve).
2. Log in once **as the user the API runs as** (the `agent-elno` system user on a default Linux
   install): `sudo -u agent-elno claude login` — this writes the auth token into that user's
   `~/.claude/` folder, which is what `ClaudeCliProvider` will use.
3. Verify with a smoke test: `sudo -u agent-elno claude -p "ping"` should print a model response.

### Server config

```json
{
  "name": "Claude CLI",
  "description": "Local Claude Code CLI",
  "type": "ClaudeCli",
  "baseUrl": "",
  "apiKey": "",
  "isActive": true,
  "supportedModels": ["claude-opus-4-7", "claude-sonnet-4-6"]
}
```

`baseUrl` and `apiKey` are intentionally empty — the CLI handles auth itself. `supportedModels`
lists the versioned model IDs you want to route through this server; agents that target one of
those IDs will be dispatched to `ClaudeCliProvider` automatically.

### How task workers call back into the platform

When a CLI worker runs a task, the API spawns `claude -p <prompt> --mcp-config <tempfile>` with
an MCP config that points the spawned process at the API's **internal** MCP endpoint
(`/mcp/agent`, JWT-protected, embedded in `DataPS.AI.Api`). This is a different MCP server than
the standalone `DataPS.AI.MCP` service on port 5300 (which is for VS Code). No extra setup — the
API generates the per-agent JWT and writes the temp config on the fly.

---

## Nginx (Reverse Proxy + SSL)

Agent-Elno requires WebSocket support for SignalR (chat streaming and task updates).
The critical headers are `Upgrade` and `Connection`.

```nginx
# /etc/nginx/sites-available/dataps-ai

# Web UI
server {
    listen 443 ssl;
    server_name ai.example.com;

    ssl_certificate     /etc/ssl/certs/ai.example.com.crt;
    ssl_certificate_key /etc/ssl/private/ai.example.com.key;

    location / {
        proxy_pass http://localhost:5200;
        proxy_http_version 1.1;

        # Required for SignalR (WebSocket + Server-Sent Events)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Prevent SignalR long-polling timeouts
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}

# API
server {
    listen 443 ssl;
    server_name api.ai.example.com;

    ssl_certificate     /etc/ssl/certs/ai.example.com.crt;
    ssl_certificate_key /etc/ssl/private/ai.example.com.key;

    location / {
        proxy_pass http://localhost:5100;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}

# MCP — DO NOT EXPOSE
# The MCP server is an authenticated proxy that grants full API access
# without user login. Never expose it to the public internet.
# It should only be reachable from your local network or via VPN.

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name ai.example.com api.ai.example.com;
    return 301 https://$host$request_uri;
}
```

**After adding the proxy**, update `PublicUrl.Api` and `PublicUrl.App` in `system-config/system.json`
to the external HTTPS URLs. See the [Public URL](#important-public-url-after-proxying) section below.

---

## Traefik (Reverse Proxy + SSL)

If Traefik is already running in your environment, add Agent-Elno as file-based routes.

Create `/etc/traefik/conf.d/dataps-ai.yml`:

```yaml
http:
  routers:
    dataps-ai-app:
      rule: "Host(`ai.example.com`)"
      entryPoints: ["websecure"]
      tls: {}
      service: dataps-ai-app

    dataps-ai-api:
      rule: "Host(`api.ai.example.com`)"
      entryPoints: ["websecure"]
      tls: {}
      service: dataps-ai-api

    # MCP — DO NOT EXPOSE
    # The MCP server is an authenticated proxy that grants full API access
    # without user login. Never expose it to the public internet.
    # It should only be reachable from your local network or via VPN.

  services:
    dataps-ai-app:
      loadBalancer:
        servers:
          - url: "http://localhost:5200"

    dataps-ai-api:
      loadBalancer:
        servers:
          - url: "http://localhost:5100"
```

Traefik handles WebSocket upgrade automatically — no additional middleware needed.

**After adding the proxy**, update `PublicUrl.Api` and `PublicUrl.App` in `system-config/system.json`
to the external HTTPS URLs. See the [Public URL](#important-public-url-after-proxying) section below.

---

## Important: Public URL After Proxying

Regardless of which proxy you use, the public URLs must reflect the **external** address
after SSL termination:

| Variable | Value after proxying |
|----------|---------------------|
| `PublicUrl.Api` (in `system-config/system.json`) | `https://api.ai.example.com` |
| `PublicUrl.App` (in `system-config/system.json`) | `https://ai.example.com` |

The `AiConfig__Sdk__ApiUri` used for internal App→API and MCP→API communication
should remain `http://localhost:5100/` — it does not need to change.

Restart all services after config changes: `systemctl restart dataps-ai-api dataps-ai-app dataps-ai-mcp`
