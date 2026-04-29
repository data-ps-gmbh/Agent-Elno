# Prompt Engineering Tips

Practical guidelines for writing and maintaining agent system prompts.
These apply to all agents — manager, personal, and workers.

---

## Positive framing over negation

Smaller models often drop or ignore "NOT" / "NEVER" / "don't" in instructions.
Instead of prohibiting an action, define what the agent CAN do — boundaries through inclusion.

| Weak (negation) | Strong (positive boundary) |
|---|---|
| "Do NOT set kanban state" | "Your only lifecycle actions are `complete_task` and `fail_task`" |
| "Never modify files outside your scope" | "Limit changes to files directly related to the task" |
| "Don't retry failed calls" | "After a failed call, try a different approach" |

If a prohibition is truly critical and must stay, pair it with the positive alternative:
> "Your only lifecycle actions are `complete_task` and `fail_task`. The manager handles all state transitions."

---

## Be explicit about tools

Models infer from available tools. If an agent has `update_task` in its tool set, it will
try to use it — even if the prompt says nothing about state management.

- Tell the agent which tools are "theirs" — the ones they should actively use
- If a tool is available but not for this agent's use case, define the boundary positively
  (see above)

---

## Structured output formats

When you need a specific output shape (e.g. review verdicts), provide a template.
Models follow structure better than prose descriptions of format.

```
## Review Summary
[1-2 sentence assessment]

## Verdict
[APPROVE / REQUEST_CHANGES]
```

---

## Token efficiency

Prompts are sent with every LLM call. Every token counts — especially for smaller,
cheaper models that are called frequently (e.g. manager heartbeat).

- Use tables over prose for rules with multiple cases
- Use bullet points over paragraphs
- Remove filler words: "please", "you should consider", "it is important to"
- Merge overlapping rules — two rules saying similar things waste tokens and confuse

---

## Context window awareness

Different models have different context limits. Prompts compete with tool results,
chat history, and skill content for space.

- Keep system prompts under 1000 tokens where possible
- Move reference material (checklists, examples) into skills that agents can `read_skill` on demand
- The personality prompt is separate from the system prompt — use it for tone/style,
  keep the system prompt for behavior

---

## Placeholders

Prompts support `{Placeholder}` substitution from `PromptContext`.
See [agents-and-skills.md](agents-and-skills.md) for the full placeholder reference.

- Use placeholders for dynamic content — don't hardcode agent names, project lists, or timestamps
- Unknown placeholders are left as-is (no errors), but they're wasted tokens
- `{AvailableWorkers}` is injected by the caller — don't hardcode worker/role lists in prompts

---

## Escalation is not failure

Models resist calling `fail_task` — they interpret it as admitting defeat and will loop
trying alternatives instead. Explicitly reframe escalation as the correct action:

> "Returning a task via `fail_task` is not failure — it is the correct action when you
> cannot proceed. The manager will reassign or escalate."

This single paragraph prevents more wasted tokens than any "don't loop" instruction.

---

## Only state confirmed facts

Models hallucinate file paths, function names, and technical details when prompted to
"be specific." If the manager instructs a worker with a hallucinated path, the worker
wastes its entire session looking for something that doesn't exist.

Rule: only include concrete details (paths, names, values) that were confirmed via tool calls.
If you haven't read it, don't reference it.

---

## Milestone-based commits, not per-change

Telling an agent to "commit as you make progress" produces a commit for every file edit.
Instead, instruct agents to commit at meaningful milestones — a feature working, a test
passing, a logical unit complete. Same applies to `report_progress` comments.

---

## Drop boilerplate sections

If a section exists in every prompt but doesn't change behavior, it wastes tokens.
Common offender: "Tool Usage" blocks like "don't repeat calls, don't retry failures."
Models that loop don't loop because they missed that instruction — they loop because
the task is unclear or they're stuck. Address the root cause (e.g. "Knowing When to Stop")
instead of adding generic tool hygiene rules.

---

## Testing prompts

- Test with the smallest model first — if it works on a 7B model, it works everywhere
- Watch for instruction-following failures: state changes the agent shouldn't make,
  tools called with wrong parameters, hallucinated tool names
- Check the action log for unexpected tool calls — that reveals prompt gaps
- When a model misbehaves, check if the instruction was negative ("don't X") and reframe positively
