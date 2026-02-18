---
layout: page
title: Ollama API Test Commands
permalink: /projects/opsis/docs/ollama-test-api/
---

> Imported from `docs/ollama_test_api.md`

# Ollama API — Reference & Test Commands

Run these from your Mac terminal. Ollama runs natively on macOS (not in Docker)
so all commands target `http://localhost:11434` directly.

---

## 0. Server Management

### Start the server

```bash
ollama serve
```

Ollama must be running before the pipeline or any curl commands will work.
Run this in a dedicated terminal tab and leave it open. It will print logs as
models are loaded and unloaded.

### Verify the server is up

```bash
curl http://localhost:11434
# → "Ollama is running"
```

### Stop the server

`Ctrl+C` in the terminal running `ollama serve`, or:

```bash
pkill ollama
```

---

## 1. Model Management

### List all downloaded models

```bash
ollama list
```

Example output:
```
NAME                       ID              SIZE    MODIFIED
llama3.2:latest            a80c4f17acd5    2.0 GB  2 hours ago
nomic-embed-text:latest    0a109f422b47    274 MB  2 hours ago
```

This shows every model stored on disk. A model must be listed here before it
can be used.

### Pull a model

```bash
ollama pull llama3.2:latest
ollama pull nomic-embed-text:latest
```

Downloads the model weights. Progress is shown in the terminal. Models are
stored at `~/.ollama/models/` and persist between restarts.

### Remove a model

```bash
ollama rm llama3.2:latest
```

Frees disk space. The model will need to be pulled again to use it.

### Show model details (size, quantization, architecture)

```bash
ollama show llama3.2:latest
```

---

## 2. GPU & Performance

### Verify Metal GPU is being used (Apple Silicon)

```bash
# Start a generation and watch system resource usage
ollama run llama3.2:latest "hello"
```

In Activity Monitor → GPU History, you should see GPU usage spike. If only CPU
usage rises, Metal is not being used — make sure you installed Ollama natively
via `brew install ollama` and not through Docker.

### Check what's currently loaded in memory

```bash
curl http://localhost:11434/api/ps | python3 -m json.tool
```

Example response:
```json
{
  "models": [
    {
      "name": "llama3.2:latest",
      "size_vram": 2019393024,
      "expires_at": "2026-02-17T13:00:00Z"
    }
  ]
}
```

`size_vram` — bytes currently held in GPU memory (unified memory on Apple Silicon).
`expires_at` — when the model will be evicted (controlled by `keep_alive`).

---

## 3. Warm Pooling & keep_alive

By default Ollama keeps a model in memory for **5 minutes** after the last
request. You can override this per-request with the `keep_alive` parameter.

| Value | Behaviour |
|-------|-----------|
| `"5m"` | Default — evict after 5 minutes of inactivity |
| `"30m"` | Keep warm for 30 minutes |
| `"-1"` | Keep in memory indefinitely (until server restart) |
| `"0"` | Evict immediately after the request completes |

### Pin a model in memory permanently

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:latest",
  "prompt": "",
  "keep_alive": -1
}'
```

This is useful during active development — the model is already loaded when the
pipeline fires, so there's no cold-start delay.

### Pre-warm both models at startup

```bash
# Add this to your session startup or a shell alias
curl -s http://localhost:11434/api/generate \
  -d '{"model":"llama3.2:latest","prompt":"","keep_alive":-1}' > /dev/null && \
curl -s http://localhost:11434/api/embeddings \
  -d '{"model":"nomic-embed-text:latest","prompt":"warmup","keep_alive":-1}' > /dev/null && \
echo "Both models warm."
```

### Evict a model immediately (free memory)

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:latest",
  "prompt": "",
  "keep_alive": 0
}'
```

---

## 4. LLM — `llama3.2:latest`

### Request

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:latest",
  "prompt": "In one sentence, what is a support ticket?",
  "stream": false
}'
```

### Example Response

```json
{
  "model": "llama3.2:latest",
  "created_at": "2026-02-17T12:00:00Z",
  "response": "A support ticket is a formal record of a customer's request, issue, or question submitted to a support team for resolution.",
  "done": true,
  "done_reason": "stop",
  "context": [128006, 9125, 128007, 271, 128006, 882, 128007],
  "total_duration": 1843267000,
  "load_duration": 512483000,
  "prompt_eval_count": 18,
  "prompt_eval_duration": 214000000,
  "eval_count": 26,
  "eval_duration": 1116000000
}
```

### Key fields explained

| Field | What it means |
|---|---|
| `response` | The generated text |
| `done` | `true` = generation finished |
| `done_reason` | `stop` = hit end token naturally |
| `eval_count` | Tokens generated |
| `eval_duration` | Time spent generating (nanoseconds) |
| `total_duration` | Total wall time including model load |
| `load_duration` | Time to load model into memory (0 if already warm) |

### Tokens/sec formula

```bash
# eval_count / (eval_duration / 1e9)
# e.g. 26 / (1.116) = ~23 tokens/sec
```

---

## 5. Embeddings — `nomic-embed-text:latest`

### Request

```bash
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text:latest",
  "prompt": "Login page crashes on mobile devices after the latest update"
}'
```

### Example Response (truncated)

```json
{
  "model": "nomic-embed-text:latest",
  "embedding": [
    0.5421,
    -0.1832,
    0.7103,
    0.0291,
    -0.4456,
    0.3817,
    "... 762 more values ...",
    0.1243
  ]
}
```

### Check dimensions quickly

```bash
curl -s http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text:latest",
  "prompt": "test"
}' | python3 -c "import sys,json; d=json.load(sys.stdin); print('dims:', len(d['embedding']))"
```

Expected output:
```
dims: 768
```

---

## 6. List loaded models (in-memory)

```bash
curl http://localhost:11434/api/ps | python3 -m json.tool
```

### Example Response

```json
{
  "models": [
    {
      "name": "llama3.2:latest",
      "model": "llama3.2:latest",
      "size": 2019393024,
      "digest": "a80c4f17acd55265feec403c7aef86be0c25983ab279d83f3bcd3abbcb5b8b72",
      "details": {
        "parent_model": "",
        "format": "gguf",
        "family": "llama",
        "families": ["llama"],
        "parameter_size": "3.2B",
        "quantization_level": "Q4_K_M"
      },
      "expires_at": "2026-02-17T13:00:00Z",
      "size_vram": 2019393024
    }
  ]
}
```

`expires_at` = when the model will be unloaded from memory (controlled by `keep_alive`).

---

## 7. List all downloaded models

```bash
curl http://localhost:11434/api/tags | python3 -m json.tool
```

### Example Response

```json
{
  "models": [
    {
      "name": "llama3.2:latest",
      "model": "llama3.2:latest",
      "modified_at": "2026-02-17T10:00:00Z",
      "size": 2019393024,
      "digest": "a80c4f17acd5...",
      "details": {
        "format": "gguf",
        "family": "llama",
        "parameter_size": "3.2B",
        "quantization_level": "Q4_K_M"
      }
    },
    {
      "name": "nomic-embed-text:latest",
      "model": "nomic-embed-text:latest",
      "modified_at": "2026-02-17T10:05:00Z",
      "size": 274302848,
      "digest": "0a109f422b47...",
      "details": {
        "format": "gguf",
        "family": "nomic-bert",
        "parameter_size": "137M",
        "quantization_level": "F16"
      }
    }
  ]
}
```

---

## 8. Chat format (what CrewAI uses internally)

The pipeline uses the chat endpoint under the hood, not raw `generate`:

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2:latest",
  "stream": false,
  "messages": [
    {
      "role": "system",
      "content": "You are a helpful support agent. Only use the provided context."
    },
    {
      "role": "user",
      "content": "Context: [Source: user-guide.pdf, page 4] - To reset your password, click Forgot Password on the login page.\n\nTicket: I cannot log in to my account."
    }
  ]
}'
```

### Example Response

```json
{
  "model": "llama3.2:latest",
  "created_at": "2026-02-17T12:00:00Z",
  "message": {
    "role": "assistant",
    "content": "Hi, thanks for reaching out!\n\nTo reset your password, please click the **Forgot Password** link on the login page and follow the instructions sent to your email.\n\n[Source: user-guide.pdf, page 4]\n\nLet me know if you need further help!"
  },
  "done": true,
  "done_reason": "stop",
  "eval_count": 54,
  "eval_duration": 2243000000
}
```

---

## Quick health check — one-liner

Run this any time to confirm both models are ready:

```bash
echo "=== LLM ===" && \
curl -s http://localhost:11434/api/generate \
  -d '{"model":"llama3.2:latest","prompt":"ping","stream":false}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK -', d['response'][:50])" && \
echo "=== Embeddings ===" && \
curl -s http://localhost:11434/api/embeddings \
  -d '{"model":"nomic-embed-text:latest","prompt":"ping"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK - dims:', len(d['embedding']))"
```

Expected:
```
=== LLM ===
OK - Ping!
=== Embeddings ===
OK - dims: 768
```
