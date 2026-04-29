# Configuration Reference

All configuration lives in `/opt/dataps-ai/config/`.
The installer offers three configuration modes:

| Mode | ConfigSync | ConfigRepoUrl | How it works |
|------|-----------|---------------|-------------|
| **Import once** | `0` | — | Config is imported into the database once at startup. Manage everything through the App UI afterwards. |
| **Config by file** | `300` | — | The API re-reads JSON files from `config/` every `ConfigSync` seconds. Edit files directly. |
| **Config by git** | `300` | set | The API clones a git repo into `config/` and re-syncs every `ConfigSync` seconds. |

Only `.env` changes require a service restart.

---

## Environment Files

Each service has its own `.env` file in the install root (`/opt/dataps-ai/`).

### `.env.api`

```env
ASPNETCORE_URLS=http://0.0.0.0:5100
AiConfig__BaseDir=/opt/dataps-ai/data
ConnectionStrings__aiapidb=Filename=/opt/dataps-ai/data/db/aiapidb.db
AiConfig__BaseUri=http://localhost:5100
# AiConfig__ConfigRepoUrl=https://github.com/you/my-dataps-config.git
# AiConfig__ConfigCachePath=/opt/dataps-ai/config
```

| Variable | Description |
|----------|-------------|
| `AiConfig__BaseDir` | Root directory for databases, workspaces, and logs |
| `ConnectionStrings__aiapidb` | SQLite path for all data (users, roles, tasks, agents, config, chat, logs) |
| `AiConfig__BaseUri` | Internal base URL of the API |
| `AiConfig__ConfigRepoUrl` | Git mode only — repo URL to clone config from |
| `AiConfig__ConfigCachePath` | Git mode only — local directory for the cloned repo (default: `config/`) |

### `.env.app`

```env
ASPNETCORE_URLS=http://0.0.0.0:5200
AiConfig__Sdk__ApiUri=http://localhost:5100/
```

### `.env.mcp`

```env
ASPNETCORE_URLS=http://0.0.0.0:5300
AiConfig__Sdk__ApiUri=http://localhost:5100/
AiConfig__Sdk__Username=agent
AiConfig__Sdk__Password=password
```

| Variable | Description |
|----------|-------------|
| `AiConfig__Sdk__ApiUri` | API URL for SDK calls |
| `AiConfig__Sdk__Username` | Service account username |
| `AiConfig__Sdk__Password` | Service account password — change after install |

---

## System Config (`system-config/`)

JSON arrays loaded into the database at startup. Each entry is a `category/group/key` triple.

### `system.json` — Workers & Maintenance

The manager is a scheduled agent (the `manager-heartbeat` trigger), not a hard-coded worker —
its cadence is the cron expression on its trigger, not a system-config key. The keys below cover
the actual hosted workers and platform-level windows.

| Group | Key | Default | Description |
|-------|-----|---------|-------------|
| Worker | `Scheduler` | `60` | Cron trigger evaluation interval (seconds) |
| Worker | `DatabaseCleanup` | `900` | DB cleanup interval (seconds) |
| Worker | `WorkspaceCleanup` | `21600` | Workspace cleanup interval (seconds) |
| Worker | `MetricsCleanup` | `21600` | Metrics cleanup interval (seconds) |
| Worker | `ConfigSync` | `300` | Config sync interval (seconds) |
| Worker | `WorkspaceRetention` | `7` | Days to keep workspaces of completed tasks |
| Maintenance | `Start` | *(empty)* | Maintenance window start (HH:mm, server local time; empty = disabled) |
| Maintenance | `End` | *(empty)* | Maintenance window end (HH:mm, server local time; empty = disabled) |
| PublicUrl | `Api` | *(set by installer)* | Public API URL for mobile / QR |
| PublicUrl | `App` | *(set by installer)* | Public App URL |

### `kernel.json` — LLM Engine

| Group | Key | Default | Description |
|-------|-----|---------|-------------|
| Embedding | `Model` | *(set by installer)* | Embedding model name |
| Embedding | `Server` | *(empty)* | Server name; empty = auto-discover |
| RateLimit | `BackoffSeconds` | `60,120,180,240,300` | Retry backoff sequence (comma-separated) |
| Timeout | `LlmCall` | `1800` | HTTP timeout for LLM calls (seconds) |
| Timeout | `LlmStream` | `300` | First-token timeout for streaming (seconds) |
| Execution | `Temperature` | `0.7` | Default LLM temperature |

---

## LLM Servers (`servers/`)

Each JSON file in this folder defines one LLM server endpoint.

```json
{
  "name": "My Server",
  "description": "LLM provider for model access",
  "type": "Generic",
  "baseUrl": "http://localhost:11434",
  "apiKey": "",
  "apiVersion": "",
  "isActive": true,
  "supportedModels": [],
  "capabilities": [],
  "configuration": {}
}
```

| Field | Description |
|-------|-------------|
| `name` | Display name |
| `type` | `Generic`, `OpenAI`, or `Anthropic` — see below |
| `baseUrl` | Root URL of the provider API |
| `apiKey` | API key (empty for local instances without authentication) |
| `apiVersion` | API version string — required for `OpenAI` type (e.g. `2025-04-01-preview`) |
| `isActive` | Whether the server is available for use |
| `supportedModels` | Models available on this server — used to route model requests |
| `capabilities` | Reserved for future use |
| `configuration` | Reserved for future use |

### Server Types

| Type | Use for | Behaviour |
|------|---------|-----------|
| `Generic` | LiteLLM, Ollama, vLLM, any OpenAI-compatible API | Appends `/v1` to `baseUrl` if missing. Uses standard OpenAI client. |
| `OpenAI` | Azure OpenAI / Azure AI Foundry | Uses the Azure OpenAI client with `apiVersion`. The model name is sent as the **deployment name**. |
| `Anthropic` | Anthropic API (cloud) | HTTP calls to `api.anthropic.com` using the `apiKey`. Use this on a server — it is the only legal Claude path for shared/production hosts. |
| `ClaudeCli` | Local Claude Code CLI | Spawns the `claude` CLI per execution. No `baseUrl` or `apiKey` — authentication piggybacks on the CLI's own login. **Requires the `claude` binary to be installed on the host and logged in as the service user**, and per Anthropic's TOS the subscription-tied login is only permitted on your own developer machine, not on a shared/production server. See [integrations.md](integrations.md#claude-code-cli) for setup. Set `supportedModels` to the versioned model IDs you want to route (e.g. `claude-opus-4-7`, `claude-sonnet-4-6`). |

**Azure AI Foundry example:**

```json
{
  "name": "Azure Foundry",
  "description": "Azure AI Foundry endpoint",
  "type": "OpenAI",
  "baseUrl": "https://your-resource.cognitiveservices.azure.com",
  "apiKey": "your-api-key",
  "apiVersion": "2025-04-01-preview",
  "isActive": true,
  "supportedModels": ["gpt-4.1", "o4-mini"],
  "capabilities": [],
  "configuration": {}
}
```

You can add multiple server files to configure fallback or specialized endpoints.

---

## Repositories (`repositories/`)

Each JSON file defines a Git repository that can be linked to projects.
The agent clones linked repositories into task workspaces for coding tasks.

```json
{
  "name": "My App",
  "gitUrl": "git@github.com:org/my-app.git",
  "description": "Main application repository",
  "isActive": true,
  "defaultBranch": "main"
}
```

| Field | Description |
|-------|-------------|
| `name` | Display name — used to link from projects |
| `gitUrl` | SSH or HTTPS clone URL |
| `description` | What this repository contains |
| `isActive` | Whether the repository is available for use |
| `defaultBranch` | Branch to check out (e.g. `main`, `develop`) |

> The server must have SSH access to the repository.
> See [Quick Start — Step 4](quickstart.md#step-4--try-it-out) for SSH key setup.

---

## Projects (`projects/`)

Each sub-folder contains a `project.json` and an optional `project_info.md` with extended context.

```json
{
  "name": "My Project",
  "description": "What this project is about",
  "kanbanColumns": ["Backlog", "Ready", "InProgress", "Review", "Done"],
  "repositories": ["My App"],
  "parameters": {
    "boardColor": "#3f51b5"
  }
}
```

| Field | Description |
|-------|-------------|
| `name` | Display name |
| `description` | What this project is about |
| `kanbanColumns` | Ordered list of Kanban board columns |
| `repositories` | List of repository **names** (must match `name` in `repositories/`); the workspace branch comes from the repository's `defaultBranch` field |
| `parameters` | Free-form key-value pairs passed to the agent as context. Reserved keys: `boardColor` (hex board accent). |

### Project Prompt (`project_info.md`)

Place a `project_info.md` file next to `project.json` to give agents project-specific context.
This content is injected into every manager step prompt as a **## Project Context** section.

Use it to tell agents:
- Where the code lives and which commands to run
- Which files to read before writing code (conventions, architecture docs)
- Tech stack, frameworks, and constraints
- Repository layout and important paths

**Example** (`projects/my-app/project_info.md`):

```markdown
All code lives in the main repository. Run all dotnet commands from the repo root.

**Main repository**: repositories/my-app
**BEFORE writing any code, you MUST read**: repositories/my-app/instructions.md

Tech stack: .NET 10, Blazor Server, SQLite, Semantic Kernel
Test command: dotnet test
Build command: dotnet build
```

> **Tip:** The more specific the project prompt, the fewer mistakes agents make.
> Point them to your coding conventions, folder structure, and naming rules.
> If `project_info.md` is absent or empty, no project context is injected.

---

## Triggers (`triggers/`)

Triggers run an agent with a skill on a cron schedule.

```json
{
  "name": "Nightly Summary",
  "agentName": "Personal Agent",
  "skillName": "daily-summary",
  "projectName": "My Project",
  "cronExpression": "0 22 * * *",
  "enabled": true
}
```

| Field | Description |
|-------|-------------|
| `agentName` | Must match an agent `name` in `config/agents/` |
| `skillName` | Must match a skill `name` (from YAML frontmatter, or filename if omitted) |
| `cronExpression` | Standard 5-field cron expression |
| `projectName` | Optional — provides project context to the agent |
| `enabled` | `true` to activate, `false` to configure without running |

---

## Config from Git

When using **Config by git** mode, the API clones the configured repo into `ConfigCachePath`
(defaults to `config/`) and re-syncs every `ConfigSync` seconds.

The repo structure must mirror the `config/` directory layout:

```
├── agents/
├── projects/
├── repositories/
├── servers/
├── skills/
├── triggers/
└── system-config/
```

During installation the installer can optionally initialize the repo with default
config files, commit, and push — so you start with a working baseline.

---

## Advanced: Agent Shell Access

By default, the `agent-elno` system user has no login shell and no sudo privileges.
The agent can only read/write files inside `/opt/dataps-ai/`.

Power users and developers can grant the agent **root-level access** so it can
install packages, manage services, edit system files, and run arbitrary commands.

> **Not recommended for beginners or production systems.**
> This gives the agent full control over the server.

### Enable sudo for the agent user

```bash
# Allow passwordless sudo for the agent-elno user
echo 'agent-elno ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/agent-elno
chmod 440 /etc/sudoers.d/agent-elno
```

### Give the agent a real shell

The installer creates the user with `/usr/sbin/nologin`. Change it to a proper shell:

```bash
usermod -s /bin/bash agent-elno
```

### What this enables

With shell + sudo, the agent can:

- Install system packages (`apt install ...`)
- Manage systemd services
- Edit files outside `/opt/dataps-ai/`
- Run Docker commands (if Docker is installed)
- Execute deployment scripts

### Reverting

```bash
rm /etc/sudoers.d/agent-elno
usermod -s /usr/sbin/nologin agent-elno
```
