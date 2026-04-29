# Claude Code CLI Setup

The Claude Code CLI route lets Agent-Elno run Claude **without an API key** by spawning the
local `claude` binary on the host. This piggybacks on the CLI's own login, which means it's
free to use if you already pay for a Claude subscription — but it has a hard legal caveat
you need to read first.

> **⚠️ Personal-machine only.**
> Per Anthropic's Terms of Service, the subscription-tied `claude` CLI login is permitted on
> **your own developer machine** — not on a shared, multi-user, or production server.
> If you are running Agent-Elno on a server (anything that isn't your personal workstation),
> use the [Anthropic API server type](integrations.md#anthropic-api) with an API key instead.
> The two server types are interchangeable from the platform's point of view; only the
> licensing and the auth mechanism differ.

This guide assumes you're running Agent-Elno on your own dev box and want to wire up the CLI.

---

## 1. Install Claude Code on the host

Follow Anthropic's installer for your OS. After installation, verify the binary is on `PATH`:

```bash
which claude
claude --version
```

If `which claude` prints nothing, fix `PATH` first — `ClaudeCliProvider` resolves the binary
the same way (`PATH` lookup), so if your shell can't find it, neither can the platform.

---

## 2. Log in as the user the API runs as

`ClaudeCliProvider` spawns `claude` as the API process user, which means the CLI's auth state
must live in **that user's home directory**.

On a default Linux install of Agent-Elno, the API runs as the `agent-elno` system user:

```bash
sudo -u agent-elno claude login
```

Follow the browser flow to complete the login. The token is written into
`/opt/dataps-ai/.claude/` (or wherever the user's home is configured).

> If you installed Agent-Elno under your own user account (e.g. you cloned the repo and run
> `dotnet run` interactively), just `claude login` as yourself — no `sudo` needed.

Smoke-test the login:

```bash
sudo -u agent-elno claude -p "ping"
```

You should see a normal model response. If you get an auth error, the login didn't write to the
right home directory — re-run step 2 making sure you're impersonating the correct user.

---

## 3. Enable the bundled `claude-cli` server

The default config ships a **disabled** ClaudeCli server file at
`config/servers/claude-cli.json`. Open it and:

1. Set `"isActive": true`.
2. Adjust `supportedModels` to the model IDs you actually want to route. Use versioned IDs —
   the platform passes them straight to the CLI:
   ```json
   "supportedModels": ["claude-opus-4-7", "claude-sonnet-4-6"]
   ```
3. Save the file.

If you're on import-once or git config mode, follow your usual sync flow. For file-based config,
the change picks up automatically on the next `ConfigSync` cycle (default 5 min).

---

## 4. Point an agent at a Claude model

Edit any agent JSON (e.g. `config/agents/developer.json`) and set its `model` to one of the IDs
you listed in `supportedModels`:

```json
{
  "name": "Developer Agent",
  "role": "developer",
  "model": "claude-sonnet-4-6",
  "...": "..."
}
```

The router resolves the model → server by walking active servers in order. Any agent whose
`model` matches an entry in the ClaudeCli server's `supportedModels` will be dispatched through
`ClaudeCliProvider` (which spawns `claude`) instead of through the OpenAI-compatible HTTP path.

---

## 5. Verify end-to-end

1. Open the Web UI → **Monitor → Actions**.
2. Trigger something that runs through the agent you just switched (a chat message, a
   manager-heartbeat fire, or a task wakeup).
3. The action log entry should show your Claude model ID under **Model** and a non-error status.

If the call fails with a `claude: command not found`-flavoured error, the API user's `PATH`
doesn't see the binary — fix `PATH` for that user (e.g. via `~/.profile` or the systemd unit's
`Environment=PATH=...`).

---

## What this looks like at runtime

When a task worker uses Claude CLI, the API:

1. Generates a per-agent JWT for the platform's **internal** MCP endpoint (`/mcp/agent`,
   embedded in `DataPS.AI.Api`).
2. Writes a temp MCP config file that points the spawned process at that endpoint with the JWT
   as a bearer token.
3. Spawns `claude -p <prompt> --mcp-config <tempfile>` in the task workspace directory.
4. Captures stdout, deletes the temp config, releases the worker slot.

This is a different MCP server than the standalone `DataPS.AI.MCP` service on port 5300 (which
is an auth proxy for VS Code Copilot and other editor integrations) — the two share a name but
solve different problems. You don't need to touch port 5300 for the Claude CLI flow to work.
