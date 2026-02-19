---
layout: page
title: Problems with the RAG Pipeline
permalink: /projects/opsis/docs/rag-pipeline-problems/
---

> Imported from `docs/Problems_with_rag_pipeline.md`

# Problems with the RAG Pipeline — Debugging Log

A complete record of every issue encountered while building the Jira → RAG → Phanes
support pipeline, in the order they appeared. Each entry covers the error, the root
cause, and the fix applied.

---

## Issue 1 — Jira 403: Basic Auth disabled

### Error
```
JIRAError: JiraError HTTP 403 url: http://jira:8080/rest/api/2/issue/SUP-1
text: Basic auth with password is not allowed. Use an API token.
```

### Cause
The Jira Server instance was configured with Basic Auth disabled for password-based
credentials. Both `main.py` and `jira_tool.py` were constructing clients with:
```python
jira = JIRA(server=url, basic_auth=(email, token))
```
The `basic_auth=` tuple sends `Authorization: Basic <base64(email:token)>`, which Jira
rejected even when the credential was a PAT.

### Fix
Switch to `token_auth=` in both files. This sends `Authorization: Bearer <token>`,
which Jira Server accepts for PATs even when Basic Auth is disabled:
```python
# main.py and jira_tool.py
jira = JIRA(server=settings.jira_url, token_auth=settings.jira_api_token)
```

---

## Issue 2 — JQL error: `comment is EMPTY` not supported

### Error
```
JIRAError: Error in the JQL Query: The field 'comment' does not support the 'EMPTY'
operator in Jira Server.
```

### Cause
The initial JQL filter tried to find unresponded tickets using:
```
project = SUP AND comment is EMPTY
```
The `is EMPTY` operator is not supported for the `comment` field in Jira Server (it
works in Jira Cloud). Jira Server's JQL parser rejected it entirely.

### Fix
Remove the comment filter from JQL. Instead, filter in Python after fetching results
by checking `issue.fields.comment.total == 0`, and later replace that with a
three-layer Phanes-specific comment guard (see Issue 4).

---

## Issue 3 — New tickets not picked up: `labels != "auto-responded"` misses label-less tickets

### Error
No visible error — the pipeline logged "No new tickets. Sleeping..." even after a new
ticket was created in Jira with no labels.

### Cause
The JQL filter used:
```
labels != "auto-responded"
```
In Jira, `!=` only matches issues that **have the label field set to something other
than** the given value. Issues with **no labels at all** do not match `!=` — they are
silently excluded from results.

### Fix
Use the `OR labels is EMPTY` form to explicitly include tickets with no labels:
```python
jql = (
    f'project = {project} AND statusCategory != Done '
    f'AND (labels not in ("auto-responded") OR labels is EMPTY) '
    f'ORDER BY created ASC'
)
```

---

## Issue 4 — `AttributeError: 'PropertyHolder' has no attribute 'status'` in debug print

### Error
```
AttributeError: 'PropertyHolder' has no attribute 'status'
pipeline crashed after printing ticket list
```

### Cause
A debug line was printing `issue.fields.status` for tickets returned from
`jira.search_issues()`. The `search_issues()` call did not include `status` in its
`fields` parameter, so the field was not populated. Accessing it on a `PropertyHolder`
object with no data raises `AttributeError`.

### Fix
Remove `status` from the debug print, or include it in the `fields` parameter of
`search_issues()`. The simpler fix was to remove the field from the debug line since
it was not needed for filtering logic.

---

## Issue 5 — Duplicate comments: `comment.total == 0` filter too aggressive

### Cause
The early deduplication logic skipped any ticket that had `comment.total > 0`. This
was intended to skip already-responded tickets, but it also blocked tickets that had
received comments from humans or other bots before Phanes had a chance to respond.

Additionally, Jira Server's `search_issues()` sometimes returns comment objects
without fully populating the `comments` list even when `total > 0`. This could cause
`AttributeError` when iterating comments.

### Fix
Replace the `comment.total == 0` filter with a three-layer guard that checks whether
the Phanes bot specifically has already commented:

```python
BOT_USERNAME = "phanes"

def phanes_has_commented(issue) -> bool:
    try:
        comment_obj = getattr(issue.fields, "comment", None)
        if comment_obj is None:
            return False
        comments = getattr(comment_obj, "comments", []) or []
        for comment in comments:
            author_name = (
                getattr(comment.author, "name", "")
                or getattr(comment.author, "displayName", "")
                or getattr(comment.author, "accountId", "")
            )
            if BOT_USERNAME in author_name.lower():
                return True
    except Exception:
        pass
    return False
```

The three layers of defence are:
1. `getattr` with defaults — never crashes on missing fields
2. `try/except Exception: pass` — silently handles any Jira object weirdness
3. Check three author fields (`name`, `displayName`, `accountId`) — covers both
   Jira Server and Jira Cloud user object shapes

---

## Issue 6 — `patch_crewai.py` IndentationError after patching

### Error
```
IndentationError: unexpected indent
  File ".../crewai/_internal/something.py", line N
    import importlib.metadata
    ^
```

### Cause
`patch_crewai.py` used a simple string replace:
```python
content.replace("import pkg_resources", PATCH_LINES)
```
The original `import pkg_resources` line might appear inside a `try:` block or
function body with indentation. The replacement pasted the multi-line patch with no
indentation, producing:

```python
    try:
import importlib.metadata   # ← wrong: should be indented
import pkg_resources        # ← leftover original, also wrong
```

### Fix
Switch to line-by-line parsing. Detect the indentation prefix of the matched line,
then prepend it to every line of the generated replacement:

```python
lines = content.splitlines(keepends=True)
new_lines = []
for line in lines:
    stripped = line.lstrip()
    if stripped.startswith("import pkg_resources"):
        indent = line[: len(line) - len(stripped)]
        for patch_line in PATCH_LINES.splitlines():
            new_lines.append(indent + patch_line + "\n")
    else:
        new_lines.append(line)
content = "".join(new_lines)
```

---

## Issue 7 — llama3.2 passes Pydantic field schema dict as tool value

### Error
```
## Tool Input:
"{'ticket_key': {'description': 'The Jira ticket key...', 'type': 'str'}}"
```
The tool received a dict describing the field schema instead of the actual value.

### Cause
llama3.2 (3B) sometimes confuses the Pydantic `Field(description=...)` schema
definition with the actual value that should be passed. When it serializes the action
input, it copies the schema dict rather than filling it in with a real value.

This is a known limitation of small models with complex tool schemas — too many fields
with detailed descriptions increases the chance of schema confusion.

### Fix — Three layers:

**Layer 1:** Write tool descriptions imperatively and add an `Example call:` line:
```python
description: str = (
    "Fetches a Jira ticket by its key and returns a structured JSON summary. "
    "Example call: {\"ticket_key\": \"SUP-1\"}"
)
```

**Layer 2:** Simplify the schema — remove optional fields (`top_k`) that increase
surface area for confusion.

**Layer 3:** Add a Pydantic `field_validator(mode="before")` that intercepts schema
dicts and recovers gracefully:
```python
def _coerce_str(v: Any) -> str:
    if isinstance(v, str):
        return v
    if isinstance(v, dict):
        # LLM passed the field schema — try to extract something useful
        for key in ("value", "default", "ticket_key", "comment_body", "query"):
            if key in v and isinstance(v[key], str):
                return v[key]
        return ""
    return str(v) if v is not None else ""

@field_validator("ticket_key", mode="before")
@classmethod
def coerce_ticket_key(cls, v: Any) -> str:
    return _coerce_str(v)
```

---

## Issue 8 — CrewAI tool-calling loop: the core problem

This was the hardest issue and required a fundamental architectural change.

### Error
```
# Agent: Jira Ticket Analyst
## Using tool: jira_fetch_ticket
## Tool Input:
"{\"ticket_key\": \"SUP-1\"}"
## Tool Output:
{
  "key": "SUP-1",
  "summary": "Login issue",
  ...
}

# Agent: Jira Ticket Analyst
## Thought: I need to extract the necessary information from the Jira ticket summary.
## Using tool: jira_fetch_ticket
## Tool Input:
"{\"ticket_key\": \"SUP-1\"}"
## Tool Output:
I tried reusing the same input, I must stop using this action input.
I'll try something else instead.

[repeats indefinitely until max_iter is exhausted]
```

### Cause — CrewAI's ReAct loop and llama3.2's limitation

CrewAI uses the ReAct (Reason + Act) framework. The expected flow is:
```
Thought: I need to fetch the ticket.
Action: jira_fetch_ticket
Action Input: {"ticket_key": "SUP-1"}
Observation: { "key": "SUP-1", "summary": "Login issue", ... }
Thought: I now know the final answer.
Final Answer: problem_statement: ...
```

llama3.2 (3B) receives the JSON `Observation` correctly but then generates:
```
Thought: I need to extract the necessary information from the Jira ticket summary.
Action: jira_fetch_ticket
Action Input: {"ticket_key": "SUP-1"}
```

It never generates `Thought: I now know the final answer`. It permanently believes
it still needs to "extract" — apparently misunderstanding that calling the tool IS
the extraction, not a step before it.

CrewAI has a built-in duplicate-call cache. When the same `(action, input)` pair is
seen a second time it returns the string `"I tried reusing the same input, I must stop
using this action input."` This cache message then becomes the agent's next
`Observation`, but the agent — not understanding why it received a strange error —
simply tries the same tool call again. The loop is permanent.

This is a fundamental capability gap in 3B models: they understand text analysis well
but struggle with the multi-step meta-cognition required to know when to stop acting
and declare a final answer.

### Fix Attempt 1 — Prompt engineering (failed)

Added explicit instructions to the task description:
```
"CRITICAL: You must call jira_fetch_ticket only once.
The moment you have the tool result, stop using tools and provide your Final Answer."
```

**Result:** The model acknowledged these instructions in its `Thought` step, then
immediately called the tool again. Prompt engineering cannot override a capability
gap at 3B scale — the model doesn't have the meta-reasoning to follow the instruction
while also tracking tool state.

### Fix Attempt 2 — Raise `max_iter` (partially helped)

Raised `max_iter` from 3 to 6 on the analyzer and from 3 to 5 on the writer.

**Result:** The loop still occurred, but the model had more attempts to eventually
stumble into a valid Final Answer. Unreliable — sometimes worked, usually didn't.
Not a real fix.

### Fix Attempt 3 — Remove tools from analyzer, pre-fetch in Python (resolved)

The correct diagnosis: the model is good at **reading text and producing text**. It is
bad at **managing a tool-calling loop**. The solution is to separate these concerns.

Pre-fetch the Jira ticket in Python before the crew starts:
```python
# support_crew.py
ticket_json = JiraFetchTool()._run(ticket_key)
```

Embed the result directly in the task description:
```python
analyze_task = Task(
    description=(
        "Analyze the following Jira support ticket...\n\n"
        f"TICKET DATA (JSON):\n```\n{ticket_json}\n```\n\n"
        "Do not call any tools. The ticket data is already provided above."
    ),
    ...
)
```

Remove `JiraFetchTool` from the analyzer agent:
```python
return Agent(
    ...
    tools=[],  # No tools — data is embedded in the task description
)
```

**Result:** The analyzer received the JSON as plain text, summarized it correctly on
the first LLM call, and produced a Final Answer immediately. No loop.

---

## Issue 9 — Same loop on the Knowledge Retriever (RAG tool)

### Error
```
# Agent: Knowledge Base Retriever
## Using tool: rag_knowledge_search
## Tool Input:
"{\"query\": \"The user is unable to log in to the system.\"}"
## Tool Output:
I tried reusing the same input, I must stop using this action input.
```

### Cause
Identical root cause to Issue 8. The Knowledge Retriever called `rag_knowledge_search`
once (successfully, returning vector search results), then called it again with the
same query, triggering the CrewAI cache. It then looped indefinitely.

The task description asked the agent to run "at least two" queries with different
terms — but the model always generated the same query on every attempt.

### Fix
Apply the same pre-fetch pattern. Run RAG searches in Python before the crew starts,
using the ticket summary and description as queries:

```python
def _run_rag_searches(ticket_data: dict) -> str:
    rag_tool = RAGSearchTool()
    summary = ticket_data.get("summary", "").strip()
    description = (ticket_data.get("description", "") or "").strip()[:300]

    results = []
    seen: set[str] = set()
    for query in [summary, description]:
        if not query or query in seen:
            continue
        seen.add(query)
        raw = rag_tool._run(query)
        results.append(f"### Query: {query}\n{raw}")

    return "\n\n".join(results) if results else "No documentation found."
```

Embed the results in the retriever's task description and remove `RAGSearchTool` from
the agent:
```python
return Agent(..., tools=[])
```

---

## Issue 10 — Pre-empted: Response Writer jira_post_comment loop

### Cause (anticipated)
The Response Writer agent had `tools=[JiraCommentTool()]`. Based on Issues 8 and 9,
it was certain to exhibit the same loop: write a comment, call `jira_post_comment`,
receive a success message, then try to call it again with the same comment body,
triggering the cache.

### Fix (pre-emptive)
Move comment posting to Python after `crew.kickoff()` returns:

```python
result = crew.kickoff()
comment_text = str(result)

# Post via Python — never via a tool call inside an agent
post_result = JiraCommentTool()._run(ticket_key, comment_text)
```

Remove `JiraCommentTool` from the writer agent:
```python
return Agent(..., tools=[])
```

The writer's task description now ends with:
```
"Return ONLY the comment text as your Final Answer.
Do not call any tools — the comment will be posted to Jira automatically."
```

---

## Issue 11 — Phanes writer: ReAct format parse failure on tool-free agent

### Error
```
# Agent: Phanes, Oracle of the Opsis Support Temple
## Task: Write a first-response comment for Jira ticket SUP-1.
...
 Error parsing LLM output, agent will retry: I did it wrong.
 Invalid Format: I missed the 'Action Input:' after 'Action:'.
 I will do right next, and don't use a tool I have already used.

 Error parsing LLM output, agent will retry: I did it wrong.
 Invalid Format: I missed the 'Action:' after 'Thought:'.
 I will do right next, and don't use a tool I have already used.
```

### Cause — CrewAI uses ReAct format even for tool-free agents

Even when `tools=[]`, CrewAI still wraps every agent's LLM call in the ReAct
(Reason + Act) prompt template. The system prompt tells the model to follow this
format:

```
Thought: you should always think about what to do
Action: the action to take
Action Input: the input to the action
Observation: the result of the action
...
Thought: I now know the final answer
Final Answer: the final answer to the original input question
```

The Phanes agent's backstory is long and contains a full prose example response —
the model reads it and naturally generates a Phanes-style response in prose, but
doesn't prefix it with `Final Answer:`. CrewAI's parser sees a `Thought:` line
followed by prose text (not `Action:` or `Final Answer:`), fails to parse it, and
asks the model to retry.

The model then tries to use `Action:` / `Action Input:` format (there are no tools,
so this also fails), triggering another parse error. This cycle repeats until
`max_iter` is exhausted or CrewAI's built-in recovery prompt kicks in.

This issue is distinct from the tool-calling loop (Issues 8–10). The tool-calling
loop was caused by the model re-calling tools. This issue is caused by the model
generating the RIGHT content but in the WRONG format — missing the required
`Final Answer:` prefix.

### Fix

Embed the exact expected output format directly in the task description. Make it the
last thing the model reads before generating its response:

```python
respond_task = Task(
    description=(
        ...
        "You have NO tools. Do NOT write Action: or Action Input:.\n"
        "Output your response using EXACTLY this format — no other format is accepted:\n\n"
        "Thought: I now can give a great answer\n"
        "Final Answer: [your complete Phanes comment here]"
    ),
    ...
)
```

By providing the literal `Thought:` / `Final Answer:` template at the end of the
task description, the model can pattern-match its own output against the template
and produce the correct format on the first attempt, bypassing all retry logic.

### Why this format works

The model sees the template immediately before it generates its output. In context
position terms, the format instruction is the closest thing to the generation start
point, so it has the highest influence on the model's output format. This is a form
of **few-shot format prompting within the task description** — the model doesn't
need to recall the ReAct format from training; it just continues the pattern it sees.

---

## Final Architecture — All I/O in Python, Agents Are Text Generators

```
Before (broken):
  Python → [Analyzer w/ jira_fetch_ticket] → loop
           [Retriever w/ rag_knowledge_search] → loop
           [Writer w/ jira_post_comment] → loop

After (working):
  Python: fetch ticket via JiraFetchTool()._run()
  Python: run RAG searches via RAGSearchTool()._run()
      ↓
  [Analyzer agent — tools=[]]: reads ticket JSON → writes structured analysis
  [Retriever agent — tools=[]]: reads RAG results → writes synthesized context
  [Writer agent (Phanes) — tools=[]]: reads analysis + context → writes comment text
      ↓
  Python: post comment via JiraCommentTool()._run()
  Python: apply auto-responded label
```

### Why this works for llama3.2

| Task type | llama3.2 performance |
|-----------|---------------------|
| Read structured JSON, summarize it |  Good |
| Read text passages, synthesize them |  Good |
| Generate styled prose from context |  Good |
| Follow an explicit format template shown at end of prompt |  Good |
| Know when to stop calling a tool and declare Final Answer |  Unreliable at 3B |
| Re-call a tool with a different query when told to vary |  Unreliable at 3B |
| Self-select correct output format from training alone |  Unreliable at 3B |

The architecture maps tasks to what the model can actually do. All tool-calling
decisions are made by Python, not the LLM. LLM calls are pure: text in → text out.

### Rule of thumb for small models in CrewAI

> If a task requires a tool call, do it in Python before giving the agent its task.
> Reserve the LLM for text transformation only.

This rule generalizes: for any model under ~7B parameters running locally, treat
CrewAI agents as text-transformation units rather than autonomous tool-calling agents.
The ReAct loop requires a model large enough to reliably distinguish "I have the
information I need" from "I need to gather more information" — a meta-cognitive skill
that emerges more reliably at 7B+ (and is robust at 13B+).

---

## Issue 12 — PineconeDB wipes all vectors on every container restart

### Error
```
### Query: login issue
{"found": 0, "error": "Client error '404 Not Found' for url
'http://pinecone-local:5080/indexes/ticket-knowledge'", "chunks": []}
```
RAG results return zero chunks even though PDFs were indexed successfully before.

### Cause — PineconeDB is in-memory only

`ghcr.io/pinecone-io/pinecone-local` is an in-memory emulator. It stores all index
data in RAM and has no persistence layer. Every `docker compose restart pinecone-local`
or `docker compose down` wipes every index and all vectors completely.

The named volume `pinecone-data:/data` in `docker-compose.yml` has no effect —
PineconeDB does not write to `/data` and provides no environment variable to
configure a persistence path. This is confirmed in the [official Pinecone docs](https://docs.pinecone.io/guides/operations/local-development):
PineconeDB is explicitly designed as a stateless, ephemeral development tool.

### Fix — Auto-reindex on pipeline startup

Rather than manually running the indexer after every restart, the pipeline now
checks the vector count at boot and re-indexes automatically if the index is empty.

**`app/config/settings.py`** — new setting:
```python
# ── Startup behaviour ─────────────────────────────────────
auto_reindex_on_startup: bool = Field(default=True)
```

**`.env`** — toggle to disable:
```
# Set to false to manage indexing manually
AUTO_REINDEX_ON_STARTUP=true
```

**`app/main.py`** — startup guard in `main()`:
```python
if settings.auto_reindex_on_startup:
    ensure_index_populated()
```

**`ensure_index_populated()`** checks three states:

| State | Action |
|-------|--------|
| Pinecone unreachable | Log warning, continue (don't crash) |
| Index does not exist | Create it + run full indexer |
| Index exists but empty | Run full indexer |
| Index has vectors | Log count, skip indexer |

The indexer call is lazy-imported (`from indexer.pdf_indexer import PDFIndexer`)
so it only loads if actually needed, keeping normal startup fast.

### To disable and index manually

```bash
# .env
AUTO_REINDEX_ON_STARTUP=false

# Then manually when needed:
docker compose exec pipeline python -m indexer.pdf_indexer
```

---

## Summary Table

| # | Issue | Root Cause | Fix |
|---|-------|------------|-----|
| 1 | Jira 403 Basic Auth | `basic_auth=` rejected | `token_auth=` PAT |
| 2 | JQL `comment is EMPTY` | Not supported on Jira Server | Filter in Python |
| 3 | New tickets not found | `labels !=` excludes no-label tickets | `(not in ... OR labels is EMPTY)` |
| 4 | AttributeError on `status` | Field not in `search_issues` fields list | Remove from debug print |
| 5 | Duplicate Phanes comments | `comment.total == 0` too broad | Per-author comment guard |
| 6 | IndentationError in patched file | `str.replace` ignores indentation | Line-by-line indent detection |
| 7 | LLM passes schema dict as value | llama3.2 confuses schema with value | `field_validator(mode="before")` coercion |
| 8 | Analyzer tool-calling loop | 3B model cannot exit ReAct loop | Pre-fetch ticket in Python, `tools=[]` |
| 9 | Retriever tool-calling loop | Same cause as Issue 8 | Pre-fetch RAG in Python, `tools=[]` |
| 10 | Writer post-comment loop | Same cause as Issue 8 | Post comment in Python after `crew.kickoff()` |
| 11 | Phanes ReAct parse failure | Model writes prose without `Final Answer:` prefix | Embed exact `Thought:/Final Answer:` template in task description |
| 12 | Pinecone empty after restart | PineconeDB is in-memory only, no persistence | `ensure_index_populated()` at startup; toggle via `AUTO_REINDEX_ON_STARTUP` |
