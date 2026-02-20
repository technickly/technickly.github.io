---
layout: page
title: Generate Synthetic PDFs
permalink: /projects/opsis/docs/generate-synthetic-pdfs/
---

# Generating Synthetic PDFs for RAG Testing

Synthetic PDFs give you a realistic knowledge base to test the pipeline against
without needing real internal documentation. The generator lives at
`app/synthetic/pdf_generator.py` and uses ReportLab to produce multi-page PDFs
with a mix of on-topic and filler content.

> **Local script only — not containerized.**
> This is a one-off Mac-side utility for MVP testing. It runs directly with your
> local Python install, not inside Docker. You need `reportlab` installed locally:
> ```bash
> pip install reportlab
> ```
> In production you'd replace this with real internal documentation uploaded to
> your SharePoint or WebDAV server directly.

---

## Quick Commands

### Generate a single PDF

```bash
cd ~/mvp-opsis
python app/synthetic/pdf_generator.py \
  --topic "password reset" \
  --pages 5 \
  --relevant-ratio 0.7 \
  --output ./data/pdfs/password-guide.pdf
```

### Generate the full default batch (5 PDFs)

```bash
python app/synthetic/pdf_generator.py --batch
```

Produces:

| File | Topic | Pages | Relevant ratio |
|------|-------|-------|----------------|
| `password-guide.pdf` | password reset | 4 | 70% |
| `billing-guide.pdf`  | billing        | 5 | 70% |
| `login-guide.pdf`    | login          | 3 | 60% |
| `error-codes.pdf`    | error codes    | 4 | 60% |
| `general-guide.pdf`  | general support| 6 | 40% |

---

## Parameters

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--topic` | string | `"general support"` | The subject the PDF is about. Controls which content lines are selected (see Topics below). |
| `--pages` | int | `5` | Approximate number of pages. Actual page count may vary slightly depending on line wrapping. |
| `--relevant-ratio` | float 0–1 | `0.6` | Fraction of content lines that are on-topic. The rest are filler noise sentences. `1.0` = pure signal, `0.0` = pure noise. |
| `--output` | path | `./data/pdfs/synthetic.pdf` | Where to write the PDF. Parent directories are created automatically. |
| `--batch` | flag | off | Ignore all other flags and generate the full default set of 5 PDFs. |

---

## How It Works

### 1. Topic matching → relevant lines

The generator has a `TOPIC_CONTENT` dictionary keyed by keywords:

```
"password" → 10 lines about password reset flows, expiry, lock policies
"billing"  →  8 lines about invoices, payment methods, refunds
"login"    →  7 lines about login troubleshooting, SSO, session errors
"error"    →  8 lines about HTTP error codes 400–500
```

When you pass `--topic "password reset"`, it scans every key and includes lines
from any key that appears as a substring in your topic string. So
`--topic "password reset"` matches `"password"`, while
`--topic "login and billing"` matches both `"login"` and `"billing"`.

If nothing matches, the generator falls back to the 15 generic filler sentences.

### 2. Filler noise

The remaining `(1 - relevant_ratio)` fraction is filled with generic support
boilerplate — things like:

> "Ensure that your browser cache is cleared before attempting to log in again."

This simulates real documentation where only part of a page is relevant to any
given query. It makes the RAG pipeline actually work to find the right chunks
rather than returning everything.

### 3. Page layout

Each page holds approximately 35 lines at 14pt line spacing:

```
Title + metadata header (first page only)
│
├─ sentence
├─ sentence
├─ (blank gap)
├─ sentence
│  ...
└─ Page N  (footer, every page)
```

Lines shorter than 55 characters that don't end with a period are rendered as
**bold section headers** — a simple heuristic that occasionally fires on short
content lines and makes the document look more realistic.

### 4. Output

ReportLab writes a standard PDF (letter size, 8.5×11 inches). File sizes are
typically 15–40 KB depending on page count.

---

## Adding New Topics

To test the pipeline against different ticket types, add a new key to
`TOPIC_CONTENT` in `app/synthetic/pdf_generator.py`:

```python
TOPIC_CONTENT = {
    # existing keys ...

    "api": [
        "API keys can be generated under Settings > Developer > API Keys.",
        "Each key can be scoped to specific endpoints using permission sets.",
        "Rotate your API key immediately if it is exposed in a public repository.",
        "Include the API key in the Authorization header as a Bearer token.",
        "Webhook signatures are verified using HMAC-SHA256.",
    ],
}
```

Then generate a PDF targeting that topic:

```bash
python app/synthetic/pdf_generator.py \
  --topic "api keys" \
  --pages 4 \
  --relevant-ratio 0.75 \
  --output ./data/pdfs/api-guide.pdf
```

---

## Upload to WebDAV After Generating

PDFs need to be in WebDAV for the indexer to find them. Two options:

**Option A — Drag and drop via browser**

Open `http://localhost:8082` (Cloud Commander) and drag the PDFs from
`~/mvp-opsis/data/pdfs/` into the file browser.

**Option B — Upload via curl**

```bash
for f in ~/mvp-opsis/data/pdfs/*.pdf; do
  fname=$(basename "$f")
  curl -u admin:admin123 -T "$f" "http://localhost:8081/$fname"
  echo "Uploaded: $fname"
done
```

---

## Re-index After Uploading

After adding new PDFs to WebDAV, re-run the indexer to embed them into Pinecone:

```bash
cd ~/mvp-opsis
bash scripts/index-pdfs.sh
```

The indexer uses MD5-based vector IDs, so re-running on already-indexed PDFs is
safe — existing vectors are upserted (overwritten), not duplicated.

---

## Relevant Ratio — Choosing the Right Value

| Ratio | Use case |
|-------|----------|
| `0.9–1.0` | Unit testing: you want the RAG to almost always find the answer |
| `0.6–0.8` | Realistic testing: simulates real docs with mixed content |
| `0.3–0.5` | Stress testing: most of the doc is noise — tests retrieval precision |
| `0.0–0.2` | Negative testing: verifies the pipeline handles "nothing relevant found" |
