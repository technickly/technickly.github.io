---
layout: page
title: Opsis Setup Checkpoints
permalink: /projects/opsis/docs/checkpoints/
---

> Imported from `CHECKPOINTS.md`

#  Checkpoints

Track your progress. Check off each item as you verify it.

---

## Phase 1 — Infrastructure

### 1.1 Docker
- [ ] `docker --version` returns v24+
- [ ] `docker compose version` returns v2+

### 1.2 Ollama (Native Mac)
- [ ] `brew install ollama` complete
- [ ] `ollama serve` running in a terminal tab
- [ ] `ollama pull llama3.2:latest` complete (~2 GB)
- [ ] `ollama pull nomic-embed-text:latest` complete (~274 MB)
- [ ] `ollama list` shows both models
- [ ] LLM test returns a response (see SETUP_GUIDE Step 3)
- [ ] Embedding test prints `dims: 768`

### 1.3 Jira Postgres
- [ ] `docker compose up -d jira-db` runs without error
- [ ] `docker compose ps` shows `jira-db` as `Up (healthy)`
- [ ] `docker exec jira-db psql -U jira -d jiradb -c "SELECT version();"` returns Postgres version

### 1.4 Jira
- [ ] `docker compose up -d jira` runs without error
- [ ] http://localhost:8080 loads in browser
- [ ] Setup wizard completed (license entered)
- [ ] Admin account created, email noted in `.env`
- [ ] Project created with key `SUP` (or your key) in `.env`
- [ ] API token generated and saved to `.env` as `JIRA_API_TOKEN`
- [ ] Verify: `curl -u email:token http://localhost:8080/rest/api/2/project/SUP` returns JSON

### 1.5 WebDAV
- [ ] `docker compose up -d webdav` runs without error
- [ ] `curl -u admin:admin123 http://localhost:8081/` returns a response

### 1.6 FileBrowser
- [ ] `docker compose up -d filebrowser` runs without error
- [ ] http://localhost:8082 loads in browser
- [ ] Login with `admin` / `admin` works
- [ ] Can see and upload files via the UI

### 1.7 PineconeDB
- [ ] `docker compose up -d pinecone-local` runs without error
- [ ] `curl http://localhost:5080/indexes` returns `{"indexes": []}`

---

## Phase 2 — Knowledge Base

### 2.1 PDF Generation / Upload
- [ ] At least 1 PDF in `app/data/pdfs/` (generated or real)
- [ ] PDF(s) visible in FileBrowser at http://localhost:8082

### 2.2 Indexing
- [ ] `docker compose exec pipeline python -m indexer.pdf_indexer` runs without errors
- [ ] `curl http://localhost:5080/indexes` shows `ticket-knowledge` index
- [ ] `curl http://localhost:5081/describe_index_stats` shows `totalVectorCount > 0`

> **Auto-reindex on startup:** The pipeline checks Pinecone on every boot and
> re-indexes automatically if the index is empty. PineconeDB is in-memory only —
> every container restart wipes vectors. You no longer need to run the indexer
> manually after a restart.
> To disable: set `AUTO_REINDEX_ON_STARTUP=false` in `.env`.

---

## Phase 3 — Pipeline

### 3.1 Build + Start
- [ ] `docker compose up -d pipeline` builds and starts without error
- [ ] `docker compose logs pipeline` shows `Polling Jira for new tickets...`
- [ ] No `ConnectionError` or `ImportError` in logs

### 3.2 End-to-End Test
- [ ] Created a Jira ticket with description related to PDF content
- [ ] Pipeline log shows ticket was picked up within 60s
- [ ] Pipeline log shows `Retrieved X relevant PDF chunks`
- [ ] Pipeline log shows `Posted comment to SUP-XX ✓`
- [ ] Jira ticket has AI-generated comment with PDF citation

### 3.3 Response Persona (Phanes)
- [ ] Comment is posted by the `phanes` Jira bot user (not the admin account)
- [ ] Comment opens with a philosophical observation or framing sentence
- [ ] Response cites at least one source as `*(filename.pdf, p. N)*`
- [ ] Response is signed `— Phanes, Opsis Support`
- [ ] Ticket is labelled `auto-responded` after comment is posted
- [ ] Re-running the pipeline does NOT post a duplicate comment on the same ticket

> **Tuning the response voice:** Edit `app/agents/response_writer.py` — the `backstory` field
> is the primary lever. `temperature` controls creativity (0.6 = philosophical, 0.3 = generic).
> No rebuild required — the app folder is volume-mounted; restart the container to apply changes.
> See [`docs/custom_response_agent_context.md`](../custom-llm-agent-context/) for full
> parameter reference and before/after response examples.

---

## Phase 4 — Validation
- [ ] Comment references at least one PDF filename
- [ ] Response is coherent and relevant to the ticket
- [ ] Pipeline continues polling after first successful response
- [ ] `docker compose restart pipeline` — startup log shows `✓ Pinecone index ready` or auto-indexes
- [ ] `docker compose down && docker compose up -d` — pipeline re-indexes automatically on next boot

> **Note on Pinecone persistence:** PineconeDB is in-memory only. Restarting the
> `pinecone-local` container always wipes all vectors. The pipeline handles this
> automatically via `ensure_index_populated()` at startup (controlled by
> `AUTO_REINDEX_ON_STARTUP` in `.env`). Jira data and WebDAV PDFs are unaffected —
> they use proper named volumes (`jira-data`, `webdav-data`).

---

##  Status Summary

| Phase | Status |
|---|---|
| 1.1 Docker |  Complete |
| 1.2 Ollama Native |  Complete |
| 1.3 Jira Postgres |  Complete |
| 1.4 Jira |  Complete |
| 1.5 WebDAV |  Complete |
| 1.6 FileBrowser |  In progress |
| 1.7 PineconeDB |  Complete |
| 2 Knowledge Base |  Not started |
| 3 Pipeline |  Not started |
| 4 Validation |  Not started |

>  Not started →  In progress →  Complete →  Blocked
