# Agents & Skills

Agent-Elno uses a two-layer prompt system: **agents** define *who* does the work,
**skills** define *how* specific steps are executed.

---

## Agents

An agent is a named persona with a system prompt, a default model, and optional tool restrictions.
Agents live in `config/agents/` — one JSON file per agent, plus a Markdown file for the system prompt
and an optional personality prompt file.

### Agent JSON

```json
{
  "name": "Developer Agent",
  "role": "developer",
  "description": "Simple to medium coding tasks, bug fixes, small features",
  "capabilities": ["git-operations", "file-operations", "shell-operations"],
  "model": "qwen2.5:14b",
  "supportsFunctionCalling": true
}
```

| Field | Description |
|-------|-------------|
| `name` | Display name shown in the web UI |
| `role` | Internal identifier (used in project config and task routing) |
| `description` | What this agent is good at (shown in UI, used by manager for role selection) |
| `capabilities` | Array of allowed capability groups; controls which tools are available |
| `model` | LLM model name for this agent |
| `supportsFunctionCalling` | Whether the model supports tool use |

### Built-in Agents

The default config ships with these agents:

| Agent | Purpose |
|-------|---------|
| `manager` | Internal — drives the execution loop (do not assign to projects) |
| `developer` | General software development tasks |
| `senior-developer` | Same as developer, higher-quality prompts, slower/costlier model |
| `architect` | System design, documentation, ADRs |
| `reviewer` | Code review and quality assessment |
| `document-editor` | Writing, editing, and formatting documents |
| `personal` | Personal assistant with a configurable personality |

### File Convention

Prompt files are loaded **by naming convention** based on the JSON filename.
Given `developer.json`, the system looks for `developer_system.md` and `developer_personality.md`
in the same folder.

Each agent can have up to three files:

| File | Purpose |
|------|---------|
| `{name}.json` | Agent definition (model, capabilities, tools) |
| `{name}_system.md` | System prompt — role, constraints, instructions |
| `{name}_personality.md` | Personality prompt (optional) — tone, style, character |

The **system prompt** defines *what* the agent does. The **personality prompt** defines *who* the agent is.
Both are sent as separate system messages to the LLM. Only the personal agent ships with a personality
prompt by default, but any agent can have one.

```markdown
<!-- agents/developer_system.md -->

You are a pragmatic software developer. You write clean, working code.
You prefer simple solutions. You ask clarifying questions when the task is ambiguous.

When writing code:
- Use the language already present in the project
- Follow existing conventions
- Write tests for non-trivial logic
```

---

## Skills

Skills are **reusable prompt templates** used by the manager loop and by scheduled triggers.
They live in `config/skills/` as Markdown files.

### Built-in Skills

The default config ships five skills:

| Skill file | Used by | Purpose |
|------------|---------|---------|
| `manager-heartbeat.md` | `manager-heartbeat` trigger → Manager Agent | Survey the board, assign workers, evaluate completed work, drive state transitions |
| `manager-wakeup.md` | TaskWakeup → Manager Agent | Sent to the manager when a worker hands a task back via `complete_task` / `fail_task`; triggers evaluation |
| `agent-wakeup.md` | TaskWakeup → assigned worker | Sent to the worker the moment the manager calls `assign_task`; orients it and instructs autonomous execution |
| `chat-summarize.md` | `chat-summarize` trigger → Personal Agent | Distill recent chat sessions into persistent user memories |
| `project-summary.md` | `project-summary` trigger → Personal Agent | Post a short kanban status report for the project via `send_to_user` |

The first three are part of the task lifecycle and are referenced by code paths (TaskWakeup + manager heartbeat skill name). The last two are example scheduled skills you can keep, edit, or replace freely.

### Customizing Skills

Edit the Markdown files directly. The skill content is sent as a prompt to the LLM.

**All prompt text** — system prompts, personality prompts, skills, and project info — receives
placeholder substitution before being sent to the LLM. Resolution happens in every execution path:
workers (CLI + SK) resolve before sending to the LLM, and `read_skill` (MCP + SK plugin) resolves
before returning content to the agent.

### Placeholder Reference

Values come from `PromptContext` — well-known fields are mapped directly,
additional values come from `context.Parameters` (set by the caller).

#### Well-known fields (always available)

| Variable | Content |
|----------|---------|
| `{AgentName}` | Name of the executing agent |
| `{ProjectId}` | Linked project ID (empty if none) |
| `{TaskId}` | Task ID (empty if not in task context) |
| `{WorkspacePath}` | Workspace root path for file/shell/git operations |

#### Caller-provided parameters

| Variable | Set by | Content |
|----------|--------|---------|
| `{Now}` | All worker paths, MCP | Current timestamp (ISO 8601) |
| `{ProjectName}` | All worker paths | Linked project name (empty if none) |
| `{AvailableWorkers}` | All worker paths | Markdown list of available worker agents with descriptions |
| `{LastRunAt}` | Scheduler | Previous execution timestamp, or `"never"` on first run |
| `{TriggerName}` | Scheduler | Display name of the trigger |
| `{TaskName}` | TaskWakeup | Task name |

#### Resolution scope by execution path

| Path | Resolves on | Context source |
|------|-------------|----------------|
| CLI worker (`CliWorker`) | System prompt, personality, skill/step prompt | Full `PromptContext` from caller |
| SK worker (`InternalWorker`) | System prompt, personality, user prompt | Full `PromptContext` from caller |
| MCP `read_skill` | Skill content returned to agent | Active session context (resolved from the calling agent's session) |
| SK `SkillsPlugin.read_skill` | Skill content returned to agent | `PromptContext` injected into plugin |

Unknown placeholders are left as-is — they won't cause errors.

Use `{LastRunAt}` to scope tool calls to only process data since the last run,
avoiding duplicate work across executions.

---

## Role Determination

The manager determines at each step which agent should handle it.
The manager LLM receives the task context and the list of available agent roles,
then returns the best-fit role.

If the LLM returns an unknown role or is uncertain, the task is blocked for manual review.

---

## Adding a Custom Agent

1. Create `config/agents/my-agent.json` with the fields above
2. Create `config/agents/my-agent_system.md` with the system prompt
3. Optionally create `config/agents/my-agent_personality.md` for tone/style

Config is re-synced from disk every 5 minutes — no restart required.

---

## Adding a Custom Skill

1. Create `config/skills/my-skill.md`
2. Assign it to a scheduled trigger in `config/triggers/`.
