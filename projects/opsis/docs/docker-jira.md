---
layout: page
title: Jira Docker Setup
permalink: /projects/opsis/docs/docker-jira/
---

#  Jira Setup

## Container

```yaml
image: atlassian/jira-software:latest
ports: 8080:8080
depends_on: jira-db (postgres:14)
```

## First Launch

Jira requires a one-time setup wizard. It only runs once — data persists in the `jira-data` Docker volume.

### 1. Start services

```bash
docker compose up -d jira-db
# Wait for Postgres to be healthy:
docker compose ps  # jira-db should show (healthy)

docker compose up -d jira
```

### 2. Wait for Jira to boot

```bash
docker compose logs -f jira
```

Look for: `Server startup in XXXXX ms`. First boot takes **3–8 minutes** — Jira is running DB migrations.

### 3. Open the setup wizard

Visit http://localhost:8080

Choose: **"I'll set it up myself"**

### 4. Database configuration

Select **"My own database"** and fill in:

| Field | Value |
|---|---|
| Database Type | PostgreSQL |
| Hostname | `jira-db` |
| Port | `5432` |
| Database | `jiradb` |
| Username | `jira` |
| Password | `jirapassword` |

Click "Test Connection" → should succeed.

### 5. License

When prompted for a license, get one from Atlassian:

1. Go to https://my.atlassian.com/license/evaluate
2. Sign in (free Atlassian account required)
3. Choose **Jira Software (Data Center)**
4. Evaluation — **10 users, 30 days**
5. Copy the license key
6. Paste into the Jira setup wizard

>  After 30 days you'll need a new eval license. For a permanent free option, Jira offers a free tier for up to 10 users on Jira Cloud (but that's not local).

### 6. Create admin account

Set an email and password. **Note these down** — you'll put them in `.env`.

### 7. Create a project

After setup completes:
1. Click "Create project"
2. Choose **Scrum** or **Kanban** (either works)
3. Note the **project key** (e.g., `SUP`) — set `JIRA_PROJECT_KEY` in `.env`

### 8. Generate API token

1. Click your avatar → **Profile**
2. → **Manage account** → **Security** → **API tokens**
3. → **Create API token** → name it "local-pipeline"
4. Copy the token → set `JIRA_API_TOKEN` in `.env`

---

## Verifying Connection

```bash
# Should return JSON with project info
curl -u your@email.com:YOUR_TOKEN \
  http://localhost:8080/rest/api/2/project/SUP | python3 -m json.tool
```

## Common Issues

**"Application Data directory not found"**
→ The `jira-data` volume isn't mounted correctly. Check `docker compose ps`.

**Jira stuck at "Loading" forever**
→ Not enough RAM. Increase Docker's memory limit to at least 6 GB in Docker Desktop settings.

**"Could not connect to database"**
→ Make sure `jira-db` is fully healthy before starting `jira`. Try `docker compose restart jira`.

**License expired**
→ Get a new eval license from Atlassian and apply it at: Admin → License details.

---

## Memory Tuning

In `docker-compose.yml`, adjust JVM memory to your machine:

```yaml
environment:
  JVM_MINIMUM_MEMORY: 1024m   # default
  JVM_MAXIMUM_MEMORY: 2048m   # increase to 3072m if you have 16+ GB RAM
```
