---
layout: page
title: Opsis Architecture
permalink: /projects/opsis/docs/architecture/
---

> Imported from `ARCHITECTURE.md`

#  Architecture

## Overview

This system is a local-first, event-driven RAG pipeline. All components run in Docker containers on your machine. No cloud services required.

---

## Component Map

```
┌─────────────────────────────────────────────────────┐
│                  Docker Network: mvp-net             │
│                                                      │
│  ┌──────────┐    ┌──────────┐    ┌───────────────┐  │
│  │  Jira    │    │  WebDAV  │    │ Pinecone Local│  │
│  │ :8080    │    │ :8081    │    │    :5080      │  │
│  │          │    │          │    │               │  │
│  │ Postgres │    │ PDF      │    │ Vector Index  │  │
│  │ DB :5432 │    │ Storage  │    │ ticket-know.. │  │
│  └────┬─────┘    └────┬─────┘    └──────┬────────┘  │
│       │               │                 │            │
│       │         ┌─────┘                 │            │
│       │         │                       │            │
│  ┌────▼─────────▼───────────────────────▼─────────┐  │
│  │                  Pipeline App                   │  │
│  │              (CrewAI + Python)                  │  │
│  │                                                 │  │
│  │  ┌──────────────┐   ┌──────────────────────┐   │  │
│  │  │ Polling Loop │   │  PDF Indexer (once)  │   │  │
│  │  │ main.py      │   │  indexer/            │   │  │
│  │  └──────┬───────┘   └──────────────────────┘   │  │
│  │         │                                       │  │
│  │  ┌──────▼──────────────────────────────────┐   │  │
│  │  │           CrewAI Support Crew            │   │  │
│  │  │                                          │   │  │
│  │  │  Agent 1          Agent 2        Agent 3 │   │  │
│  │  │  Ticket           Knowledge      Response│   │  │
│  │  │  Analyzer      ─► Retriever   ─► Writer  │   │  │
│  │  └──────────────────────────────────────────┘   │  │
│  └────────────────────────┬────────────────────────┘  │
│                           │                            │
│                    ┌──────▼──────┐                     │
│                    │   Ollama    │                     │
│                    │   :11434    │                     │
│                    │             │                     │
│                    │ llama3.1:8b │                     │
│                    │ nomic-embed │                     │
│                    └─────────────┘                     │
└─────────────────────────────────────────────────────┘
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
    ├─► Chunk text (512 tokens, 64-token overlap)
    │
    ├─► Generate embedding via Ollama
    │   POST /api/embeddings {model: nomic-embed-text}
    │   → float[768]
    │
    └─► Upsert to Pinecone Local
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
    └─► Task 3: Response Writer
          Tool: JiraCommentTool
          Input: ticket summary + retrieved context
          Process:
            1. Prompt Ollama LLM with context
            2. Draft professional first-response comment
            3. Include PDF citations
            4. Post comment to Jira ticket
          Output: posted comment (confirmation)
```

---

## Design Decisions

### Why Pinecone Local instead of Chroma/Qdrant?

Pinecone Local is Pinecone's official local development server. It uses the **exact same API** as Pinecone Cloud, meaning this MVP can be moved to cloud Pinecone with zero code changes — just swap `PINECONE_HOST` to the cloud endpoint.

### Why Ollama for both LLM and embeddings?

Keeps everything local and avoids any API costs or rate limits. `nomic-embed-text` produces 768-dimensional embeddings with excellent retrieval quality for technical documents.

### Why CrewAI?

CrewAI makes it easy to decompose the pipeline into clear agent responsibilities. Each agent has a single job, making the system easy to debug and extend (e.g., adding a "ticket classifier" agent or a "human escalation" agent later).

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
| Cloud Pinecone | Change `PINECONE_HOST` to your Pinecone cloud endpoint |
| Webhooks instead of polling | Replace polling loop in `main.py` with FastAPI webhook endpoint |
| Better LLM | Swap model name in `.env` — any Ollama model works |
| Slack notification | Add a Slack tool that notifies the team when auto-response is posted |

---

## Port Reference

| Port | Service | Notes |
|---|---|---|
| `8080` | Jira Web UI | Main ticket interface |
| `5432` | Jira Postgres | Internal, not exposed |
| `8081` | WebDAV | Upload/browse PDFs here |
| `5080` | Pinecone Local | Vector DB REST API |
| `11434` | Ollama | LLM + embedding inference |
