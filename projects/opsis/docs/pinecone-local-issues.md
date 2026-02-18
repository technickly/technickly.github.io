---
layout: page
title: Pinecone Local Issues
permalink: /projects/opsis/docs/pinecone-local-issues/
---

> Imported from `docs/pinecone-local-issues.md`

# Pinecone Local — Known Issues & Fixes

A running log of every issue hit when using `ghcr.io/pinecone-io/pinecone-local:latest`
with the Pinecone Python SDK v5 (`pinecone==5.4.2`) in a Docker Compose environment
on Apple Silicon (ARM64).

---

## Issue 1 — Healthcheck fails: `/bin/sh` not found

**Error**
```
OCI runtime exec failed: unable to start container process:
exec: "/bin/sh": stat /bin/sh: no such file or directory
```

**Cause**
`pinecone-local` is a distroless image — there is no shell at all.
The `CMD-SHELL` form of Docker healthcheck requires `/bin/sh`, so it always fails.

**Fix**
Remove the healthcheck entirely from the `pinecone-local` service, and change the
pipeline's `depends_on` condition from `service_healthy` to `service_started`:

```yaml
pinecone-local:
  image: ghcr.io/pinecone-io/pinecone-local:latest
  # No healthcheck — distroless image has no shell
  # Verify manually: curl http://localhost:5080/indexes

pipeline:
  depends_on:
    pinecone-local:
      condition: service_started   # was: service_healthy
```

---

## Issue 2 — SDK rejects `cloud="local"` on index creation

**Error**
```
PineconeApiValueError: Invalid value for `cloud` (local),
must be one of ['gcp', 'aws', 'azure']
```

**Cause**
The Pinecone Python SDK v5 validates the `cloud` field client-side against real
cloud provider values before the request even leaves the process.
`ServerlessSpec(cloud="local", region="local")` is rejected immediately.

**Fix**
Bypass the SDK for index creation entirely — use `httpx` to POST directly to the
Pinecone Local REST API. Pass a valid-looking but dummy `cloud`/`region` — the
local server accepts these fields but ignores them at runtime:

```python
import httpx

httpx.post(
    f"{pinecone_host}/indexes",
    json={
        "name": "ticket-knowledge",
        "dimension": 768,
        "metric": "cosine",
        "spec": {
            "serverless": {"cloud": "aws", "region": "us-east-1"}
        },
    },
    headers={"Api-Key": "pinecone-local"},
)
```

---

## Issue 3 — SDK upsert returns 404

**Error**
```
pinecone.core.openapi.shared.exceptions.NotFoundException: (404)
Reason: Not Found
```

**Cause**
The Pinecone SDK v5 is designed for Pinecone Cloud, where each index gets its own
dedicated hostname (e.g. `https://my-index-xxx.svc.pinecone.io`). When connecting
to a local server, the SDK cannot auto-discover the data-plane host and ends up
sending upsert requests to the wrong URL.

**Fix**
Bypass the SDK for all data-plane operations (upsert, query) and use `httpx` directly.

---

## Issue 4 — Data plane is on a different port than control plane

**Error**
```
httpx.ConnectError: [Errno 111] Connection refused
# or
httpx.HTTPStatusError: 404 Not Found for url 'http://pinecone-local:5080/vectors/upsert'
```

**Cause**
Pinecone Local runs each index's **data plane on a separate port** from the control plane:

| Plane         | Port |
|---------------|------|
| Control plane | 5080 |
| Data plane    | 5081 (first index), 5082 (second), etc. |

The `GET /indexes/{name}` endpoint returns the data-plane host:
```json
{
    "name": "ticket-knowledge",
    "host": "localhost:5081",
    ...
}
```

Sending upsert requests to port 5080 returns 404. Sending to `localhost:5081` from
inside Docker returns connection refused because `localhost` inside a container
refers to the container itself — not the Mac host or the pinecone-local container.

**Fix**
After creating the index, fetch the describe-index response and replace `localhost`
with the container name (`pinecone-local`) to get the correct Docker-network address.
No port publishing is needed — containers on the same Docker network can reach each
other on any internal port:

```python
desc = httpx.get(f"{ctrl_host}/indexes/ticket-knowledge", headers=headers)
raw_host = desc.json().get("host", "")  # e.g. "localhost:5081"

# Replace localhost with the container name for Docker network routing
raw_host = raw_host.replace("localhost", "pinecone-local") \
                   .replace("127.0.0.1", "pinecone-local")
data_host = f"http://{raw_host}"  # → "http://pinecone-local:5081"

# Now upsert goes to the right place
httpx.post(f"{data_host}/vectors/upsert", json={"vectors": [...], "namespace": "..."})
```

---

## Summary — What works for Pinecone Local + Docker

| Operation       | Use SDK? | Method                              |
|-----------------|----------|-------------------------------------|
| List indexes    |        | `GET /indexes` via httpx            |
| Create index    |        | `POST /indexes` via httpx           |
| Resolve data host |      | `GET /indexes/{name}` → replace `localhost` with container name |
| Upsert vectors  |        | `POST /vectors/upsert` via httpx to data-plane host |
| Query vectors   |        | `POST /query` via httpx to data-plane host |

**TL;DR:** The Pinecone Python SDK v5 is built for Pinecone Cloud and is not
compatible with Pinecone Local in a Docker environment. Use `httpx` for all
Pinecone operations and store the resolved data-plane host after index creation.

---

## Pinecone Local Port Reference

```
Control plane:  http://localhost:5080          (from Mac host)
                http://pinecone-local:5080     (from other Docker containers)

Data plane:     http://localhost:5081          (from Mac host, first index)
                http://pinecone-local:5081     (from other Docker containers)
```

Only port 5080 needs to be published in `docker-compose.yml` for the control plane.
Port 5081 (and beyond) are reachable within `mvp-net` without publishing.
