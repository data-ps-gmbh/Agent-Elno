# Changelog

All notable changes to Agent-Elno will be documented in this file.

## [Unreleased]

*Nothing yet.*

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
