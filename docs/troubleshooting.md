# Troubleshooting & Diagnostics

Agent-Elno provides three layers of observability: the **Action Log** (all LLM calls),
the **Trigger Log** (scheduler execution history), and **file-based system logs** in the `./logs/` directory.

---

## Action Log

The action log records every LLM call made by the system — from the operator,
the personal agent chat, and the scheduler. It is the primary place to look
when something produces an unexpected result or fails silently.

### Where to Find It

**Web UI → Monitor → Actions** (`/action-logs`)

The list view shows:
- Columns: Timestamp, Source, Action, AgentName, Context, TokensTotal, DurationMs, Status, Actions
- Summary bar: total calls, error count, average duration, total tokens consumed
- Auto-refreshes every 10 seconds
- Filterable by Source, Status, and Context Type

Click any row to open the **detail view**, which shows:
- Sidebar with all metadata (source, action, context, agent, model, round, tokens, duration, status, timestamp)
- User prompt
- Tool calls and their results (if any)
- Assistant response
- Error details (if any)

### Fields Reference

| Field | Description |
|-------|-------------|
| `Timestamp` | When the LLM call was made |
| `Source` | Who initiated the call: `Operator`, `Assistant`, `Scheduler` |
| `Action` | What was being done (e.g., `PlanStep`, `EvaluateResult`, `Chat`) |
| `ContextType` | `Task`, `ChatSession`, or `Trigger` |
| `ContextId` | ID of the task / session / trigger that triggered the call |
| `Round` | Iteration number within the current session |
| `AgentName` | Agent used at time of call |
| `Model` | Exact model identifier sent to the LLM |
| `TokensIn / Out / Total` | Token accounting for cost tracking |
| `DurationMs` | Total time for the LLM call in milliseconds |
| `Status` | `Success` or `Error` |
| `Error` | Error message if the call failed |
| `PromptReference` | Skill name, if a stored skill was used |

### Common Patterns

| Symptom | What to look for in Action Log |
|---------|-------------------------------|
| Task stuck in "In Progress" | Filter by `ContextType=Task` — check for repeated `Error` status or `MaxSessionTurns` reached |
| Wrong agent behavior | Open detail view — check `AgentName`, `Model`, and the actual system prompt sent |
| High token usage | Scan the `TokensTotal` column — find which calls are expensive |
| LLM timeout | `Status=Error`, error contains "timeout" — increase `Kernel.Timeout.LlmCall` |
| Rate limit errors | `Status=Error`, error contains "429" — tune `Kernel.RateLimit.BackoffSeconds` |

---

## Trigger Log

Every scheduler trigger execution is logged with its full result.

### Where to Find It

**Web UI → Monitor → Triggers** (`/triggers`)

Each trigger in the list shows:
- `LastRunAt` — when it last fired
- `NextRunAt` — when it will fire next
- Status of the last execution

### Fields Reference

| Field | Description |
|-------|-------------|
| `StartedAt` | When the trigger execution began |
| `FinishedAt` | When it completed (`null` = still running) |
| `AgentName` / `SkillName` | Snapshots of what was configured at execution time |
| `Status` | `Running`, `Completed`, or `Failed` |
| `Log` | Full LLM response / execution output in Markdown |
| `ErrorMessage` | Failure details if `Status=Failed` |

### Common Patterns

| Symptom | What to check |
|---------|--------------|
| Trigger never fires | Check `enabled: true` in the JSON and that `NextRunAt` is in the past |
| Trigger stuck as "Running" | Previous execution crashed — the worker skips if a `Running` log exists. Delete the stuck log entry in the Triggers view to unblock the trigger |
| Trigger fires but does nothing useful | Open the log entry — read the full LLM response to see what the agent decided |
| Cron expression silently ignored | Invalid cron sets `NextRunAt = null` — verify your expression with a cron validator |

---

## System Logs

Each service writes daily log files to its `./logs/` directory.
Log files are named `{ServiceName}_{date}.log` and roll over daily
(with numbered suffixes like `_001`, `_002` when files get large).

```
logs/
├── DataPS.AI.Api_20260301.log
├── DataPS.AI.Api_20260302.log
└── DataPS.AI.Api_20260302_001.log   ← roll-over
```

### Reading Logs

```bash
# Latest log file
tail -100 ./logs/DataPS.AI.Api_$(date +%Y%m%d).log

# Follow live
tail -f ./logs/DataPS.AI.Api_$(date +%Y%m%d).log

# Search for errors
grep -i "error\|exception" ./logs/DataPS.AI.Api_$(date +%Y%m%d).log

# All errors from the last 3 days
grep -i "error\|exception" ./logs/DataPS.AI.Api_*.log
```

### Service Status

```bash
# Quick health check — shows active/failed and last log lines
systemctl status dataps-ai-api dataps-ai-app dataps-ai-mcp
```

### Log Levels

| Level | When it appears |
|-------|----------------|
| `Information` | Normal operation — requests, worker ticks, config syncs |
| `Debug` | Disabled in production — only appears in development builds |
| `Warning` | Recoverable issues — retries, skipped tasks, config fallbacks |
| `Error` | Failures requiring attention — unhandled exceptions, service crashes |

### Common Patterns

| Symptom | What to look for |
|---------|-----------------|
| Service won't start | Check the latest log file for startup exceptions |
| Service keeps restarting | `grep -i "error\|exception"` across recent log files |
| Operator not picking tasks | `tail -f` the API log — watch for worker tick messages |
| Config not loading | Look for `ConfigSync` warning lines |
| Database error | Look for `SQLite`, `EF Core`, or `migration` in error lines |

### Restarting Services

```bash
# Restart a single service
systemctl restart dataps-ai-api

# Restart all three
systemctl restart dataps-ai-api dataps-ai-app dataps-ai-mcp
```

---

## Metrics

> **Note:** The metrics system is under active development and not yet production-ready.
> The categories and cleanup worker described below reflect the planned design.

The system collects internal performance and business metrics in the database.
Raw metrics are cleaned up periodically by the `MetricsCleanup` worker.

| Category | Examples |
|----------|---------|
| `performance` | LLM call duration, queue wait time, execution time per task |
| `business_value` | Estimated time saved, task success rate |
| `resource` | Token consumption per agent/model |
| `aggregated` | Weekly/monthly rollups of the above |

The cleanup interval is configured in `system-config/system.json` via `Worker.MetricsCleanup` (default: every 6 hours).

---

## Quick Diagnostic Checklist

When something goes wrong, work through this order:

1. `systemctl status dataps-ai-api` — is the service running?
2. Check `./logs/` — any startup or runtime errors in the latest log file?
3. **Action Log** in the UI — find the relevant call, open detail view
4. **Trigger Log** — if the issue involves a scheduled trigger
5. Check `config/system-config/` — are worker intervals and timeouts sensible?
6. Check `config/servers/` — is the LLM provider URL and API key correct?
