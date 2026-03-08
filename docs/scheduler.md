# Scheduler & Triggers

The **scheduler** runs background tasks on a cron schedule — without you lifting a finger.
Triggers can run any skill with any agent at any time interval you define.

---

## How It Works

```
SchedulerWorker (every 60s)
    │ loads all enabled triggers where NextRunAt ≤ now
    ▼
For each due trigger:
    │ overlap check (skip if already running)
    ├─ load agent + skill
    ├─ call LLM (skill prompt + agent system prompt)
    ├─ log result (TriggerLog)
    └─ compute NextRunAt from cron expression
```

The scheduler runs inside the API service as a background worker.
It polls the database every 60 seconds (configurable via `Worker.Scheduler`).

---

## Trigger Definition

Triggers are defined as JSON files in `config/triggers/`.

```json
{
  "name": "Chat Summarization",
  "agentName": "Personal Agent",
  "skillName": "chat-summarize",
  "projectName": null,
  "cronExpression": "0 */2 * * *",
  "enabled": false
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Display name shown in the UI |
| `agentName` | ✅ | Must match an agent `name` in `config/agents/` |
| `skillName` | ✅ | Must match a skill filename in `config/skills/` (without `.md`) |
| `projectName` | ❌ | Optional — provides project context to the agent |
| `cronExpression` | ✅ | 5-field cron expression (server local time) |
| `enabled` | ✅ | `false` = configured but inactive; `true` = will run on schedule |

---

## Cron Expression Format

Standard 5-field cron (server local time):

```
┌──────── minute (0-59)
│ ┌────── hour (0-23)
│ │ ┌──── day of month (1-31)
│ │ │ ┌── month (1-12)
│ │ │ │ ┌ day of week (0-7, 0 and 7 = Sunday)
│ │ │ │ │
* * * * *
```

### Common Examples

| Expression | Meaning |
|-----------|---------|
| `0 */2 * * *` | Every 2 hours (at minute 0) |
| `0 8 * * *` | Daily at 08:00 |
| `30 7 * * 1-5` | Weekdays at 07:30 |
| `0 0 * * 0` | Weekly, Sunday at midnight |
| `*/15 * * * *` | Every 15 minutes |
| `0 9,17 * * *` | 09:00 and 17:00 every day |

> All times use the **server's local timezone**.

---

## What Happens When a Trigger Fires

The scheduler **does not create a Kanban task**. It runs the LLM directly:

1. Loads the agent's system prompt + personality
2. Sends the skill's prompt as the user message
3. The agent can use all tools its capabilities allow
4. The full LLM response is saved to the **trigger log**
5. `LastRunAt` and `NextRunAt` are updated in the database

This is ideal for maintenance tasks, summarizations, and proactive notifications
that don't need human review.

---

## Built-in Trigger: Chat Summarization

The default config ships with one trigger (disabled):

**File:** `config/triggers/chat-summarize.json`

```json
{
  "name": "Chat Summarization",
  "agentName": "Personal Agent",
  "skillName": "chat-summarize",
  "cronExpression": "0 */2 * * *",
  "enabled": false
}
```

**What it does:**
Every 2 hours, the Personal Agent scans recent chat sessions and extracts
key facts, decisions, and preferences — storing them as user memories.
This ensures your assistant "remembers" important context across sessions.

**To enable it:** Set `"enabled": true` — it will be picked up on the next ConfigSync cycle.

---

## Overlap Prevention

If a trigger is still running when the next scheduled time arrives,
the scheduler skips that execution and waits for the next interval.
This prevents stacking long-running tasks.

---

## Trigger Logs

Every execution is logged in the database with:
- Start time and end time
- Status: `Running` → `Completed` or `Failed`
- Full LLM response content
- Error message (on failure)

You can view trigger logs in the web UI under **Monitor → Triggers**.

---

## Managing Triggers

### Via Config File (Recommended)

Edit or add JSON files in `config/triggers/`. Config is re-synced automatically 
every `Worker.ConfigSync` seconds (default: 5 min), if you're using folder import or git-based config.

### Via Web UI

Triggers can also be created and toggled directly in **Configuration → Scheduler** without editing files.

---

## Creating a Custom Trigger

**Example: Daily standup summary at 09:00**

1. Create `config/skills/daily-standup.md`:

```markdown
---
name: "daily-standup"
description: "Generate a daily standup summary from recent tasks"
---

Check the Kanban board for tasks that moved to Done or Review in the last 24 hours.
Write a concise standup update:
- What was completed yesterday
- What is in progress today
- Any blockers in Review

Format as a short bullet list, ready to paste into a team chat.
```

2. Create `config/triggers/daily-standup.json`:

```json
{
  "name": "Daily Standup",
  "agentName": "Personal Agent",
  "skillName": "daily-standup",
  "cronExpression": "0 9 * * 1-5",
  "enabled": true
}
```

3. The trigger will be picked up on the next ConfigSync cycle (default: 5 min).

The trigger fires weekdays at 09:00 (server time). Results appear in the trigger log.
To also receive the result as a chat message, add a `send_to_user` call to the skill prompt.
The agent must have the `chat_write` capability for this to work.

---

## Scheduler Settings

Configured in `config/system-config/system.json`:

| Key | Default | Description |
|-----|---------|-------------|
| `Worker.Scheduler` | `60` | Poll interval in seconds |
| `Worker.Operator` | `30` | Separate — operator poll interval |
| `Maintenance.Start` | *(empty)* | Scheduler pauses during maintenance window (empty = disabled) |
| `Maintenance.End` | *(empty)* | Scheduler resumes after window (empty = disabled) |

---

## Skill Placeholders

Before sending the skill prompt to the LLM, the scheduler substitutes these placeholders:

| Placeholder | Value | Example |
|-------------|-------|---------|
| `{LastRunAt}` | ISO 8601 timestamp of the previous execution | `2026-03-06T15:00:00.0000000Z` |
| `{Now}` | Current execution timestamp (ISO 8601) | `2026-03-06T17:00:00.1234567Z` |
| `{TriggerName}` | Display name of the trigger | `Chat Summarization` |
| `{AgentName}` | Name of the agent running this trigger | `Personal Agent` |
| `{ProjectName}` | Linked project name (empty if none) | `My Project` |
| `{ProjectId}` | Linked project ID (empty if none) | `2` |

On first run (no previous execution), `{LastRunAt}` is replaced with `"never"`.

This lets skills scope their work to only process new data since the last run.
For example, the `chat-summarize` skill uses it to call `list_sessions(since: "{LastRunAt}")`.
