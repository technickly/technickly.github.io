---
layout: page
title: Opsis Demo Walkthrough
permalink: /projects/opsis/docs/demo-walkthrough/
---

# Opsis AI — Support Pipeline Demo Walkthrough

> **What this is:** An end-to-end walkthrough of the Opsis RAG auto-responder pipeline.
> A Jira ticket is created by a user. Within one polling cycle, the pipeline reads the
> ticket, searches its PDF knowledge base, generates a contextually grounded response
> in the voice of **Phanes** (the Opsis support persona), and posts it back to the
> ticket — all without any human intervention.

---


## Step 1 — User Creates a Jira Ticket

A support user files a ticket in the `SUP` project describing their problem.

![Step 1 — Newly created Jira ticket, no comments, no labels](../screenshots/step1b_ticket_created.png)

**Ticket filed in this demo:**

| Field | Value |
|-------|-------|
| Project | SUP |
| Summary | `Login issue after password reset` |
| Description | `After resetting my password I can no longer log in. The page just reloads with no error message. Tried Chrome and Safari.` |
| Priority | Medium |
| Reporter | ryan |
| Status | Backlog |
| Labels | *(none)* |

The ticket lands in `Backlog` with no labels and zero comments — exactly the condition
the pipeline polls for.

---

## Step 2 — Pipeline Detects the Ticket

The pipeline polls Jira every 60 seconds using a JQL query that finds open,
unlabelled tickets.

**JQL used:**
```
project = SUP AND statusCategory != Done
AND (labels not in ("auto-responded") OR labels is EMPTY)
ORDER BY created ASC
```

**Pipeline log output:**
```
Polling Jira for new tickets (project=SUP)...
  JQL returned 1 ticket(s)
    SUP-8: comments=0  labels=[]
  After dedup filter: 1 ticket(s)
Found 1 unresponded ticket(s): ['SUP-8']
```

The pipeline confirms three conditions before processing:

- Ticket has **zero comments** (never been touched)
- Ticket has **no labels** (not yet processed)
- Ticket passes the **Phanes comment guard** (Phanes hasn't commented)

---

## Step 3 — Ticket Data Fetched (Python)

Before any AI agents run, the pipeline fetches the full ticket as structured JSON
directly in Python — no LLM involved at this step.

**Raw fetch output (`JiraFetchTool._run("SUP-8")`):**
```json
{
  "key": "SUP-8",
  "summary": "Login issue after password reset",
  "description": "After resetting my password I can no longer log in. The page just reloads with no error message. Tried Chrome and Safari.",
  "priority": "Medium",
  "status": "Backlog",
  "reporter": "ryan",
  "labels": [],
  "components": [],
  "created": "2026-02-19T14:22:03.000+0000"
}
```

This JSON is embedded directly into the Ticket Analyzer's task description, bypassing
the need for the LLM to call a tool — a deliberate design decision that keeps the
pipeline reliable regardless of model size by separating I/O from text generation.

---

## Step 4 — Knowledge Base Searched (Python)

The pipeline runs two semantic searches against the PineconeDB vector database,
using the ticket `summary` and `description` as queries. Embeddings are generated
via Ollama (`nomic-embed-text`).

**Searches run:**
```
Query 1: "Login issue after password reset"
Query 2: "After resetting my password I can no longer log in..."
```

**Results returned (formatted):**

```
── Chunk 1 ─────────────────────────────────────────────
   Source:  login_failed.pdf  (page 1)
   Score:   0.8921
   Text:    If you cannot log in verify that Caps Lock is not enabled.
            Contact your administrator to verify the email address on
            your account. Clear your browser cache and try again in
            an incognito window. Session cookies are required for
            login. Ensure cookies are enabled in your browser.

── Chunk 2 ─────────────────────────────────────────────
   Source:  login_failed.pdf  (page 3)
   Score:   0.8644
   Text:    If you see an error 401 your session has expired.
            Please log in again. SAML 2.0 and OpenID Connect are
            both supported for SSO configuration. Contact your
            administrator to verify the email address on your account.

── Chunk 3 ─────────────────────────────────────────────
   Source:  reset_password.pdf  (page 1)
   Score:   0.8201
   Text:    After a password reset, clear your browser cache and
            ensure cookies are enabled. MFA settings can be reviewed
            under Profile > Security.
```

---

## Step 5 — Agent 1: Ticket Analyzer

**Role:** Reads the pre-fetched JSON and produces a structured analysis that downstream
agents will use to formulate the response.

**Input:** Ticket JSON from Step 3, embedded in the task description.

**Agent output (Final Answer):**
```
problem_statement: The user is unable to log in after a password reset.
  The login page reloads silently without displaying any error message,
  occurring across multiple browsers.

technical_terms: password reset, session cookies, browser cache,
  login redirect loop, authentication

search_queries:
  - "login fails after password reset no error message"
  - "session cookie not set after authentication"
  - "browser cache login redirect loop"

priority: Medium
reporter: ryan
```

---

## Step 6 — Agent 2: Knowledge Retriever

**Role:** Reads the pre-fetched RAG chunks and synthesizes the most relevant passages
into a clean, cited context block for the response writer.

**Input:** Raw Pinecone results from Step 4, embedded in the task description.

**Agent output (Final Answer):**
```
The following documentation passages are most relevant to this login issue:

1. login_failed.pdf (p. 1) — Browser troubleshooting steps:
   Clear browser cache, try incognito window, ensure session cookies
   are enabled. Verify Caps Lock is off.

2. login_failed.pdf (p. 3) — Session and authentication:
   Error 401 indicates an expired session. SAML 2.0 / OpenID Connect
   are supported for SSO. Administrator can verify the account email.

3. reset_password.pdf (p. 1) — Post-reset guidance:
   Clear browser cache after reset. MFA settings under Profile > Security.
```

---

## Step 7 — Agent 3: Phanes Writes the Response

**Role:** **Phanes** — the Opsis support persona — takes the ticket analysis and
synthesized documentation and drafts a response.

**Persona:** Phanes (Φάνης) is named for the ancient Greek deity of light and new
beginnings, whose name shares its root with *opsis* (sight, vision, clarity).

**Agent output — the actual Phanes comment posted to Jira:**

---

> The user's inability to log in after password reset may stem from a temporary issue
> or an incorrect browser configuration. Here are steps to troubleshoot this issue:
>
> Firstly, ensure that Caps Lock is not enabled, as this can prevent login attempts.
> Also, verify that cookies are enabled in your browser.
>
> If the problem persists, try clearing your browser cache and cookies fully, then
> reload the page using a hard reload (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows).
>
> Additionally, check if two-factor authentication is enabled for your account by
> navigating to Profile > Security. If it's not enabled, consider enabling MFA to
> add an extra layer of security.
>
> If none of these steps resolve the issue, please refer to our reset password support
> documentation topic: reset password | Pages: ~3 | Version: 1.0
>
> The texts do not speak to this directly; let me carry your question to someone who
> can answer it. Our support team would be happy to assist you further.
>
> — Phanes, Opsis Support

---

> **Note on response quality:** The response above was generated by `llama3.1:8b` running
> locally via Ollama. Larger models (13B+) produce even richer philosophically-grounded
> responses. The persona voice, citations, and sign-off are controlled entirely by the
> agent's `backstory` and `temperature` fields in `response_writer.py` — no retraining
> required.

---

## Step 8 — Comment Posted to Jira

The comment is posted to the Jira ticket by the **Phanes bot user** — a dedicated
Jira account (`phanes`) separate from the admin account, so comments in Jira show
the Phanes identity rather than a generic admin username.

After posting the comment, the pipeline applies the `auto-responded` label to the
ticket, preventing any duplicate responses on subsequent polling cycles.

**Pipeline log:**
```
  [pipeline] Posting Phanes comment to SUP-8...
  [pipeline] SUCCESS: Comment posted to SUP-8 by Phanes,
             label 'auto-responded' added.

✓ Crew completed for SUP-8
```

---

## Step 9 — Output: Jira Ticket with Phanes Response

The user returns to their Jira ticket and sees the Phanes comment posted automatically.

![Step 9 — Jira ticket with Phanes comment and auto-responded label](../screenshots/step9_jira_final.png)

What's visible in the final ticket view:

- Comment posted by **Phanes · Opsis Support** (not the admin account)
- Step-by-step guidance grounded in the PDF knowledge base
- The `— Phanes, Opsis Support` sign-off
- The ticket is labelled **`auto-responded`** — the pipeline will skip it on all future polls

---

## End-to-End Timing

| Step | What happens | Approx. time |
|------|-------------|--------------|
| 1 | User creates ticket | — |
| 2 | Pipeline polling detects ticket | 0–60s |
| 3 | Python fetches ticket JSON | < 1s |
| 4 | Python runs 2 RAG searches | 2–4s |
| 5 | Ticket Analyzer agent (LLM) | 10–20s |
| 6 | Knowledge Retriever agent (LLM) | 10–20s |
| 7 | Phanes Response Writer (LLM) | 15–30s |
| 8 | Python posts comment + labels | < 1s |
| **Total** | **Ticket created → comment posted** | **~60–120s** |

LLM timing is on `llama3.1:8b` running natively on Apple Silicon via Ollama (Metal GPU).
A larger model (13B+) would produce higher-quality responses at the cost of some throughput.

---

## Key Design Highlights

**All tool I/O happens in Python, not the LLM.** Jira fetches, RAG searches, and
comment posting are all direct Python calls. The three LLM agents receive pre-fetched
data in their task descriptions and produce only text — no tool-calling loops possible.
This was a critical architectural fix for reliable operation with a 3B model.

**Zero duplicate responses.** Three-layer guard: JQL label filter → Python label
check → per-author comment check. Even if one layer fails, the others catch it.

**Auto-reindex on startup.** PineconeDB is in-memory only — every container
restart wipes vectors. The pipeline checks the index on boot and re-runs the PDF
indexer automatically if needed. No manual intervention required.

**Swappable knowledge base.** Drop new PDFs into WebDAV and re-run the indexer.
No code changes needed. The pipeline picks up new docs on the next restart.

**Swappable persona.** The Phanes voice is entirely defined by the agent's `role`,
`goal`, `backstory`, and `temperature` fields in `response_writer.py`. Changing
the persona requires editing one file — no model changes, no retraining.
