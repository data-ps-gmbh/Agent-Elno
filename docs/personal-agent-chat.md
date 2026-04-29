# Personal Agent & Chat

The **Personal Agent** is your AI assistant — a persistent, conversational interface for
brain dumps, research, task creation, and general help. Unlike the manager and worker agents
(which process Kanban tasks autonomously in the background), the personal agent is interactive
and responds in real time.

---

## What It Is

The personal agent is a multi-session chat with a fully customizable AI persona.
The persona — tone, name, style, and character — is defined in plain Markdown files
you can replace entirely to make the agent your own.

---

## How Chat Works

```
Your browser
    │ WebSocket (SignalR)
    ▼
ChatHub (API)
    │ builds context (history + memory)
    ▼
LLM (via Semantic Kernel)
    │ response → SignalR → browser
    ▼
Response saved to DB → session updated
```

1. You type a message in the web UI
2. The message is sent to the API via SignalR
3. The API loads the full chat history for the session
4. Relevant **user memories** are injected into the system prompt (RAG)
5. The LLM responds — the answer is sent back to the browser via SignalR
6. The assistant response is persisted in the database

---

## Sessions

Every conversation lives in a **session**. Sessions are persistent across browser reloads.

| Feature | Details |
|---------|---------|
| Multiple sessions | Open as many as you like — each has its own history |
| Auto-title | New sessions are titled from the first message (first 50 chars) |
| Session sidebar | All sessions listed with relative timestamps ("5 min ago", "yesterday") |
| Unread badges | Sessions with new messages from agents are highlighted |
| Delete | Remove any session with confirmation — messages are deleted too |

---

## Memory

The personal agent has **persistent memory** across sessions via RAG (Retrieval-Augmented Generation).

### Two Memory Scopes

| Scope | What it stores |
|-------|---------------|
| **User memory** | Preferences, opinions, decisions, things you asked it to remember |
| **Project memory** | Architecture decisions, conventions, technical context per project |

### How Memory Works

- When the agent learns something worth keeping, it stores it automatically
- When you say *"remember this"*, it stores immediately
- Before each response, up to 10 relevant memories are retrieved and injected into context
- You can ask the agent to recall, update, or delete anything it has stored
- **Never stored:** passwords, tokens, API keys, or credentials

### Memory Rules

- User statement always beats stored memory — if there's a conflict, the user wins
- The agent stores distilled essence, not raw transcripts
- Quality over quantity — a few precise memories beat many vague ones

---

## Capabilities

The personal agent has access to these capability groups:

| Capability | Key tools |
|------------|----------|
| `admin` | `list_agents`, `get_agent`, `list_servers`, `get_server`, `list_configs`, `update_config` |
| `task-management` | `list_projects`, `get_project`, `list_tasks`, `get_task`, `create_task`, `update_task` |
| `memory` | `remember`, `recall`, `forget`, `remember_project`, `recall_project`, `forget_project` |
| `chat` | `list_sessions`, `get_session_messages`, `search_sessions` |
| `chat_write` | `send_message`, `send_to_user` |
| `skills` | `list_skills`, `read_skill` |
| `identity` | `get_identity` |
| `file-operations` | `read_file`, `write_file`, `list_directory`, `search_files`, `replace_in_file`, … |
| `shell-operations` | `execute_shell_command` |

### Task Delegation

The personal agent acts as your **interface to the system**, not the worker itself.

> *"I need a login page for the new project"*

The agent will:
1. Gather requirements from you
2. Create a structured task on the Kanban board with full context
3. On the next manager heartbeat, the manager assigns it to a worker agent — which executes it autonomously
4. The personal agent follows up and reports back when it's in Review

This is the **assistant flow**: brain dump → structured task → manager + worker execution.

---

## Customizing the Persona

The personal agent's persona is fully defined in config files — no code changes needed. To customize:

### `config/agents/personal.json`

```json
{
  "name": "Personal Agent",
  "role": "personal",
  "description": "Brain dump intake, intent extraction, general help and research",
  "capabilities": ["admin", "task-management", "memory", "chat", "chat_write", "skills", "identity", "file-operations", "shell-operations"],
  "model": "qwen2.5:14b",
  "supportsFunctionCalling": true
}
```

### `config/agents/personal_system.md`

The **system prompt** — defines how the agent behaves, what it can and cannot do,
how it handles memory, delegation, and long conversations.
Edit this to change the agent's operating rules.

### `config/agents/personal_personality.md`

The **personality prompt** — defines *who* the agent is. Tone, style, quirks.
Replace this file entirely to create your own persona.

Config is re-synced from disk every 5 minutes — no restart required.

---

## Workspace

The personal agent has its own workspace directory at `AiConfig__BaseDir/workspaces/_personal/`.
This is used for file operations during chat — writing drafts, saving research, or preparing
content before creating tasks.

Unlike workers (which get a fresh workspace per task), the personal agent uses a single
persistent workspace shared across all sessions.

---

## Proactive Messaging

The personal agent is the **only** agent that communicates with you via chat.
No other agent (manager, workers, scheduled triggers) sends messages directly.

When a task completes or needs attention, the personal agent picks it up and
notifies you in an existing or new session. The web UI shows an unread badge
for new incoming messages.

---

## Scheduled Tasks

### Chat Summarization

The `chat-summarize` skill runs on a schedule (default: every 2 hours, disabled by default)
to convert recent conversations into permanent memories.

### Project Summary

The `project-summary` skill runs on a schedule (default: weekdays at 09:00, disabled by default)
to post a short status report for the project — blocked items, items in review, recent progress —
via `send_to_user`. Repoint `projectName` to your real project before enabling.

→ See [scheduler.md](scheduler.md) for how to enable and configure scheduled triggers.

---

## Behavior Guidelines (from default system prompt)

The default personal agent follows these rules:

- Responds in the language you write in
- Matches your energy — terse if you're brief, expansive if you're chatty
- Switches to professional mode for serious topics (production issues, deadlines)
- Never asks for permission on harmless actions
- Acknowledges failures honestly — no hiding, no minimizing
- Never stores or exfiltrates secrets
- Always asks before anything leaves the machine (emails, messages to others)
