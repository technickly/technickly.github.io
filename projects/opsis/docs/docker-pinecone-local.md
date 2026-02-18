---
layout: page
title: PineconeDB Docker Setup
permalink: /projects/opsis/docs/docker-pinecone-local/
---

> Imported from `docker/pinecone/README.md`

#  PineconeDB Setup

PineconeDB is Pinecone's official local development server. It exposes the **exact same REST API** as Pinecone Cloud — meaning you can move to cloud Pinecone later with zero code changes.

## Container

```yaml
image: ghcr.io/pinecone-io/pinecone-local:latest
ports: 5080:5080
```

## Start

```bash
docker compose up -d pinecone-local
```

## Verify

```bash
# List indexes (empty on first start)
curl http://localhost:5080/indexes
# → {"indexes": []}

# After indexing runs, check the index
curl http://localhost:5080/indexes/ticket-knowledge
```

---

## Index Created by the Pipeline

The indexer script creates an index called `ticket-knowledge` with these parameters:

| Parameter | Value |
|---|---|
| Name | `ticket-knowledge` |
| Dimensions | `768` (nomic-embed-text output) |
| Metric | `cosine` |
| Namespace | `webdav-pdfs` |

---

## Configuration in `.env`

```bash
PINECONE_API_KEY=pinecone-local   # any non-empty string works for local
PINECONE_HOST=http://localhost:5080
PINECONE_INDEX=ticket-knowledge
PINECONE_NAMESPACE=webdav-pdfs
EMBEDDING_DIM=768
```

When the pipeline runs inside Docker, `PINECONE_HOST` is overridden to `http://pinecone-local:5080` (using the container hostname on `mvp-net`).

---

## Migrating to Pinecone Cloud

When you're ready to move to production:

1. Create a Pinecone account at https://app.pinecone.io
2. Create an index with the same dimensions (768) and metric (cosine)
3. Get your API key
4. Update `.env`:

```bash
PINECONE_API_KEY=<your-real-api-key>
PINECONE_HOST=https://<your-index-host>.pinecone.io
```

5. Re-run `bash scripts/index-pdfs.sh` to re-populate the cloud index

No code changes needed.

---

## Resetting the Index

To wipe and re-index everything:

```bash
# Delete and recreate the container + volume
docker compose stop pinecone-local
docker compose rm -f pinecone-local
docker volume rm mvp-opsis_pinecone-data
docker compose up -d pinecone-local

# Re-index
bash scripts/index-pdfs.sh
```
