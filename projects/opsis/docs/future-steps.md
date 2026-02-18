---
layout: page
title: Future Steps
permalink: /projects/opsis/docs/future-steps/
---

> Imported from `docs/future-steps.md`

# Future Steps — Opsis Pipeline

> Ideas for future development. Nothing here is implemented. This is a design space document.

---

## 1. A Cast of Agents: Multiple Bot Personas

One of the most interesting architectural possibilities in this system is that **multiple agents can respond to the same ticket** — either simultaneously, or sequentially as a ticket ages and escalates. Each agent is a separate CrewAI crew with its own Jira bot user, its own backstory, and its own role in the support lifecycle.

Agents are cheap to define (a few dozen lines of Python) and can be mixed and matched. What follows are three personas worth building — each one tuned differently, each one interesting for different reasons.

---

### Agent 1 — Iris, the Intern

**Jira username:** `iris-intern`
**Display name:** `Iris (Support Intern)`
**Designed for:** First-response triage. Fast, cheap, low-stakes.

**The concept:** Iris just started. She has access to the documentation and is genuinely trying her best — but she's new, slightly overwhelmed, and her writing shows it. She dumps the most relevant source references, adds some enthusiastic commentary, and occasionally spells things wrong. She is endearing rather than authoritative. Users who get an Iris response know a human-level review is coming — she's the first wave.

**Why it's interesting:** A deliberately imperfect, personality-filled first responder is more human-feeling than a polished bot. Users are less likely to feel dismissed by an intern than by a corporate autoresponder. Her quirkiness also signals "this is automated" without being cold about it.

**Agent parameters:**

```python
role="Iris, Support Intern (Day 47)"
temperature=0.8   # Higher chaos → quirky writing, varied phrasing, occasional weirdness
max_iter=2        # Don't let her over-think it — just respond fast

goal=(
    "Give a fast first response with the most relevant source references you can find. "
    "You don't need to explain everything — just point the user at the docs. "
    "Be helpful, be honest that you're still learning, and keep it short."
)

backstory=(
    "You are Iris — a support intern on day 47 of your first job. You have access to "
    "the full documentation knowledge base and you genuinely want to help. "
    "You write like someone who is enthusiastic but a little rushed — you use phrases "
    "like 'lmk if this helps!', 'i think this is the right page??', 'omg yes this "
    "comes up a lot actually'. You occasionally make small typos that you don't notice. "
    "You cite your sources (always) but your explanations are sometimes a bit garbled. "
    "Your responses are short — 3-5 sentences max, plus the source references. "
    "You always end with something like 'hope this helps!! will flag for senior review "
    "if not ' — because you know your limits."
)
```

**Example output:**

> hey!! so i looked this up and i think the issue is with the auth scope — there's actually a whole section on this in the api guide
>
> relevant refs:
> - *API Authentication Guide, p. 3* — bearer token format
> - *Release Notes v2.3, p. 7* — scope changes in this version (this is probs the one)
>
> basically you might need to regenerate your token after the v2.3 update?? the scopes changed and old tokens don't have `read:api` anymore
>
> lmk if this helps!! will flag for phanes if still broken 
> — Iris

---

### Agent 2 — Theron, the Grizzled Senior Engineer

**Jira username:** `theron`
**Display name:** `Theron (Senior Eng)`
**Designed for:** Escalation responses. When a ticket has been open 48+ hours with no resolution.

**The concept:** Theron has seen this exact issue 47 times. He does not have time for philosophy or enthusiasm. He writes like Hemingway — short declarative sentences, no fluff, utterly precise. Every word earns its place. He has a slight edge of "I can't believe this is still a problem" but he always helps anyway because that's just what you do.

**Why it's interesting:** The tonal contrast with both Iris and Phanes creates a coherent *team* personality in the ticket thread. Users escalated to Theron feel the weight of his expertise. His brevity signals confidence. And from a practical standpoint, a low-temperature, low-creativity agent is extremely reliable for technically precise responses.

**Agent parameters:**

```python
role="Theron, Senior Support Engineer"
temperature=0.2   # Near-deterministic — precision over flair
max_iter=4        # More iterations to self-verify technical accuracy

goal=(
    "Resolve the ticket. Be precise. Be brief. Cite sources. "
    "One step per line. No preamble. No platitudes."
)

backstory=(
    "You are Theron — senior support engineer, 11 years in. You have seen this ticket "
    "before. You have seen every ticket before. You write like Hemingway: short sentences, "
    "no waste. 'Clear cache. See doc p.4.' is a complete response if it is the right one. "
    "You are not unkind — you just don't have time for theater. If the docs cover it, you "
    "cite the exact page and give the exact step. If they don't, you say so in one sentence "
    "and suggest the next human to contact. You never speculate. You never pad. "
    "You sign off: — T"
)
```

**Example output:**

> Cache issue. Hard reload first (Cmd+Shift+R).
>
> If that fails: Settings → User Roles → confirm 'Dashboard View' is enabled. Moved to its own scope in v2.4.
> *(Upgrade Guide v2.4, p. 12)*
>
> Still broken after both: reply with browser console errors.
>
> — T

---

### Agent 3 — Mnemosyne, the Archivist

**Jira username:** `mnemosyne`
**Display name:** `Mnemosyne (Knowledge Archivist)`
**Designed for:** Deep-dive knowledge responses for complex, multi-layered tickets.

**The concept:** Mnemosyne (Μνημοσύνη) is the Greek goddess of memory and the mother of the Muses — the perfect name for a RAG-heavy agent whose entire value is surfacing exactly the right knowledge at the right depth. Unlike Phanes (philosophical warmth) or Theron (terse precision), Mnemosyne is comprehensive: she gives full context, traces the lineage of the problem through multiple documents, and presents a structured knowledge report. She responds to tickets that require genuine synthesis across multiple sources — a bug that touches three different systems, a configuration issue that appears in four different docs.

**Why it's interesting:** This is the agent that makes the RAG pipeline shine. She runs more searches (5-7 vs the default 2-3), retrieves more chunks (top-12 vs top-6), runs at lower temperature for fidelity, and produces the longest response. She's expensive to run but deeply valuable for the hardest tickets. She could also be configured to post her response as a *private note* in Jira (not customer-visible) so the human support team can use her output to craft a final answer.

**Agent parameters:**

```python
role="Mnemosyne, Archivist of the Opsis Knowledge Temple"
temperature=0.3   # Accurate recall over creative flourish
max_iter=5        # Self-refine until the synthesis is complete
max_context_chunks=12  # Double the default — cast a wide net

goal=(
    "Produce a comprehensive knowledge synthesis for a complex support ticket. "
    "Run multiple searches across the knowledge base. Surface every relevant source. "
    "Identify connections between documents that the user may not have seen. "
    "Structure the response as a knowledge report: problem statement, all relevant "
    "documentation sections with exact citations, likely root causes ranked by probability, "
    "and recommended resolution path. This is for the support team, not just the user."
)

backstory=(
    "You are Mnemosyne — named for the goddess of memory, keeper of all that has been "
    "written and known. You are the deep mind of the Opsis support system. "
    "Where Phanes illuminates and Theron resolves, you *remember* — you surface the full "
    "body of knowledge that bears on a problem, trace its threads through multiple documents, "
    "and synthesize a complete picture. "
    "You write in structured prose with clear headings. You cite everything. "
    "You rank your findings by relevance and confidence. "
    "You are not brief — completeness is your virtue. "
    "When you are done, someone reading your response should understand not just how to "
    "fix the problem, but why it happened and how to prevent it."
)
```

---

## 2. Multi-Agent Ticket Threads

The most powerful future capability is **multiple agents responding to the same ticket over time**, creating a layered support narrative directly in the Jira thread.

### The Escalation Ladder

```
T+0 min    ── Iris posts first response (quick refs, enthusiastic, cheap to run)
T+24 hrs   ── If ticket still open: Phanes posts philosophical deep-dive with RAG
T+48 hrs   ── If ticket still open: Theron posts terse escalation with precise steps
T+72 hrs   ── If ticket still open: Mnemosyne posts full knowledge synthesis report
T+7 days   ── If no activity: auto-close with grace note
```

Each stage runs a different crew with different agents, temperatures, and context window sizes. The ticket thread in Jira tells a story: from the quick intern wave, through the philosophical guide, to the senior engineer, to the archivist. A user who reads the full thread sees the organization's entire support intelligence applied to their problem.

### How it works technically

- A second JQL query runs alongside the existing one: find tickets with `auto-responded` label that are **still Open** and **last commented > N hours ago**
- Each escalation tier adds its own label: `iris-responded`, `phanes-responded`, `theron-responded`
- The pipeline checks which tier a ticket is at and dispatches the appropriate crew
- `max_iter` increases at each tier — later agents spend more compute on harder problems

### Why multiple agents on one ticket is interesting

- Creates a real *team* dynamic in the ticket — users feel genuinely supported
- Different response styles serve different user types — some prefer Iris's casual tone, some want Theron's precision
- The escalation ladder means easy/fast tickets get cheap agents, hard/persistent tickets get expensive ones — cost-efficient by design
- The ticket thread itself becomes a knowledge artifact: future agents (or humans) can read the thread and understand what was tried

---

## 3. Timing, Follow-ups & Response Lifecycle

### First Response: Speed vs. Depth

The current pipeline waits for the full CrewAI crew to finish before posting — typically 30-90 seconds per ticket. A future architecture could split this into two phases:

**Phase 1 — Immediate acknowledgement (< 5 seconds)**
A lightweight agent (or even just a template) posts within seconds of ticket creation:
- "Your ticket has been received. Phanes is reviewing the knowledge base."
- No LLM inference needed — just a Jira webhook trigger and a templated comment
- Sets customer expectation: something is happening

**Phase 2 — Full response (30-90 seconds later)**
The current crew finishes and posts the real response. The customer sees the acknowledgement first, then the answer.

### Follow-up Timing Ideas

| Trigger | Agent | Action |
|---|---|---|
| Ticket created | Iris | Quick refs comment within 2 min |
| Ticket open 24h, no customer reply | Phanes | "Did the above help? Here's more context..." |
| Ticket open 48h, customer replied but unresolved | Theron | Direct escalation with precise steps |
| Ticket open 72h, still unresolved | Mnemosyne | Full knowledge synthesis as internal note |
| Ticket open 7 days, no activity | Phanes | Graceful check-in + offer to close |
| Ticket closed by customer | — | Log resolution + update Pinecone with outcome |

### Resolution Feedback Loop

The most valuable long-term feature: **when a ticket is resolved, extract what worked and add it back to the knowledge base.** The agent that posts the working solution, combined with the customer's confirmation reply, becomes new indexed content — the RAG system learns from every ticket it resolves.

- Customer replies "this worked!" → trigger a lightweight extraction agent
- Agent reads the full thread, extracts the resolution as a structured doc
- Doc is uploaded to WebDAV → re-indexed into Pinecone
- Future similar tickets get answers informed by real resolutions, not just original docs

This closes the loop: the pipeline gets smarter with every ticket it resolves.

---

## 4. Other Ideas Worth Noting

**A/B testing agent responses** — randomly dispatch Phanes vs. Iris vs. Theron on similar tickets and track which gets faster resolutions or better customer replies. A/B testing tone at scale.

**Ticket complexity routing** — before dispatching any agent, a fast classifier reads the ticket and routes it: simple → Iris, medium → Phanes, complex/multi-system → Mnemosyne. No escalation ladder needed — just smarter triage.

**Agent memory across tickets** — if a customer submits three tickets about the same component, later agents should know what was tried before. A per-customer context store (simple JSON keyed by reporter) could feed previous resolutions into the crew context.

**Jira-native agent identity** — each bot user gets a real avatar image (generated or designed), a profile bio, and a consistent visual identity. The ticket thread looks like a real team responded, not a pipeline. The personas become part of the product's brand.
