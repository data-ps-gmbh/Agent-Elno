# How the Operator Process Works

The **operator** is the autonomous engine that picks up tasks from the Kanban board,
works through them step by step using LLM calls and tools, and moves the result based
on the definition inside the prompt. If needed, it calls in a human for help or approval.

---

## The Task Lifecycle

The operator picks tasks from **any state except** those in `IgnoredStates` (default: `Backlog`, `Done`)
and skips tasks tagged with `IgnoredTags` (default: `blocked`, `review`).

1. You (or a trigger) create a task on the Kanban board
2. The **operator worker** polls every 30 seconds (configurable) for eligible tasks
3. It picks one task and starts the execution loop
4. After processing, the **evaluate-result** skill decides the outcome — continue, mark done, or request human review (adds the `review` tag)
5. To re-process a reviewed task, add your feedback as a comment and remove the `review` tag

---

## The Execution Loop

Each task runs through a multi-turn loop capped by `MaxSessionTurns` (default: 10).

```
┌─────────────────────────────────────────────┐
│  For each turn (up to MaxSessionTurns):     │
│                                             │
│  1. PlanStep       → what should happen now?│
│  2. DetermineRole  → which agent handles?   │
│  3. ComposePrompt  → build the LLM prompt   │
│  4. LLM call       → execute with tools     │
│  5. EvaluateResult → done? error? continue? │
│  6. SummarizeStep  → log what happened      │
│                                             │
│  If done: SummarizeTask                     │
└─────────────────────────────────────────────`
```

Each step uses a configurable **skill** (prompt template). See [agents-and-skills.md](agents-and-skills.md).

---

## Task Eligibility

The operator skips tasks that:
- Are in states listed in `IgnoredStates` (default: `Backlog`, `Done`)
- Have tags listed in `IgnoredTags` (default: `blocked`, `review`)
- Are already being processed by another operator instance

Only one task is processed at a time per operator instance.

---

## Available Tools

The tools available during execution depend on the assigned agent's **capabilities**.
Each capability group loads a set of Semantic Kernel plugins:

| Capability | Key tools |
|------------|----------|
| `file-operations` | `read_file`, `write_file`, `delete_file`, `list_directory`, `search_files`, `replace_in_file`, `grep_search`, `find_files` |
| `git-operations` | `read_file`, `write_file` (git-aware) |
| `shell-operations` | `execute_shell_command` |
| `task-management` | `list_projects`, `get_project`, `list_tasks`, `get_task`, `create_task`, `update_task` |
| `base-tools` | `get_current_datetime`, `get_system_info` |
| `memory` | `remember`, `recall`, `search_memory`, `forget`, `remember_project`, `recall_project`, `search_project_memory`, `forget_project` |
| `admin` | `list_agents`, `get_agent`, `list_servers`, `get_server`, `list_configs`, `update_config` |
| `chat_write` | `create_session`, `send_message`, `send_to_user` |

The developer agent, for example, has `file-operations`, `git-operations`, and `shell-operations`.

---

## Workspaces

Each task gets an isolated **workspace** directory under `AiConfig__BaseDir/workspaces/prj-{projectId}/task-{taskId}/`.
The operator clones repos, writes files, and runs commands inside this directory.

For every linked repository the operator creates a **feature branch** named
`prj-{projectId}_task-{taskId}`, based on the repository's default branch.
All changes are committed and pushed to this branch before the task moves to review.
Commit messages follow the format `[prj-{projectId}_task-{taskId}] {taskTitle}`.

Workspaces for completed tasks are cleaned up after `Worker.WorkspaceRetention` days (default: 7).

---

## Project Context Injection

If a project has a `project_info.md` (see [configuration.md](configuration.md#project-prompt-project_infomd)),
its content is injected into every step prompt as a **## Project Context** section.

This is how you tell agents where the code is, which conventions to follow, and which
files to read before making changes. Without it, agents guess — and often guess wrong.

---

## Maintenance Window

During the maintenance window (`Maintenance.Start` → `Maintenance.End`), the operator
will not pick up new tasks. In-progress tasks are not interrupted.

---

## Operator vs. Scheduler

| | Operator | Scheduler |
|---|---|---|
| Triggered by | Eligible tasks on Kanban board | Cron expressions in `triggers/` |
| Output | Processes tasks, moves to Review | Runs agent + skill, logs result |
| Poll interval | `Worker.Operator` (30s) | `Worker.Scheduler` (60s) |

The scheduler runs agents with skills directly (no Kanban task). The operator processes Kanban tasks. They work independently.

---

## Execution Loop Failure Handling

If the LLM call fails due to a rate limit, the operator applies the backoff sequence
from `Kernel.RateLimit.BackoffSeconds` (default: `60,120,180,240,300` seconds).

If `MaxSessionTurns` is reached without a completion signal, the task is tagged
`blocked` — you can add feedback as a comment, remove the tag, and re-queue it.

If a tool call throws an unrecoverable error, the evaluate-result skill decides the outcome.
