---
layout: page
title: Ollama Model Research
permalink: /projects/opsis/docs/ollama-models-research/
---

> Imported from `docs/ollama-models-research.md`

# Ollama LLM Models — Research & Alternatives

> Context: `llama3.1:8b` is OOM-killing on this setup (multiple heavy Docker containers + Jira running alongside).
> Goal: Find a smaller model that still produces coherent, cited support responses.

---

## Why `llama3.1:8b` Is Dying

The signal `killed` in a Docker container almost always means the OS OOM killer stepped in.

With everything running together:

| Service | Approx RAM |
|---|---|
| Jira + Postgres | ~2.5–3.5 GB |
| WebDAV | ~50 MB |
| PineconeDB | ~200 MB |
| `llama3.1:8b` at Q4 | ~5–6 GB |
| Pipeline app | ~300 MB |
| **Total** | **~9–10 GB** |

On a 16 GB Mac, Docker Desktop's default memory limit is often set to 8 GB — meaning Ollama gets killed before it finishes loading the model. Even at 16 GB total, macOS itself takes 2–3 GB, leaving very little headroom.

---

## Diagnosing OOM — Commands

### Check if it was actually an OOM kill

```bash
# See the last exit code and reason for the ollama container
{% raw %}docker inspect ollama-local --format '{{.State.ExitCode}} {{.State.Error}}'{% endraw %}

# Full container event log
docker events --filter container=ollama-local --since 1h
```

Exit code `137` = killed by SIGKILL = almost always OOM.

### Check current memory usage across all containers

```bash
docker stats --no-stream
```

Shows live memory usage per container. The `MEM USAGE / LIMIT` column tells you how close each service is to its cap.

### Check Docker Desktop's total memory limit

```bash
docker info | grep "Total Memory"
```

If this shows less than 12 GB on a 16 GB machine, increase it:
Docker Desktop → Settings → Resources → Memory → raise to 12–14 GB.

### Watch memory live while pulling/running a model

```bash
# In one terminal — live stats
docker stats ollama-local

# In another — try loading the model
docker exec ollama-local ollama run phi3:mini "say hello"
```

### Check macOS system memory pressure

```bash
# Memory pressure indicator (normal / warn / critical)
memory_pressure

# Or via vm_stat
vm_stat | grep "Pages free\|Pages active\|Pages wired"
```

### Check if a model is actually loaded in Ollama

```bash
# Lists currently loaded models and their memory footprint
curl http://localhost:11434/api/ps | python3 -m json.tool
```

### Force unload a model from memory

```bash
# Keep alive of 0 = unload immediately after response
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1:8b",
  "keep_alive": 0
}'
```

---

## Model Alternatives — Ranked for This Project

## How RAG Works With These Models

Before picking a model, it helps to understand what the LLM actually does in a RAG pipeline — because it changes what "good" means.

### What RAG offloads away from the LLM

In a standard RAG setup, the LLM does **not** need to know the answer from its training data. Instead:

1. The question (ticket) is embedded → vector search finds relevant PDF chunks
2. Those chunks are **injected directly into the prompt** as context
3. The LLM's only job is to **read that context and write a coherent response**

This is sometimes called "grounded generation" — the model is anchored to what you give it, not what it memorised during training. This matters a lot for model choice.

### What this means in practice

A smaller model (3–4B) can perform surprisingly close to a larger one (8B) in RAG, because:

- The hard part (finding the right information) is already done by the vector search
- The LLM just needs to be good at **reading, summarising, and formatting** — not recalling facts
- Short-output tasks (a 200–350 word support reply) suit small models well

Where small models still fall short vs large:
- Complex multi-step reasoning ("this ticket involves 3 interacting bugs")
- Long retrieved context (many chunks → model loses track)
- Structured JSON output (less reliable at smaller sizes)

### What `phi3.5` specifically does well for RAG

- Trained by Microsoft specifically for **instruction following + long context reading**
- Handles a 128k token context window — you can pass many PDF chunks without truncation
- Reliably follows formatting instructions ("cite sources as [Source: file.pdf, page N]")
- Better at "stay grounded, don't make things up" than generic small models
- Fast enough on CPU to respond in 15–30 seconds for a typical support reply

---

## Model Alternatives — Ranked for This Project

###  Recommended: `phi3.5` (3.8B)

```bash
docker exec ollama-local ollama pull phi3.5
```

| Property | Value |
|---|---|
| Size on disk | ~2.2 GB |
| RAM needed | ~3.5–4 GB |
| Context window | 128k tokens |
| Best for | RAG, structured output, instruction following |

Microsoft trained Phi-3.5 Mini specifically for RAG and document-heavy workflows — it processes long retrieved context better than similarly-sized models. Instruction following is strong enough to reliably produce cited, structured support responses. **Best balance for this MVP.**

**Update `.env`:**
```bash
OLLAMA_LLM_MODEL=phi3.5
```

---

###  Alternative: `llama3.2:3b`

```bash
docker exec ollama-local ollama pull llama3.2:3b
```

| Property | Value |
|---|---|
| Size on disk | ~2.0 GB |
| RAM needed | ~2–3 GB |
| Context window | 128k tokens |
| Best for | General instruction following, chat |

Meta's Llama 3.2 3B is the most widely tested small model. Very fast, handles structured output (JSON, markdown) well. Slightly less RAG-optimised than Phi-3.5 but more broadly capable.

**Update `.env`:**
```bash
OLLAMA_LLM_MODEL=llama3.2:3b
```

---

###  Lightweight fallback: `gemma2:2b`

```bash
docker exec ollama-local ollama pull gemma2:2b
```

| Property | Value |
|---|---|
| Size on disk | ~1.6 GB |
| RAM needed | ~3–4 GB |
| Context window | 8k tokens |
| Best for | Chat, summaries, simple drafting |

Google's Gemma 2 2B with Flash Attention enabled by default. Lower context window (8k vs 128k) is the main limitation for RAG — keep PDF chunks small (~300 words) if using this model.

**Update `.env`:**
```bash
OLLAMA_LLM_MODEL=gemma2:2b
```

---

###  If you want to keep `llama3.1:8b` — use a quantized tag

The default pull gets `Q4_K_M`. You can try an even smaller quantisation:

```bash
docker exec ollama-local ollama pull llama3.1:8b-instruct-q3_K_S
```

`Q3_K_S` uses ~4.1 GB vs ~5 GB for Q4. Some quality loss on reasoning but usable for response drafting. This is a last resort — better to just use `phi3.5`.

---

## Impact on Response Quality

Switching from 8B → 3–4B will produce:

| Aspect | `llama3.1:8b` | `phi3.5` / `llama3.2:3b` |
|---|---|---|
| Response coherence | Excellent | Good (phi3.5 close to 8b) |
| Citation formatting | Reliable | Usually reliable |
| Instruction following | Strong | Strong (phi3.5 trained for it) |
| Hallucination rate | Low | Slightly higher |
| Context handling | 128k | 128k |
| Tokens/sec (Apple Silicon) | ~12–18 | ~35–55 |
| RAM usage | ~5–6 GB | ~2–3.5 GB |

For a first-response suggestion on a support ticket (200–350 words), the difference in quality is minor. The retrieved RAG context does most of the heavy lifting — the LLM is mostly formatting and synthesising it.

---

## Quick Fix Steps

```bash
# 1. Pull the replacement model
docker exec ollama-local ollama pull phi3.5

# 2. Update .env
# OLLAMA_LLM_MODEL=phi3.5

# 3. Restart the pipeline
docker compose restart pipeline

# 4. Verify the model loads cleanly
curl http://localhost:11434/api/generate -d '{
  "model": "phi3.5",
  "prompt": "Reply in one sentence: what is a support ticket?",
  "stream": false
}' | python3 -m json.tool
```

---

## Increase Docker Memory Limit (if not done already)

Docker Desktop → **Settings** → **Resources** → **Memory**

Recommended for this stack:

| Your Mac RAM | Docker Limit |
|---|---|
| 16 GB | 12 GB |
| 32 GB | 20 GB |
| 64 GB | 40 GB |

After changing, click **Apply & Restart** and re-run `docker compose up -d`.

---

---

## GPU Acceleration on Apple Silicon

###  Critical: Docker blocks Metal GPU access

This is the most important thing to know about Ollama + Mac:

> **Docker Desktop on macOS does NOT expose the Apple GPU to containers.**
> Ollama inside Docker runs CPU-only — no Metal, no GPU acceleration.

This means our current setup is running Ollama in pure CPU mode, which is why it's slow and OOM-prone.

### Why this matters for RAG specifically

In a RAG pipeline, Ollama gets called **twice per ticket**:
1. Once during indexing to embed each PDF chunk (embedding model)
2. Once per ticket response to generate the reply (LLM)

On CPU-only Docker:
- Embedding a 100-page PDF might take 2–5 minutes
- Generating a single reply might take 30–60 seconds at 5–8 tokens/sec

On native Metal GPU:
- Same PDF indexes in 20–40 seconds
- Reply generates in 5–10 seconds at 45–60 tokens/sec

For an MVP you're testing manually, CPU-only is workable. But it's worth knowing the full picture. You have two options:

---

### Option A — Run Ollama natively (recommended for speed)

Install Ollama directly on macOS instead of Docker:

```bash
# Install
brew install ollama

# Start as a background service
brew services start ollama

# Or run manually
ollama serve
```

Ollama native on Apple Silicon uses **Metal automatically** — no config needed. You'll get:
- **3–5× faster** token generation vs Docker CPU
- ~28–45 tokens/sec on M2/M3 Pro for 7–8B models
- Models stay warm in unified memory (shared CPU+GPU)

**Update `.env` to point at the native Ollama instead of Docker:**
```bash
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

`host.docker.internal` is the magic hostname Docker uses to reach the Mac host from inside a container.

Then remove `ollama` from `docker compose up` — the pipeline container still talks to it over HTTP, just to a different host.

---

### Option B — Keep Ollama in Docker (slower, simpler)

If you prefer keeping everything in Docker, accept the CPU-only constraint and mitigate with smaller models + keep_alive.

Add to `docker-compose.yml` under the `ollama` service:

```yaml
ollama:
  environment:
    - OLLAMA_KEEP_ALIVE=3600       # keep model in memory for 1 hour
    - OLLAMA_NUM_PARALLEL=1        # one request at a time (saves RAM)
    - OLLAMA_MAX_LOADED_MODELS=1   # only one model loaded at a time
```

---

## Warm Pooling — Keep Models Hot

Every time Ollama loads a model cold it takes 3–10 seconds. Warm pooling keeps it resident in memory so the pipeline responds instantly.

### Set keep_alive globally (Docker)

In `docker-compose.yml`:
```yaml
environment:
  - OLLAMA_KEEP_ALIVE=3600    # seconds — 3600 = 1 hour
```

### Set keep_alive per request

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "phi3.5",
  "prompt": "hello",
  "keep_alive": 3600
}'
```

### Check what's currently loaded in memory

```bash
curl http://localhost:11434/api/ps | python3 -m json.tool
```

### Force unload a model (free RAM)

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "phi3.5",
  "keep_alive": 0
}'
```

---

## Quantization Quick Reference

Different quant levels trade quality vs RAM:

| Tag | RAM use | Quality loss | Use when |
|---|---|---|---|
| `q8_0` | ~8.5 GB | Minimal | Plenty of RAM |
| `q5_K_M` | ~5.7 GB | Very small | 16 GB Mac |
| `q4_K_M` | ~4.8 GB | Small (default) | 8–16 GB Mac |
| `q3_K_S` | ~4.0 GB | Moderate | RAM constrained |
| `q2_K` | ~3.4 GB | Significant | Last resort |

Pull a specific quant:
```bash
ollama pull llama3.1:8b-instruct-q3_K_S
```

---

## Benchmark: Native vs Docker on Apple Silicon

From real-world testing on M2 Pro 16GB (2025):

| Setup | Model | Tokens/sec |
|---|---|---|
| Native + Metal | llama3.1:8b | 28–35 |
| Native + Metal | phi3.5 | 45–60 |
| Docker CPU only | llama3.1:8b | 5–8 |
| Docker CPU only | phi3.5 | 12–20 |

Native + Metal is **4–5× faster** for the same model.

---

## Sources

- [Best AI Models for 8GB RAM — LocalAIMaster](https://localaimaster.com/blog/best-local-ai-models-8gb-ram)
- [Ollama VRAM Requirements 2026 — LocalLLM.in](https://localllm.in/blog/ollama-vram-requirements-for-local-llms)
- [Best Ollama Models 2025 — Collabnix](https://collabnix.com/best-ollama-models-in-2025-complete-performance-comparison/)
- [Top 7 Small Language Models for Laptop — MachineLearningMastery](https://machinelearningmastery.com/top-7-small-language-models-you-can-run-on-a-laptop/)
- [Ollama Models 2026: 4GB RAM Guide — LocalAIMaster](https://localaimaster.com/blog/free-local-ai-models)
- [Complete Ollama Models Guide 2025 — PracticalWebTools](https://practicalwebtools.com/blog/ollama-models-complete-guide-2025)
- [Ollama Models List 2025 — Skywork AI](https://skywork.ai/blog/llm/ollama-models-list-2025-100-models-compared/)
