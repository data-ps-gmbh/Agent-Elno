# Architecture Overview

Agent-Elno is a three-service platform that runs entirely on a single Linux server.
The API is the only service with direct database access.
App and MCP communicate exclusively through the API — they never touch SQLite or config directly.

---

## Services

```
┌─────────────────────┐          ┌─────────────────────┐
│    Your Browser     │          │  VS Code / Copilot  │
└─────────┬───────────┘          └─────────┬───────────┘
          │ HTTP / SignalR                 │ MCP protocol
          ▼                                ▼
┌─────────────────────┐          ┌─────────────────────┐
│  App  (port 5200)   │          │  MCP  (port 5300)   │
│  Blazor Server      │          │  .NET MCP Server    │
│  Kanban · Chat      │          │  Tasks · Review     │
└─────────┬───────────┘          └─────────┬───────────┘
          │ SDK / REST                     │ SDK / REST
          └──────────────┬─────────────────┘
                         ▼
          ┌──────────────────────────────┐
          │       API  (port 5100)       │
          │    ASP.NET Core — JWT Auth   │
          │  REST · Operator · Scheduler │
          │  SignalR · Semantic Kernel   │
          │          SQLite              │
          └──────────────┬───────────────┘
                         │ OpenAI API
                         ▼
                   LLM Provider
                 (Generic / OpenAi)
```

---

## Component Responsibilities

### API (`DataPS.AI.Api`)

The central service. Everything else talks to it.

- **REST API** — CRUD for projects, tasks, agents, skills, config, users
- **JWT authentication** — HS256, 1h access token + 7d refresh token
- **Operator worker** — background loop that picks and executes tasks
- **Scheduler worker** — evaluates cron triggers, runs agent + skill, logs result
- **SignalR hub** — real-time updates for chat and task status
- **Semantic Kernel** — orchestrates LLM calls, function calling, embeddings
- **Config loader** — reads `config/` from disk (or git) at startup and on sync interval

### App (`DataPS.AI.App`)

The web UI and mobile entry point.

- **Blazor Server** — server-side rendering with Blazor components
- **Kanban board** — drag-and-drop task management
- **Chat** — real-time LLM conversations
- **Settings** — manage agents, skills, servers, users, projects
- **Monitoring** — action log (all LLM calls) and trigger log (scheduler history)

### MCP (`DataPS.AI.MCP`)

VS Code integration via the Model Context Protocol.

- Exposes tasks, projects, and review actions as MCP tools
- Allows reviewing and approving agent output from inside VS Code
- Authenticates against the API using the SDK

---

## Data Flow — Task Execution

```
User creates task
      │
      ▼
API: task stored in SQLite (state = Todo)
      │
      ▼  (every 30s)
Operator worker picks task
      │
      ├─ DetermineRole   → select agent
      ├─ PlanStep        → decide next action
      ├─ ComposePrompt   → build LLM prompt
      ├─ LLM call        → Semantic Kernel + tools
      ├─ EvaluateResult  → done / continue / error
      └─ SummarizeStep   → append to task log
      │
      ▼ (when done or turn limit hit)
SummarizeTask → task moved to Review
      │
      ▼
User reviews result → Approve (Done) or Reject (Todo)
```

---

## Data Storage

All persistent data lives under `AiConfig__BaseDir` (default: `/opt/dataps-ai/data/`).

```
data/
├── db/
│   └── aiapidb.db        # all data: users, roles, tasks, projects, agents, config, chat, logs, metrics
└── workspaces/
    └── <task-id>/        # per-task working directory (git repos, files, etc.)
```

Agent-Elno uses **SQLite** for simplicity and zero-dependency operation.
No external database server is required.

---

## Config Loading

```
/opt/dataps-ai/config/
├── system-config/    → loaded into DB at startup
├── servers/          → LLM server registry
├── agents/           → agent definitions + system prompts
├── skills/           → prompt templates
├── projects/         → project definitions
└── triggers/         → scheduled triggers
```

Config is re-synced from disk (or git) every `ConfigSync` seconds (default: 5 min).
Changes do not require a service restart except for `.env` changes.

---

## Security Model

- All API endpoints require a valid JWT except `/auth/login` and `/health`
- The App authenticates users via login (JWT)
- The MCP server authenticates with a service account (`AiConfig__Sdk__*`)
- LLM provider config (including API keys) is defined in `config/servers/` and synced to the database by ConfigSync
- Workspaces run under the `agent-elno` system user with no sudo access by default

> **⚠️ Network exposure:** Agent-Elno is designed to run on a private network.
> We do not recommend exposing the services to the public internet.
> If you choose to do so, securing the deployment (firewall rules, reverse proxy with TLS,
> rate limiting, etc.) is entirely your responsibility.
