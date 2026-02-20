---
layout: page
title: WebDAV and FileBrowser Setup
permalink: /projects/opsis/docs/docker-webdav-filebrowser/
---

#  WebDAV + FileBrowser — Local SharePoint Simulation

## The Concept

In a real enterprise setup, documentation and knowledge base PDFs live in **SharePoint**, Confluence, or a shared network drive. The RAG pipeline would connect to those systems to read source documents.

For this local MVP, we simulate that with two lightweight containers that together behave like a document management system:

```
┌─────────────────────────────────────────────────────┐
│              "SharePoint" Simulation                 │
│                                                      │
│  ┌──────────────────┐      ┌──────────────────────┐  │
│  │   FileBrowser    │      │       WebDAV         │  │
│  │   :8082          │      │       :8081          │  │
│  │                  │      │                      │  │
│  │  Human uploads   │      │  Machine reads       │  │
│  │  via browser UI  │      │  via HTTP protocol   │  │
│  │  (drag & drop)   │      │  (pipeline)          │  │
│  └────────┬─────────┘      └──────────┬───────────┘  │
│           │                           │              │
│           └──────────┬────────────────┘              │
│                      │                               │
│            ┌─────────▼──────────┐                   │
│            │  Docker Volume     │                   │
│            │  webdav-data       │                   │
│            │                   │                   │
│            │  /var/lib/dav/data │                   │
│            │  ├── password.pdf  │                   │
│            │  ├── billing.pdf   │                   │
│            │  └── errors.pdf    │                   │
│            └────────────────────┘                   │
└─────────────────────────────────────────────────────┘
```

**FileBrowser** is the human-facing interface — you drag and drop PDFs in via browser, just like uploading to a SharePoint document library.

**WebDAV** is the machine-facing interface — the pipeline connects to it programmatically via the WebDAV HTTP protocol to list and download files, just like an app reading from a SharePoint REST API.

Both containers mount the **same Docker volume** at the same internal path (`/var/lib/dav/data/`). A file uploaded via FileBrowser is instantly available to the WebDAV server, and therefore instantly available to the pipeline — no sync, no copy, no delay.

---

## Why This Simulates SharePoint

| SharePoint (real) | This setup (local) |
|---|---|
| Document library UI in browser | FileBrowser at http://localhost:8082 |
| SharePoint REST API / Graph API | WebDAV protocol at http://localhost:8081 |
| Folder structure in library | Directory structure in the volume |
| Upload via browser drag & drop | Upload via FileBrowser drag & drop |
| App reads docs via API | Pipeline reads docs via WebDAV HTTP |
| Auth via Azure AD / OAuth | Basic auth (admin / admin123) |

To move this to production: replace the WebDAV tool in `app/tools/webdav_tool.py` with a SharePoint Graph API client. The rest of the pipeline (chunking, embedding, Pinecone, CrewAI) stays identical.

---

## Start

```bash
docker compose up -d webdav filebrowser
```

---

## How the Volume Is Wired

```yaml
# docker-compose.yml

webdav:
  volumes:
    - webdav-data:/var/lib/dav       # WebDAV serves files from /var/lib/dav/data/

filebrowser:
  volumes:
    - webdav-data:/var/lib/dav       # Same volume, same path
  command: --root /var/lib/dav/data  # FileBrowser UI root = exact same folder
```

This is the key to seamless drag and drop — both containers share the same volume mounted at the same path, so they see an identical filesystem.

---

## FileBrowser — Human Upload UI

Open **http://localhost:8082** — no login required (local dev only).

Drag PDFs from Finder straight into the browser window. They are immediately available to the pipeline.

---

## WebDAV — Pipeline Access

The pipeline reads files via WebDAV HTTP. You can also use it from the command line:

```bash
# List all files
curl -u admin:admin123 http://localhost:8081/

# Upload a file
curl -u admin:admin123 -T myfile.pdf http://localhost:8081/myfile.pdf

# Download a file
curl -u admin:admin123 http://localhost:8081/myfile.pdf -o myfile.pdf
```

---

## Synthetic Test PDFs

Generate test documents without needing real ones:

```bash
cd ~/mvp-opsis/app
pip install reportlab --break-system-packages

# Generate 5 PDFs covering: password, billing, login, errors, general
python -m synthetic.pdf_generator --batch
# Output: app/data/pdfs/*.pdf
```

Then drag them into FileBrowser at http://localhost:8082.

---

## After Uploading New PDFs

Always re-index after adding new files so Pinecone stays up to date:

```bash
bash scripts/index-pdfs.sh
```

---

## Upgrading to Real SharePoint (Production Path)

When you're ready to connect to a real document source:

1. Replace `app/tools/webdav_tool.py` with a SharePoint Graph API client
2. Update `app/indexer/pdf_indexer.py` to call the new tool
3. Set SharePoint credentials in `.env`
4. Everything else (chunking, embedding, RAG, CrewAI) stays the same

The WebDAV layer is intentionally thin — it's just a file source. Swapping it out has zero impact on the rest of the pipeline.

---

## Credentials

| Service | URL | Username | Password |
|---|---|---|---|
| FileBrowser UI | http://localhost:8082 | _(none)_ | _(none)_ |
| WebDAV (pipeline) | http://localhost:8081 | `admin` | `admin123` |
