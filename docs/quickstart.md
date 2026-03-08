# Quick Start Guide

Get Agent-Elno running on a fresh Linux server in under 10 minutes.

---

## Prerequisites

- A server running **Debian 12+** or **Ubuntu 22.04+**
- Root / sudo access
- An **OpenAI-compatible LLM endpoint** reachable from the server
  (any OpenAI-compatible API like Ollama or LiteLLM, or OpenAI directly)
- Ports **5100**, **5200**, **5300** available (or your chosen alternatives)

> **No Docker required.** Agent-Elno ships as self-contained binaries and runs as native systemd services.
> No runtime installation needed.

---

## Step 1 — Install

**One-line install** — downloads the latest release, extracts it, and runs the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/data-ps-gmbh/Agent-Elno/main/get-agent-elno.sh | sudo bash
```

> **Manual download:** Go to the [Releases page](https://github.com/data-ps-gmbh/Agent-Elno/releases),
> download the latest `dataps-ai-*-linux-x64.tar.gz`, then run:
>
> ```bash
> tar -xzf dataps-ai-*-linux-x64.tar.gz
> cd dataps-ai-*-linux-x64
> sudo bash scripts/install.sh
> ```

---

The installer will prompt you for:

| Prompt | Example | Notes |
|--------|---------|-------|
| API port | `5100` | REST API |
| App port | `5200` | Web UI |
| Install MCP server | `y/N` | Optional — VS Code integration |
| MCP port | `5300` | Only if MCP enabled |
| Llm Server name | `My LiteLLM` | Display name in UI |
| Provider URL | `http://localhost:4000` | Base URL of your LLM API |
| API key | *(leave empty if not required)* | Required for OpenAI |
| Default model | `gpt-5.1-codex-mini` | Must exist on your provider |
| Embedding model | `nomic-embed-text` | Recommended — enables semantic memory search |
| Public API URL | `http://192.168.1.10:5100` | Used for mobile app / QR codes |
| Public App URL | `http://192.168.1.10:5200` | Used for external links |

After confirming, the installer will:
1. Create the system user `agent-elno`
2. Install files to `/opt/dataps-ai/`
3. Write `.env` files with your settings
4. Install and start the systemd services (API + App, optionally MCP)

---

## Step 2 — Verify the Services

```bash
systemctl status dataps-ai-api dataps-ai-app
```

Both should show **active (running)**. If a service failed, check the logs:

```bash
tail -50 /opt/dataps-ai/logs/DataPS.AI.Api_$(date +%Y%m%d).log
```

---

## Step 3 — Open the Web UI

Navigate to `http://<your-server>:5200` in your browser.

**Default credentials:**

| User | Password | Purpose |
|------|----------|---------|
| `admin` | `password` | Web UI login |
| `agent` | `password` | Internal service account (used by API/Agent/MCP) |

> **Change both passwords immediately after first login.**
> - `admin` — via **Profile → Change Password** in the Web UI
> - `agent` — via **Profile → Change Password**, then update `AiConfig__Sdk__Password` in `.env.mcp` and restart the services

---

## Step 4 — Try It Out

**Chat** — open the **Chat** page and talk to Elno directly.

**Autonomous coding** — set up a project first:

1. Generate an SSH key on the server and add the public key to your Git server / hosting account:
   ```bash
   sudo -u agent-elno ssh-keygen -t ed25519 -N "" -f /opt/dataps-ai/.ssh/id_ed25519
   cat /opt/dataps-ai/.ssh/id_ed25519.pub
   ```
2. Add a repository — **either via UI or config file:**

   **UI:** Go to **Configuration → Repositories** and add the SSH clone URL (e.g. `git@github.com:org/repo.git`)

   **File-based:** Create `/opt/dataps-ai/config/repositories/my-app.json`:
   ```json
   {
     "name": "My App",
     "gitUrl": "git@github.com:org/my-app.git",
     "description": "Main application repository",
     "isActive": true,
     "defaultBranch": "main"
   }
   ```
3. Create a project and link the repository — **UI or file:**

   **UI:** Go to **Configuration → Projects**, create a project, and select the repository

   **File-based:** Create `/opt/dataps-ai/config/projects/my-project/project.json`:
   ```json
   {
     "name": "My Project",
     "description": "What this project is about",
     "kanbanColumns": ["Backlog", "Ready", "InProgress", "Review", "Done"],
     "repositories": ["My App"],
     "parameters": { "default-branch": "main" }
   }
   ```
4. Open the **Board** in the Web UI
5. Click **+ New Task** — give it a title and description
6. Move the Task to Ready
7. The operator picks it up within 30 seconds — watch it move through *In Progress* → *Review*
8. In the *Review* column, approve or reject the result

    
    
## Runtime dependencies for coding projects
> **Agent-Elno ships no runtime**, SDK, or language toolchain — it is intentionally lean.
> Whether a task succeeds depends entirely on what is available on the server.
> When the agent has shell access it will try to build, test, or run code, so the relevant
> runtimes must already be present.
> At a minimum, **install Python** — most LLM-generated code defaults to Python, and many
> tool-use patterns assume it is available:
> ```bash
> sudo apt install -y python3 python3-pip python3-venv
> ```
> Add any other toolchain your projects require (Node.js, .NET, Java, …) the same way.

---

## Updating

Run the same one-liner again — the installer detects the existing installation and updates in place:

```bash
curl -fsSL https://raw.githubusercontent.com/data-ps-gmbh/Agent-Elno/main/get-agent-elno.sh | sudo bash
```

The installer stops the services, replaces the binaries, and restarts.
Your data and config in `/opt/dataps-ai/data/` and `/opt/dataps-ai/config/` are never touched.

---

## Connecting VS Code

The MCP server at port 5300 is an auth proxy — no credentials needed.
Add a `.vscode/mcp.json` to your project:

```json
{
  "servers": {
    "dataps-ai": {
      "type": "sse",
      "url": "http://<your-server>:5300/sse"
    }
  }
}
```

Copilot and other MCP-aware extensions will pick it up automatically.

---

## Next Steps

- [Configuration reference](configuration.md) — tune the operator, add LLM servers, set up projects
- [Operator process](operator-process.md) — understand how the autonomous loop works
- [Agents & Skills](agents-and-skills.md) — customize agent behavior and prompt templates
