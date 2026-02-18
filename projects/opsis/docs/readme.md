---
layout: page
title: Opsis MVP README
permalink: /projects/opsis/docs/readme/
---

> Imported from `README.md`

#  Jira RAG Auto-Responder — Local MVP

A fully local AI pipeline that watches Jira for new support tickets, retrieves context from PDF docs stored in a WebDAV server via RAG, and automatically posts a first-response comment back to the ticket.

---

##  Stack

| Service | Role | Port | How it runs | Docker image |
|---|---|---|---|---|
| **Jira Software** | Ticket system (source + sink) | `8080` | Docker container | `atlassian/jira-software:latest` |
| **Jira Postgres** | Jira database | `5432` | Docker container | `postgres:14-alpine` |
| **WebDAV** | PDF knowledge base storage | `8081` | Docker container | `bytemark/webdav:latest` |
| **FileBrowser** | Browser UI to upload/view PDFs | `8082` | Docker container | `coderaiser/cloudcmd:latest` |
| **Pinecone Local** | Vector store for RAG | `5080` + `5081`* | Docker container | `ghcr.io/pinecone-io/pinecone-local:latest` |
| **Ollama** | LLM + embeddings (Metal GPU) | `11434` | **Native Mac** — `ollama serve` | _(not containerized)_ |
| **PDF Generator** | Synthetic PDF creator for testing | | **Native Mac** — `python app/synthetic/pdf_generator.py` | _(not containerized)_ |
| **Indexer** | Chunk + embed PDFs, upsert into Pinecone | | **Native Mac** — `bash scripts/index-pdfs.sh` | Runs inside the Pipeline image |
| **Pipeline** | CrewAI orchestration app | | Docker container | Built from `app/Dockerfile` |

> *Pinecone Local uses port `5080` for its control plane (index management) and port `5081` for the data plane (vector upsert/query) of the first created index. See [`docs/pinecone-local-issues.md`](../pinecone-local-issues/).

> **Ollama runs natively** on the Mac host (not in Docker) to access Apple Silicon Metal GPU.
> Docker containers reach it via `http://host.docker.internal:11434`.
> See [`docker/ollama/README.md`](../docker-ollama/) for setup.

> **PDF Generator and Indexer are not long-running services.** The generator is a local Mac script invoked with `python`. The indexer is a one-off Docker run that exits after completion — it is not a persistent container.

All Docker images and their configurations are defined in [`docker-compose.yml`](../relevant-files/).

---

##  Pipeline Flow

```
New Jira Ticket
      │
      ▼
[CrewAI: Ticket Analyzer]
  → Fetches ticket via Jira API
  → Extracts: summary, description, components, priority
      │
      ▼
[CrewAI: Knowledge Retriever]
  → Embeds ticket text via Ollama (nomic-embed-text:latest)
  → Queries Pinecone Local for top-k relevant PDF chunks
  → Returns: source filenames + relevant excerpts
      │
      ▼
[CrewAI: Response Writer]
  → Uses Ollama LLM (llama3.2:latest) to draft a response
  → Cites PDF sources by filename/page
      │
      ▼
[Jira API: Post Comment]
  → Posts formatted first-response to ticket
  → Labels ticket: auto-responded
```

---

##  Quick Start

```bash
# 1. Enter project directory
cd ~/mvp-opsis

# 2. Copy and fill environment variables
cp .env.example .env
# → Edit JIRA_EMAIL, JIRA_API_TOKEN, JIRA_PROJECT_KEY

# 3. Start Ollama natively (Metal GPU)
brew install ollama
ollama serve &
ollama pull llama3.2:latest
ollama pull nomic-embed-text:latest

# 4. Start all Docker services
docker compose up -d jira-db
# wait for healthy, then:
docker compose up -d jira webdav filebrowser pinecone-local

# 5. Complete Jira setup wizard at http://localhost:8080
#    → Get eval license from https://my.atlassian.com/license/evaluate
#    → Create project, note key (e.g. SUP)
#    → Generate API token → paste into .env

# 6. Generate + upload test PDFs
cd app
python -m synthetic.pdf_generator --batch    # creates 5 PDFs in data/pdfs/
# → Upload via FileBrowser at http://localhost:8082

# 7. Index PDFs into Pinecone
bash scripts/index-pdfs.sh

# 8. Start the pipeline
docker compose up -d pipeline
docker compose logs -f pipeline
```

---

##  Project Structure

```
mvp-opsis/
├── README.md                  ← You are here
├── SETUP_GUIDE.md             ← Step-by-step walkthrough
├── CHECKPOINTS.md             ← Progress tracker
├── ARCHITECTURE.md            ← System design & data flow
├── .env.example               ← Environment variable template
├── .env                       ← Your local config (git-ignored)
├── docker-compose.yml         ← All Docker services
│
├── docker/
│   ├── jira/README.md         ← Jira setup & license notes
│   ├── webdav/README.md       ← WebDAV + FileBrowser guide
│   ├── pinecone/README.md     ← Pinecone Local setup
│   └── ollama/README.md       ← Ollama native Mac setup
│
├── app/                       ← Pipeline application
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── main.py                ← Polling loop entry point
│   ├── config/settings.py     ← Pydantic settings (reads .env)
│   ├── tools/                 ← CrewAI tool wrappers
│   │   ├── jira_tool.py       ← Fetch tickets, post comments
│   │   ├── webdav_tool.py     ← List + download PDFs
│   │   ├── rag_tool.py        ← Vector search via Pinecone
│   │   └── embeddings.py      ← Ollama embedding helper
│   ├── agents/                ← CrewAI agent definitions
│   │   ├── ticket_analyzer.py
│   │   ├── knowledge_retriever.py
│   │   └── response_writer.py
│   ├── crew/support_crew.py   ← Crew orchestration
│   ├── indexer/pdf_indexer.py ← WebDAV → chunk → embed → Pinecone
│   ├── synthetic/             ← Test PDF generator
│   │   └── pdf_generator.py
│   └── data/pdfs/             ← Local PDF cache
│
├── docs/                      ← Research & reference docs
│   ├── ollama-embedding-research.md
│   ├── ollama-models-research.md
│   └── ollama_test_api.md
│
└── scripts/
    ├── init-ollama.sh         ← Pull Ollama models
    ├── index-pdfs.sh          ← Run PDF indexer
    └── generate-pdfs.sh       ← Generate + upload test PDFs
```

---

##  Key Config (.env)

| Variable | Example | Notes |
|---|---|---|
| `JIRA_URL` | `http://localhost:8080` | Jira base URL |
| `JIRA_EMAIL` | `admin@example.com` | Jira admin email |
| `JIRA_API_TOKEN` | `MzQ2...` | Generated in Jira UI |
| `JIRA_PROJECT_KEY` | `SUP` | Your project key |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Native Ollama host |
| `OLLAMA_LLM_MODEL` | `llama3.2:latest` | LLM for response generation |
| `OLLAMA_EMBED_MODEL` | `nomic-embed-text:latest` | Embedding model for RAG |
| `PINECONE_HOST` | `http://localhost:5080` | Pinecone Local URL |

---

##  Docs

- [Setup Guide](../setup-guide/) — full step-by-step walkthrough
- [Checkpoints](../checkpoints/) — verify each stage is working
- [Architecture](../architecture/) — design decisions & data flow
- [Jira Setup](../docker-jira/)
- [WebDAV + FileBrowser](../docker-webdav-filebrowser/)
- [Pinecone Local](../docker-pinecone-local/)
- [Ollama Native Setup](../docker-ollama/)
- [Embedding Models Research](../ollama-embedding-research/)
- [LLM Models Research](../ollama-models-research/)
- [Ollama API Test Commands](../ollama-test-api/)

---

##  Prerequisites

- macOS with Apple Silicon (M1/M2/M3) or Intel
- Docker Desktop v24+ with Compose v2+
- Homebrew (for native Ollama)
- ~15 GB free disk (Jira data + Ollama models)
- ~8 GB RAM free recommended (Jira uses 2–3 GB alone)
- Free Atlassian account (for Jira eval license)
