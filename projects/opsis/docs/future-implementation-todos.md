---
layout: page
title: Future Implementation and TODOs
permalink: /projects/opsis/docs/future-implementation-todos/
---

# Future Implementation and TODOs

This page summarizes the forward-looking roadmap in [Future Steps]({{ '/projects/opsis/docs/future-steps/' | relative_url }}).

## Scope

These are design-space ideas, not current MVP behavior.

## Planned Direction

- Multi-agent ticket responses over time, not just one immediate response.
- Distinct Jira bot identities per agent persona (for example: Phanes, Iris, Theron, Mnemosyne).
- Routing by ticket complexity and lifecycle stage.
- Faster first-touch acknowledgments, followed by deeper async responses.

## Proposed Agent Roles

- **Phanes**: philosophical, warm, grounded first-response writer.
- **Iris**: early-stage exploratory or playful assistant for simple tickets.
- **Theron**: low-temperature precision responder for complex technical clarity.
- **Mnemosyne**: long-form memory/knowledge synthesizer across many sources.

## Implementation TODOs

- Add classifier-driven dispatch before crew selection.
- Add escalation ladder with time-based triggers (for example: T+24h, T+72h).
- Add staged response strategy: immediate short response + delayed deep response.
- Add A/B testing framework for response tone/persona effectiveness.
- Add Jira private-note mode for long-form knowledge reports.
- Add metrics for resolution speed, follow-up rate, and citation usefulness.

## Engineering Notes

- Preserve deterministic agents for analysis/retrieval tasks.
- Keep response-writer persona behavior tied to CrewAI parameters (`role`, `goal`, `backstory`, `temperature`).
- Keep Jira user identity aligned to persona so thread authorship stays explicit.

## Read Full Source

- [Future Steps]({{ '/projects/opsis/docs/future-steps/' | relative_url }})
- [Custom LLM Agent Model (Phanes)]({{ '/projects/opsis/docs/custom-llm-agent/' | relative_url }})
- [Custom LLM Agent Context (Phanes)]({{ '/projects/opsis/docs/custom-llm-agent-context/' | relative_url }})
