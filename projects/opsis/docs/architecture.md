---
layout: page
title: Opsis Architecture
permalink: /projects/opsis/docs/architecture/
---

#  Architecture

## Overview

This system is a local-first, event-driven RAG pipeline. All components run in Docker containers on your machine. No cloud services required.

---

## Component Map

```
  Mac Host
  ┌──────────────────────────────────────────────────────────────────┐
  │                                                                  │
  │   ┌─────────────────────────────────────────────────────────┐   │
  │   │                Docker Network: mvp-net                   │   │
  │   │                                                          │   │
  │   │  ┌─────────────────┐   ┌────────────────────────────┐   │   │
  │   │  │      Jira        │   │  WebDAV volume (shared)    │   │   │
  │   │  │  :8080           │   │                            │   │   │
  │   │  │                  │   │  ┌──────────┐ ┌─────────┐  │   │   │
  │   │  │  ┌────────────┐  │   │  │  WebDAV  │ │File     │  │   │   │
  │   │  │  │ Postgres   │  │   │  │  :8081   │ │Browser  │  │   │   │
  │   │  │  │ DB :5432   │  │   │  │          │ │:8082    │  │   │   │
  │   │  │  └────────────┘  │   │  │ PDF store│ │Browser  │  │   │   │
  │   │  └────────┬─────────┘   │  │ (WebDAV) │ │upload UI│  │   │   │
  │   │           │              │  └────┬─────┘ └─────────┘  │   │   │
  │   │           │              │       │  bytemark/webdav    │   │   │
  │   │           │              │       │  coderaiser/cloudcmd│   │   │
  │   │           │              └───────┼────────────────────┘   │   │
  │   │           │                      │                         │   │
  │   │           │         ┌────────────────────┐                 │   │
  │   │           │         │  PineconeDB     │                 │   │
  │   │           │         │  ctrl :5080         │                 │   │
  │   │           │         │  data :5081         │                 │   │
  │   │           │         │  Vector Index       │                 │   │
  │   │           │         │  ticket-knowledge   │                 │   │
  │   │           │         └──────────┬──────────┘                 │   │
  │   │           │                    │                             │   │
  │   │  ┌────────▼────────────────────▼──────────────────────┐    │   │
  │   │  │                   Pipeline App                      │    │   │
  │   │  │               (CrewAI + Python)                     │    │   │
  │   │  │   app/Dockerfile                                     │    │   │
  │   │  │                                                      │    │   │
  │   │  │  ┌───────────────┐    ┌─────────────────────────┐   │    │   │
  │   │  │  │ Polling Loop  │    │  PDF Indexer (one-off)   │   │    │   │
  │   │  │  │  main.py      │    │  scripts/index-pdfs.sh   │   │    │   │
  │   │  │  └──────┬────────┘    └─────────────────────────┘   │    │   │
  │   │  │         │                                             │    │   │
  │   │  │  ┌──────▼────────────────────────────────────────┐   │    │   │
  │   │  │  │             CrewAI Support Crew                │   │    │   │
  │   │  │  │                                                │   │    │   │
  │   │  │  │  Agent 1        Agent 2            Agent 3    │   │    │   │
  │   │  │  │  Ticket      ─► Knowledge      ─►  Response   │   │    │   │
  │   │  │  │  Analyzer       Retriever          Writer     │   │    │   │
  │   │  │  └──────────────────────┬─────────────────────────┘   │    │   │
  │   │  └─────────────────────────│─────────────────────────────┘    │   │
  │   └─────────────────────────────│──────────────────────────────────┘   │
  │                                 │ host.docker.internal:11434            │
  │                    ┌────────────▼─────────────┐                        │
  │                    │   Ollama  (native Mac)    │                        │
  │                    │   ollama serve  :11434    │                        │
  │                    │                           │                        │
  │                    │   llama3.1:8b      (LLM)  │                        │
  │                    │   nomic-embed-text (embed)│                        │
  │                    │   Metal GPU (Apple Silicon│                        │
  │                    └───────────────────────────┘                        │
  └──────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Indexing Flow (one-time / on-demand)

```
WebDAV Server
    │
    │  HTTP (webdavclient3)
    ▼
PDFIndexer.run()
    │
    │  List all .pdf files
    ▼
For each PDF:
    │
    ├─► Download to local cache (app/data/pdfs/)
    │
    ├─► Extract text (pdfplumber, page by page)
    │
    ├─► Chunk text (300 words, 50-word overlap)
    │
    ├─► Generate embedding via Ollama
    │   POST /api/embeddings {model: nomic-embed-text}
    │   → float[768]
    │
    └─► Upsert to PineconeDB
        {id: "filename_page_chunk", values: [...], metadata: {source, page, text}}
```

### Ticket Response Flow (continuous polling)

```
main.py polling loop (every POLL_INTERVAL_SECONDS)
    │
    ▼
Jira REST API — JQL query
    "project=SUP AND statusCategory != Done
     AND comment is EMPTY ORDER BY created ASC"
    │
    ▼
For each unresponded ticket:
    │
    ▼
support_crew.py — kickoff CrewAI
    │
    ├─► Task 1: Ticket Analyzer
    │     Tool: JiraFetchTool
    │     Input: ticket_key
    │     Output: structured ticket summary (JSON)
    │
    ├─► Task 2: Knowledge Retriever
    │     Tool: RAGSearchTool + EmbeddingTool
    │     Input: ticket summary text
    │     Process:
    │       1. Generate embedding of ticket text (Ollama)
    │       2. Query Pinecone for top-6 chunks
    │       3. Return chunks with source filenames
    │     Output: list of {text, source_file, page}
    │
    └─► Task 3: Response Writer — Phanes
          Tool: JiraCommentTool
          Input: ticket summary + retrieved context
          Process:
            1. Prompt Ollama LLM with full agent backstory (persona prompt)
            2. Draft response in the voice of Phanes (Stoic philosopher tone)
            3. Include PDF citations, step-by-step guidance, source references
            4. Post comment to Jira ticket as the `phanes` bot user
          Output: posted comment (confirmation)

          Agent identity is defined in app/agents/response_writer.py:
            role        → "Phanes, Oracle of the Opsis Support Temple"
            backstory   → Full Stoic character prompt with philosopher quotes
                          and a few-shot example response
            goal        → Warm, cited, 200–350 words, signed "— Phanes"
            temperature → 0.6  (higher than other agents for creative voice)

          The backstory is the most influential parameter — it functions as
          a persistent system-level character prompt injected into every LLM
          call the agent makes. Swapping the backstory changes the entire
          voice of every generated response without touching any other code.
```

---

## Design Decisions

### Why PineconeDB instead of Chroma/Qdrant?

PineconeDB is Pinecone's official local development server. It uses the **exact same API** as Pinecone Cloud, meaning this MVP can be moved to cloud Pinecone with zero code changes — just swap `PINECONE_HOST` to the cloud endpoint.

**Important limitation — no persistence:** PineconeDB is in-memory only. Every container restart wipes all vectors. There is no environment variable or volume mount that enables persistence (the `pinecone-data` volume in `docker-compose.yml` has no effect).

The pipeline handles this automatically via `ensure_index_populated()` in `main.py`, which runs on every boot, checks the vector count, and re-runs the PDF indexer if the index is empty. This is controlled by the `AUTO_REINDEX_ON_STARTUP` setting (default: `true`).

To disable auto-reindex and manage it manually:
```
# .env
AUTO_REINDEX_ON_STARTUP=false

# Then run manually:
docker compose exec pipeline python -m indexer.pdf_indexer
```

### Why Ollama for both LLM and embeddings?

Keeps everything local and avoids any API costs or rate limits. `nomic-embed-text` produces 768-dimensional embeddings with excellent retrieval quality for technical documents.

### Why CrewAI?

CrewAI makes it easy to decompose the pipeline into clear agent responsibilities. Each agent has a single job, making the system easy to debug and extend (e.g., adding a "ticket classifier" agent or a "human escalation" agent later).

### Response Writer Persona System

The Response Writer agent's output is shaped entirely by its `role`, `goal`, `backstory`, and `temperature` fields — no fine-tuning or model changes required. The current persona is **Phanes**, a Stoic philosopher, defined in `app/agents/response_writer.py`.

The `backstory` field functions as a persistent system-level character prompt. It is injected into every LLM call the agent makes, shaping vocabulary, sentence structure, tone, and sign-off. The backstory for Phanes includes:
- Character origin (Greek deity of light, root of "opsis")
- Philosophical tradition (Marcus Aurelius, Epictetus, Seneca with specific quotes)
- An explicit note that Stoics are *warm*, not cold
- A full few-shot example response showing exactly the target tone and structure

**Reporter-identity routing (future):** Because each agent persona is just a Python function returning an `Agent` object, different personas can be dispatched based on who filed the ticket. The ticket's `reporter` field (fetched in Task 1) can drive which `make_*_agent()` function is called in Task 3 — a VIP customer gets Phanes, an internal engineer gets a terse senior-engineer voice, a first-time user gets a friendly intern. See [`docs/future-steps.md`](../future-steps/) for the full multi-agent roadmap and [`docs/custom_response_agent_context.md`](../custom-llm-agent-context/) for the persona design reference.

### Why poll instead of webhooks?

For a local MVP, polling Jira is simpler — no ngrok/tunnel required. The interval is configurable. When moving to production, replace the polling loop with a Jira webhook listener.

### Why not LangChain?

CrewAI is built on LangChain but provides a higher-level abstraction (agents with roles, goals, backstories) that maps naturally to this workflow. Less boilerplate for multi-agent setups.

---

## Extending the MVP

| Extension | How |
|---|---|
| More agents | Add a "Ticket Classifier" or "Escalation Decider" agent to `agents/` |
| More knowledge sources | Extend `PDFIndexer` to ingest Confluence pages or Notion docs |
| Cloud Pinecone | Change `PINECONE_HOST` to your Pinecone cloud endpoint — zero code changes needed |
| Persistent local vectors | Swap PineconeDB for Qdrant (`qdrant/qdrant` Docker image has full disk persistence, same REST API shape) |
| Webhooks instead of polling | Replace polling loop in `main.py` with FastAPI webhook endpoint |
| Better LLM | Swap model name in `.env` — any Ollama model works |
| Slack notification | Add a Slack tool that notifies the team when auto-response is posted |
| Different response personas | Add more agent definitions to `agents/`, route by reporter identity or ticket priority |
| Multi-agent ticket threads | Dispatch Iris (fast refs) → Phanes (deep dive) → Theron (escalation) on the same ticket over time |

---

## Port Reference

| Port | Service | Notes |
|---|---|---|
| `8080` | Jira Web UI | Main ticket interface |
| `5432` | Jira Postgres | Internal, not exposed |
| `8081` | WebDAV | Upload/browse PDFs here |
| `5080` | PineconeDB | Vector DB REST API |
| `11434` | Ollama | LLM + embedding inference |
