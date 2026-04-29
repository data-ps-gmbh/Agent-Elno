# How the Manager Process Works

The **manager** is an agent that runs on a heartbeat schedule and drives task progress on the Kanban board.
It decides what needs to happen next, assigns work to the right worker agent, evaluates results,
and involves a human when needed.

---

## The Task Lifecycle

1. You (or a trigger) create a task on the Kanban board
2. The **manager heartbeat** fires on its cron schedule and finds eligible tasks
3. The manager evaluates each task and calls `assign_task` to hand it to the right worker agent
4. The worker starts immediately (event-driven wakeup — no polling delay)
5. When the worker finishes, the manager reviews the result on the next heartbeat and moves the task to Done or Review
6. To re-process a reviewed task, add your feedback as a comment and remove the `review` tag

The manager skips tasks in states listed in `IgnoredStates` (default: `Backlog`, `Done`)
and tasks tagged with any value in `IgnoredTags` (default: `blocked`, `review`).

---

## How It Works

The manager runs as a **scheduled agent** — it fires on a configurable cron trigger (the `manager-heartbeat` trigger in `config/triggers/`).
When it runs, it uses the same tool surface as any other agent: it reads tasks, evaluates their state, assigns workers, updates state, and stores summaries in memory.

```
Manager heartbeat fires
        │
        ▼
  Read eligible tasks
        │
        ▼
  For each task: evaluate state, assign worker via assign_task
        │
        ▼
  Worker wakes up immediately, executes with tools
        │
        ▼
  Manager (next heartbeat): review result → Done or Review
```

The manager's behaviour is entirely driven by its system prompt and the `manager-heartbeat` skill.
You can tune what it does, how it assigns roles, and how it evaluates results by editing those files.
See [agents-and-skills.md](agents-and-skills.md).

---

## Task Eligibility

The manager skips tasks that:
- Are in states listed in `IgnoredStates` (default: `Backlog`, `Done`)
- Have tags listed in `IgnoredTags` (default: `blocked`, `review`)
- Are already being processed by another manager instance

Only one task is processed at a time per manager instance.

---

## Available Tools

The tools available during execution depend on the assigned agent's **capabilities**.
Each capability group loads a set of Semantic Kernel plugins:

| Capability | Key tools |
|------------|----------|
| `file-operations` | `read_file`, `write_file`, `append_file`, `delete_file`, `list_directory`, `search_files`, `replace_in_file`, `move_file`, `create_directory`, `insert_at_line`, `read_file_lines`, `search_in_files`, `grep_search`, `find_files` |
| `git-operations` | `read_file`, `write_file` (git-aware variants) |
| `shell-operations` | `execute_shell_command` |
| `task-management` | `list_projects`, `get_project`, `list_tasks`, `get_task`, `get_manager_tasks`, `create_task`, `update_task`, `delete_task`, `assign_task`, `claim_task`, `complete_task`, `fail_task`, `add_comment`, `add_attachment`, `get_attachments`, `report_progress`, `list_assigned_tasks`, `get_available_tasks` |
| `memory` | `remember`, `recall`, `forget`, `remember_project`, `recall_project`, `forget_project` |
| `admin` | `list_agents`, `get_agent`, `list_servers`, `get_server`, `list_configs`, `update_config` |
| `chat` | `list_sessions`, `get_session_messages`, `search_sessions` |
| `chat_write` | `send_message`, `send_to_user` |
| `skills` | `list_skills`, `read_skill` |
| `identity` | `get_identity` |
| `context-storage` | `store`, `read` |

The developer agent, for example, has `file-operations`, `git-operations`, and `shell-operations`.

---

## Workspaces

Each task gets an isolated **workspace** directory under `AiConfig__BaseDir/workspaces/prj-{projectId}/task-{taskId}/`.
The worker agent clones the project's repository, writes files, and runs commands inside this directory.
On startup, the workspace is updated (`git pull`) and checked out to the repository's configured `defaultBranch`.

Git workflow beyond that (branching, committing, pushing) is driven by the agent via its tools and skills —
customise the agent's system prompt or skills to enforce your preferred conventions.

Workspaces for completed tasks are cleaned up after `Worker.WorkspaceRetention` days (default: 7).

---

## Project Context Injection

If a project has a `project_info.md` (see [configuration.md](configuration.md#project-prompt-project_infomd)),
its content is injected into every step prompt as a **## Project Context** section.

This is how you tell agents where the code is, which conventions to follow, and which
files to read before making changes. Without it, agents guess — and often guess wrong.

---

## Maintenance Window

During the maintenance window (`Maintenance.Start` → `Maintenance.End`), the manager
will not pick up new tasks. In-progress tasks are not interrupted.

---

## Manager vs. Scheduler

| | Manager | Scheduler |
|---|---|---|
| What it is | A scheduled agent (the `manager-heartbeat` trigger) | The host worker that fires *all* scheduled triggers |
| Triggered by | Cron — its own `manager-heartbeat` trigger | Cron — every entry in `triggers/` |
| Output | Surveys the board, assigns workers, evaluates results, drives state | Runs `<agent> + <skill>` for any trigger, logs result |
| Cadence | Whatever cron you set on `manager-heartbeat` (default `*/15 * * * *`, **disabled out of the box**) | `Worker.Scheduler` (default 60s, evaluates due triggers) |

The scheduler is the engine; the manager is one of the agents the scheduler runs. The manager doesn't have its own poll loop.

---

## Failure Handling

If an LLM call fails due to a rate limit, the system applies the backoff sequence
from `Kernel.RateLimit.BackoffSeconds` (default: `60,120,180,240,300` seconds).

If a worker's session exceeds `MaxSessionTurns` without completing, the task is tagged
`blocked` — add your feedback as a comment, remove the tag, and it will be picked up again.

If a tool call throws an unrecoverable error, the manager evaluates the result on its next
heartbeat and decides whether to retry, block, or move to review.
