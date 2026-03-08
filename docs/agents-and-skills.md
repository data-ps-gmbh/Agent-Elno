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
| `description` | What this agent is good at (shown in UI, used by operator for role selection) |
| `capabilities` | Array of allowed capability groups; controls which tools are available |
| `model` | LLM model name for this agent |
| `supportsFunctionCalling` | Whether the model supports tool use |

### Built-in Agents

The default config ships with these agents:

| Agent | Purpose |
|-------|---------|
| `operator` | Internal — drives the execution loop (do not assign to projects) |
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

Skills are **reusable prompt templates** used by the operator loop and by scheduled triggers.
They live in `config/skills/` as Markdown files.

### Built-in Operator Skills

| Skill file | Configured by | Purpose |
|------------|--------------|---------|
| `operator-determine-role.md` | `SkillDetermineRole` | Decide which agent handles the current task |
| `operator-plan-step.md` | `SkillPlanStep` | Plan the next action given current state |
| `operator-compose-prompt.md` | `SkillComposeStepPrompt` | Build the final prompt for the LLM call |
| `operator-evaluate-result.md` | `SkillEvaluateResult` | Decide: done, continue, or error? |
| `operator-summarize-step.md` | `SkillSummarizeStep` | Summarize one completed step for the log |
| `operator-summarize-task.md` | `SkillSummarizeTask` | Write the final review summary |

### Built-in Scheduler Skills

| Skill file | Purpose |
|------------|---------|
| `chat-summarize.md` | Summarize recent chat sessions into persistent user memories |

### Customizing Skills

Edit the Markdown files directly. The skill content is sent as a prompt to the LLM.

**Operator skills** receive template variables that are substituted at runtime.
**Scheduler skills** also receive template variables — see the table below.

### Operator Template Variables

All operator skills receive these **common variables**:

| Variable | Content |
|----------|---------|
| `{TaskName}` | Task title |
| `{TaskDescription}` | Task description (or `(no description)`) |
| `{TaskState}` | Current Kanban column |
| `{TaskTags}` | Comma-separated tag list |
| `{TaskComments}` | Formatted user and agent comments with timestamps |

Individual skills receive **additional variables**:

| Skill | Extra variables |
|-------|----------------|
| `operator-determine-role` | `{AvailableRoles}` |
| `operator-plan-step` | `{AvailableRoles}`, `{StepIndex}` |
| `operator-compose-prompt` | `{StepTitle}`, `{StepDescription}`, `{PriorStepResults}`, `{AgentRole}` |
| `operator-evaluate-result` | `{WorkerResult}`, `{AgentRole}` |
| `operator-summarize-step` | `{WorkerResult}`, `{AgentRole}`, `{StepIndex}` |
| `operator-summarize-task` | `{AllStepResults}` |

### Scheduler Template Variables

Scheduler skills receive these variables, substituted before the prompt is sent to the LLM:

| Variable | Content |
|----------|---------||
| `{LastRunAt}` | ISO 8601 timestamp of the trigger's previous execution, or `"never"` on first run |
| `{Now}` | Current execution timestamp (ISO 8601) |
| `{TriggerName}` | Display name of the trigger |
| `{AgentName}` | Name of the agent running this trigger |
| `{ProjectName}` | Linked project name (empty if none) |
| `{ProjectId}` | Linked project ID (empty if none) |

Use `{LastRunAt}` to scope tool calls to only process data since the last run,
avoiding duplicate work across executions.

---

## Role Determination

The `operator-determine-role` skill runs at each step and selects which agent
should handle it. The operator LLM receives the task context and the list of
available agent roles, then returns the best-fit role.

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
2. Reference it in `system-config/system.json` if it replaces a built-in operator skill,
   or assign it to a scheduled trigger in `config/triggers/`.
