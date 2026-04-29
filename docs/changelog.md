# Changelog

All notable changes to Agent-Elno will be documented in this file.

## [0.2.0] — 2026-04-29

### Features

- **Claude Code CLI server type** — connect Claude Code CLI as a first-class LLM backend (`ClaudeCli`). Persistent sessions for chat and scheduled agents; stateless one-shot execution for task workers. Tool calls are logged to the action log. Default config now ships a disabled `claude-cli` server placeholder. See [claude-setup.md](claude-setup.md).
- **`Anthropic` server type** — direct Anthropic API support, the legal-on-server route to Claude.
- **Event-driven task execution** — workers wake up immediately on task assignment instead of polling. The manager assigns tasks via `assign_task`; the worker is notified and starts without delay.
- **Manager heartbeat** — the manager runs as a scheduled agent (the `manager-heartbeat` trigger). It reviews eligible tasks, assigns work to the right agent, and manages the review flow — no built-in execution loop. Ships disabled by default; point it at a real project before enabling.
- **Task review flow** — after a worker completes a task, it hands back to the manager. The manager evaluates the result and moves the task to review or done. Humans approve or request changes.
- **Manager commit-push gate** — the manager assigns a push worker before transitioning a task to `Done` if there are pending local commits. No silent loss of work on approve.
- **Developer rebase rule** — the developer agent prefers rebase over merge when integrating remote changes; multiple agents can share the same feature branch without merge churn.
- **`assign_task` tool** — the manager can assign tasks to worker agents by role via MCP.
- **`list_projects` / `get_project` tools** — available to any agent with `task-management` capability.
- **Parent / subtask relationships** — tasks can reference a parent task for grouping and dependency tracking.
- **Memory page redesign** — sidebar filters, flat grid layout, and detail view.
- **Placeholder resolution improvements** — `{AvailableWorkers}`, `{LastRunAt}`, `{TriggerName}`, and others are now resolved in all execution paths (CLI workers, SK workers, MCP `read_skill`).
- **Non-interactive install** — `INSTALL_*` environment variables let you drive `install.sh` end-to-end without prompts (used by the test-server flow).

### Fixes & Improvements

- Workspace provisioning hardened: clones on cold start, rebases on pull, always checks out the repository's configured default branch.
- Manager heartbeat respects the push-gate before transitioning approved tasks to Done.
- MCP HTTP transport runs in **stateless** mode on the standalone `DataPS.AI.MCP` service.
- Scheduler preserves `NextRunAt` across config sync ticks — fires near a schedule edge are no longer dropped.
- Chat reloads on SignalR reconnect; the conversation list subscribes to `ChatUpdated` for instant updates.
- `config-default` is now platform-agnostic (moved out of `linux-x64/`) — shared across runtime publish targets.
- Project-scoped Kanban columns — each project defines its own column set; validated on import.
- Action log now captures all MCP tool calls with arguments and results.
- "Operator" renamed to "manager" throughout the UI, configuration, and docs.
- Board navigation reloads correctly when switching between projects via the sidebar.
- Dropped unused `.env.*.example` files from the bundled tarball — `install.sh` writes its own.

## [0.1.0] — 2026-03-06

First public release.

### Features

- **Kanban board** — task management with configurable columns per project
- **Autonomous operator** — picks up tasks, writes code, creates branches, moves cards through the board
- **Human-in-the-loop review** — results land in a review column; approve, comment, or request changes
- **Personal agent chat** — brain-dump ideas in plain language, get structured tasks back
- **Semantic memory** — per-user and per-project memory for context across sessions
- **Scheduled triggers** — cron-based agent execution without manual intervention
- **VS Code / MCP integration** — manage tasks and review directly from your editor
- **Multi-model support** — connect any OpenAI-compatible endpoint (Ollama, LiteLLM, OpenAI, …)
- **Role-based agents** — operator, developer, reviewer, architect, editor — each with its own model and prompt
- **Skill system** — reusable prompt templates attached to projects
- **Git integration** — automatic branch creation, commit, push via command line integration
- **Action log** — full trace of every agent decision and tool call
- **Web UI** — Blazor-based dashboard, project views, task detail, chat
- **Mobile app** — lightweight companion for chat and task overview *(closed beta)*
- **Interactive installer** — single curl command, asks for LLM config, sets up everything
- **Zero telemetry** — no tracking, no analytics, no data collection
