---
layout: page
title: Ollama Embedding Research
permalink: /projects/opsis/docs/ollama-embedding-research/
---

# Ollama Embedding Models — Research & Comparison

> Research compiled February 2026. Benchmarks sourced from MTEB leaderboard (May–June 2025).

---

## What is an embedding model?

An embedding model converts text into a fixed-length array of numbers (a vector). Similar meaning → similar vectors. This is what makes RAG work: you embed a query and find the closest document chunks by vector distance.

The key properties that differ between models:

- **Dimensions** — length of the output vector (more ≠ always better)
- **Context length** — max tokens the model can read at once
- **MTEB score** — standardised retrieval benchmark (higher = better)
- **Size on disk** — affects RAM usage and pull time
- **Speed** — tokens embedded per second

---

## Models Compared

### 1. `nomic-embed-text`  (our current choice)

```bash
ollama pull nomic-embed-text
```

| Property | Value |
|---|---|
| Dimensions | 768 |
| Context length | 8,192 tokens |
| Disk size | ~274 MB |
| MTEB score | 53.01 |
| Speed (M2 Max) | ~9,340 tokens/sec |

**Strengths:**
- Tiny footprint — fits on almost any hardware
- Extremely fast — good for real-time or high-volume indexing
- Long context window (8k tokens) — handles full pages without chunking as aggressively
- Outperforms OpenAI `text-embedding-ada-002` on long-context tasks

**Weaknesses:**
- Lower MTEB score vs mxbai or qwen3
- 768 dims means less expressive than larger models

**Best for:** This project's MVP. Low RAM, fast, good enough retrieval quality for most support doc use cases.

---

### 2. `mxbai-embed-large`

```bash
ollama pull mxbai-embed-large
```

| Property | Value |
|---|---|
| Dimensions | 1,024 |
| Context length | 512 tokens |
| Disk size | ~1.2 GB |
| MTEB score | **64.68** (best local model) |
| Speed (M2 Max) | ~6,780 tokens/sec |

**Strengths:**
- Highest MTEB retrieval score of any local Ollama model
- Beats OpenAI `text-embedding-3-large` on retrieval benchmarks
- Great for English technical documentation retrieval

**Weaknesses:**
- Short context window (512 tokens) — you need smaller chunks when indexing
- ~4× larger than nomic-embed-text
- No multilingual support

**Best for:** Upgrading this project when retrieval quality matters more than speed. Change `OLLAMA_EMBED_MODEL=mxbai-embed-large` and set `EMBEDDING_DIM=1024`, then re-index.

---

### 3. `all-minilm`

```bash
ollama pull all-minilm
```

| Property | Value |
|---|---|
| Dimensions | 384 |
| Context length | 256 tokens |
| Disk size | ~45 MB |
| MTEB score | ~38–42 (estimated) |
| Speed | Very fast |

**Strengths:**
- Extremely small — runs on anything, including Raspberry Pi
- Fastest of all options
- 200M+ downloads on HuggingFace (widely tested)

**Weaknesses:**
- 2019 architecture — significantly outclassed by modern models
- Only 56% Top-5 accuracy in head-to-head RAG benchmarks
- Very short context (256 tokens) — requires aggressive chunking
- 384 dimensions — lower expressiveness

**Best for:** Testing and development only. Not recommended for production RAG. If you just want to verify the pipeline works before pulling larger models, this is a quick option.

---

### 4. `qwen3-embedding`  (2025 state-of-the-art)

```bash
ollama pull qwen3-embedding:0.6b   # lightweight
ollama pull qwen3-embedding:4b     # balanced
ollama pull qwen3-embedding:8b     # best quality
```

| Size | Dimensions | Context | Disk | MTEB Multilingual |
|---|---|---|---|---|
| 0.6B | up to 1,024 | 32,768 tokens | ~600 MB | strong |
| 4B | up to 2,048 | 32,768 tokens | ~4 GB | very strong |
| 8B | up to 4,096 | 32,768 tokens | ~8 GB | **70.58 — #1** |

**Strengths:**
- **#1 on MTEB multilingual leaderboard** (8B, score 70.58 as of June 2025)
- Massive context window — 32k tokens, can embed entire documents in one shot
- Supports 100+ languages natively
- MRL (Matryoshka) support — you can request smaller output dims to save storage
- Instruction-aware — pass a task description to boost retrieval by 1–5%

**Weaknesses:**
- Heavy — 8B model needs ~8–10 GB RAM just for embeddings
- Slower indexing speed than nomic or mxbai
- Overkill for English-only single-language use cases

**Best for:** Multilingual support tickets, large document corpora, or when you want the absolute best retrieval quality and have the hardware.

**Using instructions (unique to qwen3):**
```python
# Prefix your query with a task instruction for better results
query = "Instruct: Given a support ticket, find relevant documentation\nQuery: " + ticket_text
```

---

### 5. `snowflake-arctic-embed`

```bash
ollama pull snowflake-arctic-embed
```

| Property | Value |
|---|---|
| Dimensions | 1,024 |
| Context length | 512 tokens |
| Disk size | ~1.2 GB |
| MTEB score | ~63–64 |

Competitive with mxbai-embed-large. Good alternative if mxbai doesn't work well on your data. Less commonly benchmarked independently.

---

## Head-to-Head Summary

| Model | MTEB Score | Dims | Context | Size | Best Use |
|---|---|---|---|---|---|
| `qwen3-embedding:8b` | **70.58** (multilingual) | 4,096 | 32k | 8 GB | Best quality, multilingual |
| `mxbai-embed-large` | **64.68** | 1,024 | 512 | 1.2 GB | Best English retrieval |
| `snowflake-arctic-embed` | ~63–64 | 1,024 | 512 | 1.2 GB | Alternative to mxbai |
| `nomic-embed-text` | 53.01 | 768 | 8,192 | 274 MB |  This project (MVP) |
| `qwen3-embedding:0.6b` | competitive | 1,024 | 32k | 600 MB | Lightweight + multilingual |
| `all-minilm` | ~38–42 | 384 | 256 | 45 MB | Dev/testing only |

---

## How to Swap Models in This Project

1. Edit `.env`:
```bash
OLLAMA_EMBED_MODEL=mxbai-embed-large
EMBEDDING_DIM=1024   # must match the model's output dimensions
```

2. Pull the new model:
```bash
docker exec ollama-local ollama pull mxbai-embed-large
```

3. Wipe and rebuild the Pinecone index (dimension mismatch = error):
```bash
# Reset Pinecone volume
docker compose stop pinecone-local
docker compose rm -f pinecone-local
docker volume rm mvp-opsis_pinecone-data
docker compose up -d pinecone-local

# Re-index
bash scripts/index-pdfs.sh
```

>  You cannot mix dimensions in one index. If you change `EMBEDDING_DIM`, always wipe and re-index.

---

## Recommendation for This Project

| Stage | Model | Reason |
|---|---|---|
| **MVP (now)** | `nomic-embed-text` | Fast, tiny, works on any Mac |
| **Upgrade path** | `mxbai-embed-large` | Best English RAG quality |
| **If multilingual tickets** | `qwen3-embedding:0.6b` | 32k context, 100+ languages, manageable size |

---

## Sources

- [Best Ollama Embedding Models for RAG — Arsturn](https://www.arsturn.com/blog/picking-the-perfect-partner-a-guide-to-choosing-the-best-embedding-models-in-ollama)
- [Ollama Embedding Models — Collabnix 2025 Guide](https://collabnix.com/ollama-embedded-models-the-complete-technical-guide-to-local-ai-embeddings-in-2025/)
- [Ollama Embedding Models Library](https://ollama.com/search?c=embedding)
- [qwen3-embedding on Ollama](https://ollama.com/library/qwen3-embedding)
- [Benchmark of 16 Best Open Source Embedding Models — AIM Research](https://research.aimultiple.com/open-source-embedding-models/)
- [Comparing Local Embedding Models for RAG — Medium](https://medium.com/@jinmochong/comparing-local-embedding-models-for-rag-systems-all-minilm-nomic-and-openai-ee425b507263)
- [13 Best Embedding Models 2026 — Elephas](https://elephas.app/blog/best-embedding-models)
- [Ollama Embeddings Docs](https://docs.ollama.com/capabilities/embeddings)
