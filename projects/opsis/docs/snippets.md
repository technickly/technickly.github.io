---
layout: page
title: Opsis Code Snippets
permalink: /projects/opsis/docs/snippets/
---

# Opsis Code Snippets

These snippets reflect the latest MVP docs with emphasis on generating and indexing new PDF data.

## Generate synthetic PDF data (batch)

```bash
cd ~/mvp-opsis/app
python -m synthetic.pdf_generator --batch
# creates 5 PDFs in app/data/pdfs/
```

## Generate targeted dataset (single file)

```bash
cd ~/mvp-opsis/app
python -m synthetic.pdf_generator \
  --topic "password reset" \
  --pages 5 \
  --relevant-ratio 0.7 \
  --output ./data/pdfs/password-guide.pdf
```

## Upload and index

```bash
# Upload generated PDFs in browser
# http://localhost:8082 (FileBrowser)

# then index into Pinecone Local
bash scripts/index-pdfs.sh
curl http://localhost:5080/indexes | python3 -m json.tool
```

## Start pipeline and watch responses

```bash
docker compose up -d pipeline
docker compose logs -f pipeline
```
