# Agent-Elno — Self-Hosted AI Agent Platform

![Dashboard](img/dashboard.png)

> A self-hosted AI agent platform that turns a kanban board into an autonomous development team.
> Describe tasks, the manager picks them up, writes code, and delivers results for your review —
> all on your own hardware, with your own models, and zero data leaving your server.
> Free for personal use.

---

## ✨ Features

![Kanban](img/kanban.png)

- **Kanban-driven agents** — create tasks, the manager picks them up and works autonomously
- **Human-in-the-loop** — every result lands in a review column before it's accepted
- **Assistant / brain-dump chat** — describe an idea in plain language, the system creates structured tasks
- **Scheduled triggers** — cron-based agent execution without manual intervention
- **VS Code integration** — MCP server exposes tasks and review directly in your editor
- **Bring your own model** — connect any OpenAI-compatible endpoint (LocalAi, LiteLLM, …), OpenAI / Azure, or the Anthropic API directly
- **Claude Code CLI bridge** — on a personal install, route agents through your local `claude` CLI for free with your existing Claude subscription *(personal machine only — see caveat below)*
- **100 % self-hosted** — your data never leaves your machine
- **0 % telemetry** — no tracking, no analytics, no data collection ... at least not in our code 😄

---

## 🚀 Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/data-ps-gmbh/Agent-Elno/main/get-agent-elno.sh | sudo bash
```

The interactive installer asks for your LLM provider, model name, and ports — then starts everything.
Same command to update. Default login: **admin / password**.

> **Already know your config?** Skip the wizard with the **[non-interactive install template](docs/quickstart.md#non-interactive-install-env-var-driven)** —
> a pre-fillable script you can also drop into cron for nightly auto-updates.

→ **[Full installation guide](docs/quickstart.md)**

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/data-ps-gmbh/Agent-Elno/main/remove-agent-elno.sh | sudo bash
```

Removes all services, binaries, config, and data. Asks for confirmation before deleting.

---

## 🔄 How It Works

You can feed work into the system from three places — pick whichever fits your moment:

- **Web kanban board** — open the board, add a task with a title and description.
- **Assistant chat** — brain-dump an idea in plain language; the personal agent extracts intent and creates a structured task for you.
- **VS Code / Copilot via MCP** — describe the work in your editor; Copilot hands it into the system.

Once tasks are on the board, the autonomous loop takes over:

1. The **manager** runs on a cron heartbeat — surveys the board, assigns each eligible task to the right worker agent (developer, senior-developer, reviewer, architect, …).
2. The **worker** wakes up immediately, checks out the project's feature branch, writes code, runs tests, commits.
3. When the worker is done, the **manager** evaluates the result on its next heartbeat — moves trivial work to *Done*, escalates substantive work to *Review*.
4. **You review** — approve via comment, or request changes in a comment and remove the `review` tag; the manager picks it up again on the next heartbeat.

### Kanban Processing Rules

The manager picks up tasks based on column and tags:

- **Processed:** Any column except *Backlog* and *Done*, without the tags *blocked* or *review*
- **Skipped:** Tasks in *Backlog*, *Done*, or tagged *blocked* / *review*

Move a task to **Ready** (or any active column) to let the manager pick it up.
When the manager finishes, it tags or moves the task to *review* or *done* — you check the result and either approve or comment.

**Away from VS Code?** Use the chat to tell your personal agent things on the go — via the web UI or the mobile app *(currently in closed beta)*.

---

## 🤖 Model Recommendations

> **The model is everything.**
> Agent-Elno is an orchestration layer — it sets the stage, but the model does the actual thinking.
> A capable model will surprise you. A weak one will burn through your tokens producing slop.
> Pick the model first, configure the platform second.

> **Running on your own dev machine?** You can wire up the **Claude Code CLI** as an LLM
> backend — the platform spawns the local `claude` binary and piggybacks on your existing
> Claude subscription. No API key, no per-token bill on top of what you already pay.
> *Caveat:* per Anthropic's TOS the subscription-tied CLI login is **only legal on your own
> developer machine** — not on a shared or production server. For server installs, use the
> Anthropic API server type with an API key. See [docs/claude-setup.md](docs/claude-setup.md).

### What we run today

This is the live setup at DATA-PS — it changes as new models ship, so treat it as a snapshot,
not a fixed recipe.

| Use case | Model | Why |
|---|---|---|
| **Coding** (default developer) | **Claude Sonnet 4.6** | Best size / quality / cost balance for code; reliable tool calling |
| **Heavy lifting** (architect, reviewer, multi-file refactors) | **Claude Opus 4.7** | Strongest reasoning, huge context; catches what coder models miss |
| **Manager + personal assistant** (orchestration & chat) | **Qwen3.6-27B** (local) | Reliable tool calling, surprisingly good at code/architecture for triage and "simple-change" reviews, great secretary persona, free, private |
| **Specific cloud coder tasks** | **gpt-5.1** (codex variants) | Where we route the work that doesn't go to Claude — large context, fast |
| **Embedding** | **nomic-embed-text-v1.5** (local) | 768-dim, fast, good semantic search quality |

We bind these directly or front them with [LiteLLM](https://litellm.ai) as a unified proxy.

### Lessons we paid for so you don't have to

These are the *durable* takeaways — model names will rot, but the patterns hold.

- **Below ~30B params is too small for orchestration.** Anything in the 8B–14B range loops on
  tool calls under load (Qwen3-8B, Phi-4-Mini variants, Hermes-4-14B, GPT-4.1-Nano). 27–32B is
  the floor for a reliable manager / personal agent.
- **Local coder models choke on real codebases.** We ran our production repos (50k–100k LOC C#,
  20k–40k LOC Razor) past every flavour of Qwen-Coder, NextCoder, DeepSeek-V3.2 — all of them
  either ignored conventions, hallucinated paths, or "reviewed instead of coded." The working
  pattern is **local manager + cloud (or Claude CLI) coder**, not local everything.
- **Reasoning models for review pay for themselves.** Whatever the current frontier reasoning
  model is (today: Opus 4.7 / o-series), it catches what coder-tier models miss. Not a place
  to economise.
- **Tool-call quality matters more than benchmark scores.** We've watched models with great
  HumanEval numbers loop endlessly because they couldn't pick the right tool. Test in-platform,
  not on leaderboards.

### Local vs Cloud vs Claude CLI

- **Local** (LocalAI / Ollama): free, private, no rate limits — but needs a GPU (a 27–32B model
  wants ~24 GB VRAM at Q4).
- **Cloud API** (OpenAI / Azure / Anthropic API): faster, smarter coding models — costs money
  and data leaves your server, but it's the only legal Claude path on a shared host.
- **Claude CLI** (personal machine only): free if you already have a Claude subscription;
  see the legal caveat above.
- **Hybrid via LiteLLM**: route orchestration locally, coding to cloud or Claude — what we
  do day-to-day.

---
## 📖 Documentation

| | |
|---|---|
| **[Quick Start](docs/quickstart.md)** | Installation and first steps |
| **[Configuration](docs/configuration.md)** | Environment files, config modes, all options |
| **[Architecture](docs/architecture.md)** | Service architecture and data flow |
| **[Manager Process](docs/manager-process.md)** | How the autonomous loop works |
| **[Agents & Skills](docs/agents-and-skills.md)** | Agent definitions and prompt templates |
| **[Chat & Memory](docs/personal-agent-chat.md)** | Personal agent, sessions, semantic memory |
| **[Scheduler](docs/scheduler.md)** | Cron-based triggers |
| **[Integrations](docs/integrations.md)** | LiteLLM, Ollama, OpenAI, Anthropic, Claude CLI, nginx, Traefik |
| **[Claude Code CLI Setup](docs/claude-setup.md)** | Personal-machine route to Claude (subscription, no API key) |
| **[Troubleshooting](docs/troubleshooting.md)** | Logs, action log, common issues |
| **[Changelog](docs/changelog.md)** | Release history |

---

## 📋 Requirements

- **Debian 12+** or **Ubuntu 22.04+** (x64)
- An **OpenAI-compatible LLM endpoint** (Ollama, LiteLLM, OpenAI, …)
- 2 GB RAM, 4 GB disk minimum

No Docker, no .NET SDK, no runtime installation required.

---

## 💬 Support & Feedback

We built Agent-Elno to fit our own workflow — but we're actively developing it further.
If you have suggestions, feature requests, or run into problems, we'd love to hear from you.

- **Feature ideas** — open an issue; if it fits our roadmap, we'll try to integrate it
- **Bug reports** — please include a brief description of the problem and steps to reproduce; we'll investigate anything we can reproduce ourselves
- **Questions** — we try to answer as fast as we can

We can't promise everything, but we read every issue and do our best to help.

- [GitHub Issues](https://github.com/data-ps-gmbh/Agent-Elno/issues) — bug reports, feature requests, questions
- [data-ps.de](https://www.data-ps.de) — company website
- [info@data-ps.de](mailto:info@data-ps.de) — commercial inquiries

---

## 📜 License

**Free for personal, non-commercial use** under the
[PolyForm Strict License 1.0.0](license.txt).

**Commercial use requires a separate license** — contact [info@data-ps.de](mailto:info@data-ps.de).

© 2014–2026 DATA-PS GmbH. All rights reserved.

