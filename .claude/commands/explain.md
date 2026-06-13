---
description: Map how something works — request flow, data flow, or a subsystem — without changing code
argument-hint: "<file, feature, endpoint, or 'how does X work'>"
---

Explain, don't modify: $ARGUMENTS

Produce a clear mental model for a developer new to this code:

1. **Entry point** — where execution starts for this path (route, handler, CLI, job).
2. **Flow** — trace the call/data path step by step, citing `file:line` at each hop. Note where it crosses a boundary (HTTP, DB, queue, external API).
3. **State & side effects** — what reads/writes happen, what's cached, what's mutated.
4. **Failure modes** — what happens on bad input, downstream failure, or concurrency.
5. **Diagram** — a short ASCII or numbered flow if it aids understanding.
6. **Gotchas** — non-obvious constraints, invariants, or traps a future editor would miss.

Read-only. Do not edit any files. If the question is design-level, consider delegating to the **architect** agent.
