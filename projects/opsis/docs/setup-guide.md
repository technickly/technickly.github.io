---
layout: page
title: Opsis Setup Guide
permalink: /projects/opsis/docs/setup-guide/
---

> Imported from `SETUP_GUIDE.md`

#  Setup Guide

Follow these steps in order. Check off each item in [CHECKPOINTS.md](../checkpoints/) as you go.

---

## Step 1 — Prerequisites

- **Docker Desktop** with Compose v2 — verify: `docker --version` and `docker compose version`
- **Homebrew** — verify: `brew --version`
- **Python 3.11+** — for running the synthetic PDF generator locally
- ~15 GB free disk, ~8 GB free RAM

---

## Step 2 — Environment Variables

```bash
cp .env.example .env
```

Fill in these values at minimum:

| Variable | What to set |
|---|---|
| `JIRA_EMAIL` | Your Jira admin email |
| `JIRA_API_TOKEN` | Generated in Jira UI (Step 5) |
| `JIRA_PROJECT_KEY` | Your project key e.g. `SUP` |

Everything else has working defaults for local dev.

---

## Step 3 — Start Ollama Natively (Mac GPU)

> Ollama runs **outside Docker** to use Apple Silicon Metal GPU.
> Running it in Docker on macOS means CPU-only inference — 4–5× slower and prone to OOM kills with models larger than 3B.

```bash
# Install
brew install ollama

# Start the server (leave this running in a terminal tab)
ollama serve

# Pull models (in a new tab)
ollama pull llama3.2:latest          # ~2 GB — LLM for response generation
ollama pull nomic-embed-text:latest  # ~274 MB — embeddings for RAG

# Verify
ollama list
```

Test both are working:

```bash
# LLM
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:latest",
  "prompt": "say hello",
  "stream": false
}' | python3 -m json.tool

# Embeddings — should print: dims: 768
curl -s http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text:latest",
  "prompt": "test"
}' | python3 -c "import sys,json; d=json.load(sys.stdin); print('dims:', len(d['embedding']))"
```

See [docs/ollama_test_api.md](../ollama-test-api/) for more test commands.

---

## Step 4 — Start Docker Services

```bash
# Start Postgres first — Jira depends on it
docker compose up -d jira-db

# Wait for healthy
docker compose ps   # jira-db should show (healthy)

# Start everything else
docker compose up -d jira webdav filebrowser pinecone-local
```

Verify all are up:

```bash
docker compose ps
```

Expected:

```
jira-db           Up (healthy)
jira              Up
webdav            Up
filebrowser       Up
pinecone-local    Up (healthy)
```

> Jira takes **3–5 minutes** on first boot. Watch: `docker compose logs -f jira`
> Look for: `Server startup in XXXXX ms`

---

## Step 5 — Jira First-Time Setup

1. Open **http://localhost:8080**
2. Choose **"I'll set it up myself"**
3. Database → **"My own database"** → fill in:
   - Host: `jira-db` | Port: `5432` | DB: `jiradb` | User: `jira` | Password: `jirapassword`
4. License: get a free eval at **https://my.atlassian.com/license/evaluate**
   - Select Jira Software (Data Center) → Evaluation → copy license key
5. Create admin account — note the email, it goes in `.env` as `JIRA_EMAIL`
6. Create a project → note the **project key** (e.g. `SUP`) → set `JIRA_PROJECT_KEY` in `.env`
7. Generate API token:
   - Profile → Manage account → Security → API tokens → Create
   - Paste into `.env` as `JIRA_API_TOKEN`

Verify:

```bash
curl -u your@email.com:YOUR_TOKEN \
  http://localhost:8080/rest/api/2/project/SUP | python3 -m json.tool
```

---

## Step 6 — Upload PDFs via FileBrowser

FileBrowser is a browser-based file manager at **http://localhost:8082**.

Default login: `admin` / `admin` (prompted to change on first login).

**Option A — Generate synthetic test PDFs (no real docs needed):**

```bash
cd ~/mvp-opsis/app
pip install reportlab --break-system-packages
python -m synthetic.pdf_generator --batch
# Creates 5 PDFs covering: password, billing, login, errors, general
```

Then drag the files from `app/data/pdfs/` into FileBrowser.

**Option B — Use your own PDFs:**

Drag any documentation PDFs into FileBrowser at http://localhost:8082.

> FileBrowser (port 8082) and WebDAV (port 8081) share the same Docker volume.
> Files uploaded via FileBrowser are instantly visible to the pipeline.

---

## Step 7 — Index PDFs into Pinecone

Reads all PDFs from WebDAV → chunks text → embeds via Ollama → stores in Pinecone Local.

```bash
bash scripts/index-pdfs.sh
```

Verify the index was created:

```bash
curl http://localhost:5080/indexes | python3 -m json.tool
# Should show: ticket-knowledge with non-zero total_vector_count
```

---

## Step 8 — Start the Pipeline

```bash
docker compose up -d pipeline
docker compose logs -f pipeline
```

Expected output:

```
[INFO] Polling Jira for new tickets (project=SUP)...
[INFO] No new tickets. Sleeping...
```

---

## Step 9 — Test End-to-End

1. Create a Jira ticket at http://localhost:8080
2. Write a description related to your PDF content (e.g. "I can't reset my password")
3. Watch pipeline logs — within 60s it should pick up the ticket
4. Open the ticket — an AI comment should appear citing your PDFs

---

## Synthetic PDF Generator

The project includes a built-in PDF generator for creating test documents without needing real docs.

```bash
cd ~/mvp-opsis/app

# Generate a single PDF
python -m synthetic.pdf_generator \
  --topic "password reset" \
  --pages 5 \
  --relevant-ratio 0.7 \
  --output ./data/pdfs/password-guide.pdf

# Generate a full batch (5 PDFs covering common support topics)
python -m synthetic.pdf_generator --batch

# With Ollama-generated content (richer text, slower)
python -m synthetic.pdf_generator --topic "billing" --pages 4 --use-ollama
```

Parameters:

| Flag | Default | Description |
|---|---|---|
| `--topic` | `general support` | Subject matter for relevant content |
| `--pages` | `5` | Target page count |
| `--relevant-ratio` | `0.6` | 0.0–1.0, on-topic vs filler content |
| `--output` | `./data/pdfs/synthetic.pdf` | Output file path |
| `--batch` | off | Generate 5 pre-configured test PDFs |
| `--use-ollama` | off | Use LLM to generate richer section content |

---

##  Troubleshooting

| Symptom | Fix |
|---|---|
| Jira won't start | `docker compose logs jira` — usually needs more RAM in Docker Desktop |
| `401` from Jira | Regenerate API token; verify email matches admin account |
| Ollama OOM / killed | You're running Ollama in Docker — switch to native: `brew install ollama` |
| `dims: 0` from embeddings | `ollama pull nomic-embed-text:latest` |
| No RAG results | Re-run `scripts/index-pdfs.sh`; confirm PDFs are in FileBrowser |
| Pipeline can't reach Ollama | Verify `ollama serve` is running; `OLLAMA_BASE_URL=http://host.docker.internal:11434` |
| FileBrowser shows empty | WebDAV volume not mounted — `docker compose restart filebrowser` |

---

##  Teardown

```bash
# Stop containers, keep all data
docker compose down

# Full wipe — deletes Jira data, PDFs, vectors (irreversible)
docker compose down -v
```
