---
layout: page
title: Getting Started
permalink: /getting-started/
---

# Getting Started with Opsis

Get up and running with Opsis in minutes. This guide will walk you through installation, configuration, and your first AI-powered workflow.

## Prerequisites

Before installing Opsis, ensure you have:

- **Python 3.9+**: Check with `python --version`
- **pip**: Python package manager
- **Git**: For cloning the repository
- **4GB+ RAM**: Minimum for running local LLMs (8GB+ recommended)
- **Storage**: At least 10GB free for models and indexes

### Optional Requirements

- **GPU**: NVIDIA GPU with CUDA for faster LLM inference
- **Docker**: For containerized deployment
- **OpenDAV Server**: If using remote file storage
- **Jira Instance**: For project management integration

---

## Quick Start (5 Minutes)

### 1. Clone the Repository

```bash
git clone https://github.com/technickly/opsis.git
cd opsis
```

### 2. Install Dependencies

```bash
# Create a virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install Opsis and dependencies
pip install -r requirements.txt
```

### 3. Configure Opsis

```bash
# Copy the example configuration
cp config.example.yml config.yml

# Edit with your preferred editor
nano config.yml  # or vim, code, etc.
```

**Minimal Configuration**:
```yaml
# config.yml
opsis:
  data_dir: ./data
  index_dir: ./indexes

llm:
  provider: ollama
  model: llama3
  base_url: http://localhost:11434

embeddings:
  provider: sentence-transformers
  model: all-MiniLM-L6-v2
```

### 4. Install a Local LLM

**Using Ollama** (Recommended):
```bash
# Install Ollama from https://ollama.ai
curl https://ollama.ai/install.sh | sh

# Pull a model
ollama pull llama3
```

### 5. Run Opsis

```bash
python opsis.py
```

You should see:
```
 Opsis v1.0.0 - Local AI Knowledge Base
✓ LLM connection established (llama3)
✓ Embeddings loaded (all-MiniLM-L6-v2)
✓ Knowledge base ready

Opsis > _
```

Congratulations! You're ready to start using Opsis.

---

## First Steps

### Index Your First Documents

```bash
# In the Opsis shell
index /path/to/your/documents

# Or index a specific file
index /path/to/document.pdf
```

### Ask Your First Question

```bash
# Query your knowledge base
query "What are the main topics in my documents?"

# Or use the shorthand
? "Summarize the recent meeting notes"
```

### Create a CrewAI Workflow

```bash
# Use a pre-built workflow
workflow run document-summary --input /path/to/docs

# List available workflows
workflow list
```

---

## Configuration Guide

### Full Configuration Options

Create a comprehensive `config.yml`:

```yaml
# Opsis Configuration
opsis:
  # Data directories
  data_dir: ./data
  index_dir: ./indexes
  cache_dir: ./cache

  # Logging
  log_level: INFO
  log_file: ./logs/opsis.log

# LLM Configuration
llm:
  provider: ollama  # ollama, llama.cpp, textgen, vllm
  model: llama3
  base_url: http://localhost:11434

  # Model parameters
  temperature: 0.7
  max_tokens: 2048
  context_window: 4096

# Embeddings
embeddings:
  provider: sentence-transformers
  model: all-MiniLM-L6-v2
  device: cpu  # or 'cuda' for GPU
  batch_size: 32

# Vector Database
vector_db:
  provider: chroma  # chroma, faiss, qdrant
  persist_directory: ./indexes/chroma
  collection_name: opsis_docs

# RAG Settings
rag:
  chunk_size: 1000
  chunk_overlap: 200
  retrieval_k: 5  # Number of chunks to retrieve
  reranking: true

# Document Processing
documents:
  # Supported file types
  supported_formats:
    - .pdf
    - .txt
    - .md
    - .docx
    - .html

  # Processing options
  extract_images: false
  ocr_enabled: false

# OpenDAV Integration
opendav:
  enabled: false
  url: https://cloud.example.com/remote.php/webdav/
  username: your_username
  password: your_password  # Use environment variables!
  sync_interval: 300  # seconds
  watch_paths:
    - /Documents
    - /Projects

# Jira Integration
jira:
  enabled: false
  url: https://your-domain.atlassian.net
  username: your_email@example.com
  api_token: your_api_token  # Use environment variables!
  project_key: PROJ

  # Ticket creation defaults
  defaults:
    issue_type: Task
    priority: Medium

# CrewAI Workflows
crewai:
  max_agents: 5
  timeout: 300  # seconds per workflow
  verbose: true

# API Server (optional)
api:
  enabled: true
  host: 0.0.0.0
  port: 8000
  cors_origins:
    - http://localhost:3000
```

### Environment Variables

For sensitive data, use environment variables:

```bash
# .env file
OPSIS_OPENDAV_PASSWORD=your_secure_password
OPSIS_JIRA_API_TOKEN=your_api_token
OPSIS_LLM_API_KEY=optional_for_cloud_llms
```

Then reference in config:
```yaml
opendav:
  password: ${OPSIS_OPENDAV_PASSWORD}
```

---

## Integrations Setup

### OpenDAV Configuration

1. **Install WebDAV client libraries** (if not already included):
   ```bash
   pip install webdavclient3
   ```

2. **Configure in config.yml**:
   ```yaml
   opendav:
     enabled: true
     url: https://nextcloud.example.com/remote.php/webdav/
     username: your_username
     password: ${OPENDAV_PASSWORD}
     watch_paths:
       - /Documents/ProjectDocs
   ```

3. **Test connection**:
   ```bash
   python -c "from opsis.integrations import test_opendav; test_opendav()"
   ```

### Jira Integration

1. **Generate API Token**:
   - Go to https://id.atlassian.com/manage-profile/security/api-tokens
   - Create a new API token
   - Save it securely

2. **Configure in config.yml**:
   ```yaml
   jira:
     enabled: true
     url: https://your-domain.atlassian.net
     username: your_email@example.com
     api_token: ${JIRA_API_TOKEN}
     project_key: MYPROJ
   ```

3. **Test connection**:
   ```bash
   opsis jira test
   ```

---

## Common LLM Setups

### Ollama (Easiest)

```bash
# Install
curl https://ollama.ai/install.sh | sh

# Pull recommended models
ollama pull llama3        # General purpose
ollama pull codellama     # Code tasks
ollama pull mistral       # Fast & capable

# Config
llm:
  provider: ollama
  model: llama3
  base_url: http://localhost:11434
```

### llama.cpp

```bash
# Clone and build
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make

# Download a model (GGUF format)
# Place in ./models/

# Config
llm:
  provider: llama.cpp
  model_path: ./models/llama-3-8b.gguf
  n_ctx: 4096
  n_gpu_layers: 35  # Adjust for your GPU
```

### Text Generation WebUI

```bash
# Install from https://github.com/oobabooga/text-generation-webui
# Start the server with --api flag

# Config
llm:
  provider: textgen
  base_url: http://localhost:5000
  model: llama-3-8b
```

---

## Usage Examples

### Example 1: Document Q&A

```python
# Python API
from opsis import Opsis

opsis = Opsis(config_path='config.yml')

# Index documents
opsis.index_directory('/path/to/docs')

# Query
response = opsis.query("What are the key requirements from the PRD?")
print(response.answer)
print(f"Sources: {response.sources}")
```

### Example 2: CrewAI Workflow

```python
from opsis.workflows import DocumentAnalysisWorkflow

# Define workflow
workflow = DocumentAnalysisWorkflow(
    agents=[
        {'role': 'researcher', 'goal': 'Find relevant information'},
        {'role': 'analyst', 'goal': 'Synthesize findings'},
        {'role': 'writer', 'goal': 'Create report'}
    ]
)

# Execute
result = workflow.run(
    input_docs='/path/to/docs',
    output_format='markdown'
)

print(result.report)
```

### Example 3: Jira Integration

```python
# Automatically create tickets from document analysis
from opsis.integrations import JiraIntegration

jira = JiraIntegration(config=opsis.config)

# Analyze docs and create tickets
insights = opsis.analyze_for_actions('/path/to/meeting_notes.md')

for insight in insights:
    jira.create_issue(
        summary=insight.title,
        description=insight.description,
        issue_type='Task'
    )
```

---

## Troubleshooting

### LLM Connection Issues

```bash
# Test Ollama
curl http://localhost:11434/api/generate -d '{"model":"llama3","prompt":"hi"}'

# Check logs
tail -f logs/opsis.log
```

### Slow Indexing

- Reduce chunk size: `rag.chunk_size: 500`
- Increase batch size: `embeddings.batch_size: 64`
- Use GPU for embeddings: `embeddings.device: cuda`

### Memory Issues

- Use smaller models (e.g., `llama3:8b` instead of `llama3:70b`)
- Reduce context window: `llm.context_window: 2048`
- Limit retrieval: `rag.retrieval_k: 3`

---

## Next Steps

- **[Features](/features)**: Explore all Opsis capabilities
- **[Documentation](/docs)**: Dive deeper into specific topics
- **[API Reference](/docs/api)**: Build custom integrations
- **[Workflows](/docs/workflows)**: Create advanced automation

---

## Getting Help

- **GitHub Issues**: https://github.com/technickly/opsis/issues
- **Discussions**: https://github.com/technickly/opsis/discussions
- **Email**: [technickly@gmail.com](mailto:technickly@gmail.com)

[View Full Documentation →](/docs/){: .btn .btn-primary}
