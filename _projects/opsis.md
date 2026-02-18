---
layout: project
title: Opsis
tagline: Opsis (ὄψις), from ὁράω — “to see,” is a containerized local AI Jira first responder that answers with retrieved context, not hallucinated guesses.
tech_stack:
  - CrewAI
  - Ollama
  - PineconeDB
  - Jira API
  - WebDAV
  - Docker
github_url: https://github.com/yourusername/opsis
docs_url: /projects/opsis/docs/
---

## Status

This page is seeded with starter content. The documentation section is already connected to markdown imported from `/Users/nickanderson/mvp-opsis`.

- Docs hub: [Opsis docs]({{ '/projects/opsis/docs/' | relative_url }})
- Source docs tracked: `README.md`, `ARCHITECTURE.md`, `SETUP_GUIDE.md`, `CHECKPOINTS.md`

---

## What Opsis Does

Opsis watches Jira for new support tickets, retrieves relevant context from indexed PDFs stored in WebDAV, and posts a drafted response back to the ticket.

```text
Jira Ticket -> Ticket Analyzer -> RAG Retrieval -> Response Writer -> Jira Comment
```

---

## Example Snippet (Dummy)

```python
from opsis.pipeline import run_once

result = run_once(project_key="SUP")
print(result.ticket_key, result.status)
```

---

## Relevant Files

- `app/main.py` - polling loop and orchestration entrypoint
- `app/crew/support_crew.py` - CrewAI task chain
- `app/indexer/pdf_indexer.py` - PDF chunking and vector upsert
- `app/tools/rag_tool.py` - retrieval helper for agents

---

## Screenshots

### Browser UI (replace later)

![Opsis browser UI placeholder]({{ '/assets/img/opsis-browser-ui-placeholder.svg' | relative_url }})

### Architecture

![Opsis architecture placeholder]({{ '/assets/img/opsis-architecture-placeholder.svg' | relative_url }})

### Jira Comment

![Opsis jira comment placeholder]({{ '/assets/img/opsis-jira-placeholder.svg' | relative_url }})
