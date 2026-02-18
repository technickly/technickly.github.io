---
layout: page
title: Ollama Setup Notes
permalink: /projects/opsis/docs/docker-ollama/
---

> Imported from `docker/ollama/README.md`

#  Ollama Setup — Native Mac (Not Docker)

## Why Native, Not Docker

Docker Desktop on macOS cannot expose the Apple Silicon GPU to containers. Running Ollama in Docker means CPU-only inference:

| Mode | Model | Tokens/sec |
|---|---|---|
| Native Mac (Metal) | llama3.2:latest | ~40–60 |
| Docker (CPU only) | llama3.2:latest | ~8–12 |
| Docker (CPU only) | llama3.1:8b | ~5–8 + OOM kills |

Running natively gives 4–5× faster inference and eliminates OOM issues entirely.

---

## Install & Start

```bash
brew install ollama
ollama serve
```

Leave `ollama serve` running in a dedicated terminal tab. Models are stored in `~/.ollama/` and persist across restarts.

---

## Models Used in This Project

```bash
# LLM — generates support responses (~2 GB)
ollama pull llama3.2:latest

# Embeddings — powers RAG vector search (~274 MB)
ollama pull nomic-embed-text:latest

# Verify both are present
ollama list
```

---

## How Docker Containers Reach Native Ollama

The pipeline container talks to native Ollama via `host.docker.internal` — Docker's built-in hostname that resolves to the Mac host from inside any container.

In `.env`:
```bash
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

---

## Test Commands

```bash
# LLM
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:latest",
  "prompt": "say hello in one sentence",
  "stream": false
}' | python3 -m json.tool

# Embeddings — expected: dims: 768
curl -s http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text:latest",
  "prompt": "test"
}' | python3 -c "import sys,json; d=json.load(sys.stdin); print('dims:', len(d['embedding']))"

# Check what is currently loaded in memory
curl http://localhost:11434/api/ps | python3 -m json.tool
```

See [docs/ollama_test_api.md](../ollama-test-api/) for the full API reference.

---

## Swapping Models

To use a different LLM, pull it and update `.env`:

```bash
ollama pull phi3.5
# .env: OLLAMA_LLM_MODEL=phi3.5
```

If changing the **embedding model**, also update `EMBEDDING_DIM` in `.env` and wipe + re-index Pinecone (index dimension must match).

See [docs/ollama-models-research.md](../ollama-models-research/) for model comparisons.
See [docs/ollama-embedding-research.md](../ollama-embedding-research/) for embedding model comparisons.

---

## Re-adding as Docker Container (Linux / NVIDIA)

Uncomment this in `docker-compose.yml` and revert `OLLAMA_BASE_URL` to `http://ollama-local:11434`:

```yaml
ollama:
  image: ollama/ollama:latest
  container_name: ollama-local
  ports:
    - "11434:11434"
  volumes:
    - ollama-data:/root/.ollama
  networks:
    - mvp-net
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```
