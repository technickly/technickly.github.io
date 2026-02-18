---
layout: page
title: PDF Indexing Explainer
permalink: /projects/opsis/docs/pdf-indexing-explainer/
---

> Imported from `docs/pdf-indexing-explainer.md`

# PDF Indexing & Chunking — Deep Explainer

This document explains exactly what happens when you run `bash scripts/index-pdfs.sh`, why each decision was made, and what the embedding is actually capturing.

---

## The Big Picture

The indexer's job is to convert human-readable PDF documents into a format a computer can search by *meaning* rather than by keyword.

The end result is a Pinecone index full of vectors — each one representing a small piece of a document. When a Jira ticket arrives, we embed the ticket text the same way and find the closest matching vectors. Those are the most relevant passages from the docs.

```
PDF file
  │
  ▼
Extract raw text (pdfplumber, page by page)
  │
  ▼
Clean the text (strip junk, collapse whitespace)
  │
  ▼
Split into overlapping chunks (500 words, 50-word overlap)
  │
  ▼
Embed each chunk (Ollama → nomic-embed-text → float[768])
  │
  ▼
Store in Pinecone (id + vector + metadata)
```

---

## Step 1 — Text Extraction (pdfplumber)

```python
with pdfplumber.open(str(local_path)) as pdf:
    for page_num, page in enumerate(pdf.pages, start=1):
        raw_text = page.extract_text() or ""
```

**What it does:** Opens the PDF and reads the text layer from each page. PDFs store text as positioned characters — pdfplumber reassembles them into readable strings.

**Why page by page:** We preserve the page number for every chunk. This matters for citations — the pipeline can tell users "see page 4 of password-guide.pdf" rather than just the filename.

**Why pdfplumber over alternatives:**
- `pypdf` extracts text but loses layout — words run together across columns
- `pdfminer` is lower-level and harder to use
- `pdfplumber` is built on pdfminer but adds intelligent layout reconstruction — it understands columns, tables, and spacing

**Limitation:** This only works on text-based PDFs. Scanned PDFs (images of paper) return empty text and would need OCR (e.g. Tesseract) as a pre-processing step.

---

## Step 2 — Text Cleaning

```python
def _clean_text(text: str) -> str:
    text = re.sub(r'\s+', ' ', text)           # collapse whitespace
    text = re.sub(r'[^\x20-\x7E\n]', '', text) # strip non-ASCII
    return text.strip()
```

**What it does:** Two regex passes on the raw extracted text.

**Pass 1 — collapse whitespace** (`\s+` → single space):
PDF extraction often produces messy whitespace — double spaces, tabs, newlines mid-sentence from column breaks. This collapses all of that into clean single spaces so sentences read naturally.

Before: `"To  reset   your\npassword   click"`
After: `"To reset your password click"`

**Pass 2 — strip non-ASCII** (keep only characters 0x20–0x7E):
PDFs embed fonts that sometimes produce garbage characters — curly quotes that extract as `\u2019`, em-dashes as `\u2014`, ligatures like `ﬁ` instead of `fi`. These confuse the tokeniser inside the embedding model. Stripping them to plain ASCII keeps the embedding clean.

**Trade-off:** We lose characters like `é`, `ü`, `ñ`. For English-only documentation this is fine. For multilingual docs, remove the second regex or use a Unicode-aware cleaning approach.

---

## Step 3 — Chunking (the most important decision)

```python
CHUNK_SIZE    = 500   # words
CHUNK_OVERLAP = 50    # words

def _chunk_text(text: str, size=500, overlap=50) -> list[str]:
    words = text.split()
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + size, len(words))
        chunk = " ".join(words[start:end])
        chunks.append(chunk)
        start += size - overlap   # ← overlap means we step 450, not 500
    return chunks
```

### What chunking is

An embedding model has a context window — a maximum number of tokens it can read at once. `nomic-embed-text` handles up to 8,192 tokens, but a dense 500-word chunk embeds much better than a 5,000-word chapter, because:

- A large chunk covers too many topics → the embedding averages across all of them → becomes "about everything" → matches nothing precisely
- A small chunk is focused → the embedding captures one specific concept → matches precisely

### Why 500 words

500 words is roughly one full section of a support document — e.g. "Password Reset Procedure" with its 4–6 step instructions. It is:

- Long enough to contain a complete thought with context
- Short enough to be about one specific thing
- Within the sweet spot for `nomic-embed-text` retrieval quality

For reference: 500 words ≈ 650–700 tokens ≈ about one A4 page of normal text.

### Why overlap (50 words)

This is the subtle but critical part.

Without overlap, chunking can split a sentence across two chunks:

```
Chunk 1: "...After 5 failed login attempts your account will be"
Chunk 2: "locked for 30 minutes. To unlock it contact your admin..."
```

The key information ("locked for 30 minutes") is split. If a ticket asks "why is my account locked", neither chunk alone gives the full answer.

With 50-word overlap, the window slides 450 words forward each time (not 500). The last 50 words of chunk N become the first 50 words of chunk N+1:

```
Chunk 1: "...After 5 failed login attempts your account will be locked for 30 minutes."
Chunk 2: "locked for 30 minutes. To unlock it contact your admin via the user management panel."
```

Now both chunks contain the complete thought. The search is more likely to find a relevant match regardless of where the query lands.

### Visualised

```
Document text (words):
[1 ........ 500][451 ....... 950][901 ....... 1400] ...
     chunk 1          chunk 2          chunk 3

Overlap zone:
              [451..500] appears in both chunk 1 and chunk 2
                         [901..950] appears in both chunk 2 and chunk 3
```

---

## Step 4 — Vector ID Generation

```python
def _make_vector_id(source_file: str, page: int, chunk_index: int) -> str:
    raw = f"{source_file}__page{page}__chunk{chunk_index}"
    return hashlib.md5(raw.encode()).hexdigest()
```

Each chunk gets a unique deterministic ID. "Deterministic" means running the indexer twice on the same file produces the same IDs — so re-indexing overwrites existing vectors (Pinecone upsert) rather than duplicating them.

The ID encodes: which file + which page + which chunk within that page.

---

## Step 5 — Embedding (the core of RAG)

```python
embedding = get_embedding(chunk)
# → calls Ollama: POST /api/embeddings {model: nomic-embed-text, prompt: chunk}
# → returns float[768]
```

### What an embedding is

An embedding is a list of 768 floating point numbers. Each number is a coordinate in a 768-dimensional space. The embedding model has learned to place text with similar *meaning* close together in that space, regardless of the exact words used.

Example — these three phrases end up near each other:
- "I forgot my password and cannot log in"
- "unable to reset credentials on login page"
- "account access issue — password not working"

They use different words but the embedding model places them within a small distance of each other because it has learned they describe the same situation.

### What nomic-embed-text specifically captures

`nomic-embed-text` is trained on a large corpus of web text and fine-tuned for retrieval tasks. For documentation PDFs it captures:

- **Semantic topic** — "password reset" vs "billing" vs "error codes" are clearly separated
- **Procedural intent** — "how to do X" clusters near other procedural instructions
- **Entity relationships** — "admin panel", "user settings", "profile page" are understood as related concepts in a UI context
- **Problem/solution pairs** — questions cluster near answers even when phrased differently

### What it does NOT capture well

- **Exact numbers and codes** — "Error 429" and "Error 403" look similar to the model (both are error codes) but mean very different things. Keyword search handles these better.
- **Negation** — "account is NOT locked" may embed similarly to "account is locked"
- **Very rare terms** — proprietary product names or internal jargon the model has never seen

### The 768 dimensions

Why 768? That's the output size `nomic-embed-text` was trained with. It is the "resolution" of the meaning representation. More dimensions = more nuance captured = larger storage. 768 is a sweet spot — OpenAI's `text-embedding-ada-002` uses 1,536, but the quality difference for support doc retrieval is marginal.

---

## Step 6 — Storing in Pinecone

```python
vectors.append({
    "id": vector_id,           # deterministic hash
    "values": embedding,       # float[768]
    "metadata": {
        "source_file": filename,  # "password-guide.pdf"
        "page": page_num,         # 3
        "chunk_index": chunk_idx, # 1
        "text": chunk[:1000],     # the actual text (for display)
    },
})
```

Each vector stored in Pinecone has three parts:

**`id`** — unique identifier so upserts overwrite rather than duplicate.

**`values`** — the 768-dimensional embedding. This is what Pinecone searches against. At query time, it computes the cosine similarity between the query embedding and every stored vector and returns the closest matches.

**`metadata`** — the human-readable information attached to this vector. When a match is found, the pipeline reads `text` to get the actual passage, and `source_file` + `page` to cite the source in the Jira comment.

### Why cosine similarity

Cosine similarity measures the angle between two vectors, not their distance. This means it compares direction (meaning) rather than magnitude (intensity of language). A short chunk and a long chunk about the same topic will have a small angle between them even if their magnitudes differ.

Formula: `similarity = (A · B) / (|A| × |B|)` — ranges from -1 (opposite) to 1 (identical).

### Batching (100 vectors per upsert)

```python
for i in range(0, len(vectors), 100):
    batch = vectors[i: i + 100]
    self.index.upsert(vectors=batch, namespace=settings.pinecone_namespace)
```

Pinecone has a request size limit. Sending 100 vectors per HTTP call is the standard batch size — large enough to be efficient, small enough to never hit the limit.

---

## Why This Approach Suits Support Documentation

Support docs have predictable characteristics that make this chunking strategy work well:

**Consistent section size** — a "How to reset your password" section is naturally ~300–600 words. Our 500-word chunks align well with these natural boundaries.

**Self-contained procedures** — support doc sections are written to be read independently. A chunked passage typically contains a complete procedure, not half of one.

**Repetitive vocabulary** — docs use consistent terminology ("click", "navigate to", "contact your administrator"). The embedding model handles this well because the same concepts appear in similar contexts repeatedly.

**Question-answer alignment** — support tickets are essentially questions ("I can't log in"), and support docs are essentially answers ("To fix login issues, do X"). Embedding models trained for retrieval learn to align questions with their answers even when phrased differently.

---

## What Happens at Query Time (for comparison)

When the pipeline processes a Jira ticket:

```python
# 1. Embed the ticket text
query_vector = get_embedding("I can't reset my password, the link expired")
# → float[768]

# 2. Search Pinecone for nearest neighbours
results = index.query(vector=query_vector, top_k=6)

# 3. Returns the 6 chunks whose embeddings are most similar
# e.g.:
# - "password-guide.pdf" page 2: "The reset link expires after 15 minutes..."
# - "password-guide.pdf" page 3: "To request a new reset link, click Forgot Password..."
# - "login-guide.pdf"    page 1: "If you cannot log in, verify your email..."
```

The ticket never needs to use the same words as the documentation. "The link expired" and "reset link expires after 15 minutes" are different strings but land close together in the 768-dimensional embedding space — so the search finds them.

---

## Summary

| Decision | Value | Why |
|---|---|---|
| Text extractor | pdfplumber | Best layout reconstruction for multi-column docs |
| Chunk size | 500 words | Matches natural section length in support docs |
| Overlap | 50 words | Prevents meaning loss at chunk boundaries |
| Embedding model | nomic-embed-text | Fast, 768-dim, strong on retrieval tasks, 8k context |
| Similarity metric | cosine | Direction-based, not magnitude-based |
| Vector dimensions | 768 | nomic-embed-text output size |
| Batch size | 100 | Pinecone recommended limit per upsert call |
| ID generation | MD5 hash of filename+page+chunk | Deterministic — safe to re-index without duplicating |
