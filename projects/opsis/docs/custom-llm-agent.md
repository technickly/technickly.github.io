---
layout: page
title: Custom LLM Agent Model (Phanes)
permalink: /projects/opsis/docs/custom-llm-agent/
---

# Custom LLM Agent Model (Phanes)

This page summarizes the custom response agent design for Opsis, based on the full source context in [Custom LLM Agent Context (Phanes)]({{ '/projects/opsis/docs/custom-llm-agent-context/' | relative_url }}).

## What It Is

Opsis uses a specialized response-writer agent called **Phanes**: a custom LLM persona grounded in a Greek philosopher-inspired voice.

The model behavior is designed to be:

- warm and direct (Marcus Aurelius style)
- practical and action-oriented (Epictetus style)
- concise and clear (Seneca style)

The tone is philosophical, but outputs remain operational support responses with concrete next steps and citations.

## Why It Matters

Compared to generic support-bot language, this model configuration improves:

- user trust and readability in first-response comments
- consistency of empathetic but factual communication
- handoff quality when escalation is needed

## Core Agent Configuration

Phanes is controlled through CrewAI agent parameters in `app/agents/response_writer.py`:

- `role`: identity and task framing
- `goal`: grounded, cited, practical response objective
- `backstory`: primary persona instruction set (highest influence)
- `temperature`: expressive but controlled generation (`0.6` target range)

Recommended operating range from the source context:

- low temperature (`0.0-0.2`) for deterministic analysis tasks
- mid temperature (`0.5-0.7`) for response-writing voice quality

## Prompt Strategy

The backstory prompt enforces a consistent response arc:

1. acknowledge user friction
2. provide clear step-by-step resolution
3. cite source material
4. escalate cleanly when coverage is incomplete

## Jira Bot Identity

To keep authorship explicit, comments should be posted by a dedicated Jira bot account (Phanes), not an admin user.

Setup and naming details are in the full source page:

- [Custom LLM Agent Context (Phanes)]({{ '/projects/opsis/docs/custom-llm-agent-context/' | relative_url }})

## Related Docs

- [Ollama Model Research]({{ '/projects/opsis/docs/ollama-models-research/' | relative_url }})
- [Ollama Embedding Research]({{ '/projects/opsis/docs/ollama-embedding-research/' | relative_url }})
- [Opsis Architecture]({{ '/projects/opsis/docs/architecture/' | relative_url }})
- [Opsis Relevant Files]({{ '/projects/opsis/docs/relevant-files/' | relative_url }})
