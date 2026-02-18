---
layout: page
title: Opsis Relevant Files
permalink: /projects/opsis/docs/relevant-files/
---

# Opsis Relevant Files

## Core docs

- `README.md` - system overview, stack, flow, and quick start
- `SETUP_GUIDE.md` - full setup and end-to-end test path
- `CHECKPOINTS.md` - phase-based validation checklist
- `ARCHITECTURE.md` - component map and data flow

## PDF data generation and ingestion

- `docs/generate-synthetic-pdfs.md` - synthetic dataset generation guide
- `app/synthetic/pdf_generator.py` - PDF generator CLI implementation
- `docs/pdf-indexing-explainer.md` - chunk/embed/upsert process details
- `app/indexer/pdf_indexer.py` - WebDAV -> chunk -> embed -> Pinecone indexer

## Pipeline + integrations

- `app/main.py` - polling loop and orchestration entry point
- `app/crew/support_crew.py` - crew and task orchestration
- `app/tools/rag_tool.py` - retrieval helper over PineconeDB
- `app/tools/webdav_tool.py` - WebDAV list/download operations
- `app/tools/jira_tool.py` - Jira fetch/post integration

## Infrastructure and troubleshooting

- `docker-compose.yml` - local service composition
- `docker/webdav/README.md` - WebDAV + FileBrowser setup and usage
- `docker/pinecone/README.md` - PineconeDB setup notes
- `docs/pinecone-local-issues.md` - known issues and local workarounds
