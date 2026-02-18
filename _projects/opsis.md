---
layout: project
title: Opsis
tagline: Opsis (ὄψις), from ὁράω — “to see,” is a containerized local AI Jira ticket first responder that answers with retrieved context, not hallucinated guesses.
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

## Overview

Opsis is a local-first AI support operations project for teams that want grounded Jira responses without relying on cloud LLM infrastructure.

It runs end-to-end on one machine and simulates a production-style support workflow: documents are ingested, indexed, retrieved, and cited in ticket responses.

Installation & Setup Docs: [Opsis docs hub]({{ '/projects/opsis/docs/' | relative_url }}).

---

## Why It Exists

Most support automation demos skip realistic data lifecycle and observability. Opsis is designed to test the full loop under practical conditions:

- Tickets arrive in Jira (`:8080`).
- Team docs are managed through WebDAV and FileBrowser (`:8082`).
- Knowledge retrieval runs through PineconeDB (`:5080`).
- Generation and embeddings run in Ollama (`:11434`) on host-native runtime.


This gives a controlled environment for validating retrieval quality, model behavior, and response consistency before broader rollout.

---

## How It Works

### Ingestion Path

1. Generate or upload PDF documentation.
2. Indexer extracts and chunks text.
3. Embeddings are produced with Ollama.
4. Vectors and metadata are stored in PineconeDB.

Read more: [Generate Synthetic PDFs]({{ '/projects/opsis/docs/generate-synthetic-pdfs/' | relative_url }}), [PDF Indexing Explainer]({{ '/projects/opsis/docs/pdf-indexing-explainer/' | relative_url }}), [PineconeDB Issues]({{ '/projects/opsis/docs/pinecone-local-issues/' | relative_url }}).

### Response Path

1. Pipeline polls Jira for unresponded tickets.
2. Analyzer structures ticket context.
3. Retriever finds top relevant chunks.
4. Writer drafts a cited first response using CrewAI response-agent parameters (`role`, `goal`, `backstory`, `temperature`) tied to the configured Jira bot identity.
5. Comment is posted back to Jira under that bot identity (for example, Phanes) so persona and authorship are explicit in-thread.

```text
Jira Ticket -> Analyzer -> Retriever (RAG) -> Writer -> Jira Comment
```

Read more: [Opsis Architecture]({{ '/projects/opsis/docs/architecture/' | relative_url }}), [Opsis Setup Checkpoints]({{ '/projects/opsis/docs/checkpoints/' | relative_url }}).

---

## Architecture At A Glance

### Runtime Topology

- Mac host runs Ollama natively (`:11434`) for local LLM + embedding inference.
- Docker network `mvp-net` contains Jira (`:8080`) with Postgres (`:5432`), WebDAV (`:8081`), FileBrowser (`:8082`), PineconeDB control (`:5080`) and data plane (`:5081`), and the Pipeline app container.
- WebDAV and FileBrowser share the same document volume for upload + ingestion workflow continuity.

### Component Map (ASCII)

```text
Mac Host
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Docker Network: mvp-net                                             │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Jira :8080 + PG :5432   WebDAV :8081 + FileBrowser :8082      │  │
│  │ PineconeDB ctrl :5080 / data :5081                             │  │
│  │                                                                │  │
│  │ Pipeline App (CrewAI + Python)                                 │  │
│  │ ┌──────────────┐  ┌────────────────┐  ┌───────────────┐        │  │
│  │ │ Ticket       │->│ Knowledge      │->│ Response      │        │  │
│  │ │ Analyzer     │  │ Retriever      │  │ Writer        │        │  │
│  │ └──────────────┘  └────────────────┘  └───────────────┘        │  │
│  │      ^                        |                                  │  │
│  │      |                        v                                  │  │
│  │  main.py poll loop    PDF Indexer (one-off)                     │  │
│  │                      scripts/index-pdfs.sh                       │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                |                                     │
│                                | host.docker.internal                │
│                                v                                     │
│                       Ollama (native) :11434                         │
│                       llama3.2 + nomic-embed                         │
└──────────────────────────────────────────────────────────────────────┘
```

### Pipeline App Breakdown

- `app/main.py`: continuous polling loop (`POLL_INTERVAL_SECONDS`) for unresponded Jira tickets.
- `app/crew/support_crew.py`: CrewAI orchestration across Ticket Analyzer -> Knowledge Retriever -> Response Writer.
- `app/indexer/pdf_indexer.py`: one-off/on-demand indexing path used by `scripts/index-pdfs.sh`.
- `app/tools/jira_tool.py`: fetches ticket context and posts final response comments.
- `app/tools/rag_tool.py` + `app/tools/embeddings.py`: query embedding + top-k retrieval from PineconeDB.

### Data Flow Details

- Indexing flow: list PDFs from WebDAV -> download to cache -> extract text by page -> chunk (`512` tokens, `64` overlap) -> embed with `nomic-embed-text` -> upsert vectors + metadata (`source`, `page`, `text`).
- Response flow: Jira JQL polling (`statusCategory != Done` and empty comment) -> ticket analysis -> embedding + retrieval (`top-6`) -> cited response draft (persona shaped by response-agent parameters) -> Jira bot comment post.

Read more: [Opsis Architecture]({{ '/projects/opsis/docs/architecture/' | relative_url }}), [Opsis Relevant Files]({{ '/projects/opsis/docs/relevant-files/' | relative_url }}), and [Opsis Code Snippets]({{ '/projects/opsis/docs/snippets/' | relative_url }}).

---

## Deep Dives

- Project overview and file map: [Opsis MVP README]({{ '/projects/opsis/docs/readme/' | relative_url }}).
- Installation & Setup Docs: [Opsis Setup Guide]({{ '/projects/opsis/docs/setup-guide/' | relative_url }}), [Jira Docker Setup]({{ '/projects/opsis/docs/docker-jira/' | relative_url }}), [WebDAV and FileBrowser Setup]({{ '/projects/opsis/docs/docker-webdav-filebrowser/' | relative_url }}), [PineconeDB Docker Setup]({{ '/projects/opsis/docs/docker-pinecone-local/' | relative_url }}), [Ollama Setup Notes]({{ '/projects/opsis/docs/docker-ollama/' | relative_url }}).
- Model and retrieval research: [Ollama Embedding Research]({{ '/projects/opsis/docs/ollama-embedding-research/' | relative_url }}), [Ollama Model Research]({{ '/projects/opsis/docs/ollama-models-research/' | relative_url }}), [Custom LLM Agent Model (Phanes)]({{ '/projects/opsis/docs/custom-llm-agent/' | relative_url }}), [Custom LLM Agent Context (Phanes)]({{ '/projects/opsis/docs/custom-llm-agent-context/' | relative_url }}), [Future Implementation and TODOs]({{ '/projects/opsis/docs/future-implementation-todos/' | relative_url }}), [Future Steps]({{ '/projects/opsis/docs/future-steps/' | relative_url }}), and [Ollama API Test Commands]({{ '/projects/opsis/docs/ollama-test-api/' | relative_url }}).
- Validation and execution checks: [Opsis Setup Checkpoints]({{ '/projects/opsis/docs/checkpoints/' | relative_url }}).
