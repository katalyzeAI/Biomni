# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Biomni is a general-purpose biomedical AI agent framework. The primary agent (`A1`) uses a ReAct-style agentic loop built on LangGraph to execute biomedical research tasks via LLM reasoning + code execution. It includes 30+ domain-specific tool modules, a retrieval-augmented tool selection system, and supports multiple LLM providers.

## Common Commands

### Installation
```bash
pip install -e .                    # Development install
pip install -e ".[gradio]"          # With Gradio UI support
```

### Linting & Formatting
```bash
# Pre-commit runs ruff (lint + format) and other checks
pre-commit run --all-files

# Ruff directly
ruff check biomni/                  # Lint
ruff check --fix biomni/            # Lint with auto-fix
ruff format biomni/                 # Format
```

### Environment Setup
The full bioinformatics environment is complex (~30GB). See `biomni_env/README.md` for four setup options ranging from basic (environment.yml) to full E1 (setup.sh, 10+ hours).

### Running the Agent
```python
from biomni.agent import A1
agent = A1(llm='claude-sonnet-4-5', path='./data')
agent.go("Your biomedical task")
agent.launch_gradio_demo()  # Web UI on port 7860
```

### Docker
```bash
docker compose build
docker compose up
```

## Architecture

### Agent System (`biomni/agent/`)
- **`a1.py`** — Main A1 agent class (~3000 lines). Implements a LangGraph `StateGraph` with three nodes: `generate` (LLM reasoning), `execute` (code execution), and `routing` (conditional branching). The agent uses XML tags (`<think>`, `<execute>`, `<solution>`) to structure its reasoning.
- **`react.py`** — Simpler ReAct agent implementation.
- **`AgentState`** — TypedDict with `messages` (conversation history) and `next_step` (routing signal).
- Code execution uses a **persistent namespace** (`_persistent_namespace` global in `support_tools.py`) so variables survive across execution steps.

### Tool System (`biomni/tool/`)
- **30+ domain modules** (genomics.py, proteomics.py, cancer_biology.py, database.py, etc.) each containing Python functions that serve as tools.
- **`tool_description/`** — Parallel directory with tool metadata schemas used for system prompt generation and retrieval.
- **`schema_db/`** — Pre-computed database schemas as `.pkl` files (included in package via MANIFEST.in).
- **`protocols/`** — Protocol databases (Addgene, Thermofisher).
- To add a new tool: implement function in `biomni/tool/{subject}.py`, add description in `biomni/tool/tool_description/{subject}.py`, use `function_to_api_schema()` for auto-documentation.

### Tool Retrieval (`biomni/model/retriever.py`)
When `use_tool_retriever=True` (default), the agent uses an LLM call to select relevant tools/data/software from the full catalog before executing a task. This keeps the system prompt manageable.

### Configuration (`biomni/config.py`)
- `BiomniConfig` dataclass with environment variable fallback (`BIOMNI_*` prefix).
- Global instance: `default_config`.
- Key settings: `llm`, `path`, `timeout_seconds`, `commercial_mode`, `use_tool_retriever`, `temperature`.

### LLM Abstraction (`biomni/llm.py`)
- `get_llm()` factory supports 8+ providers: OpenAI, Azure, Anthropic, Ollama, Gemini, Bedrock, Groq, Custom.
- Auto-detects provider from model name string.
- Returns LangChain `BaseChatModel`.

### Task & Evaluation (`biomni/task/`, `biomni/eval/`)
- `base_task.py` defines abstract interface: `get_example()`, `get_iterator()`, `evaluate()`, `get_prompt_from_input()`.
- `biomni_eval1.py` — 433-instance benchmark across 10 biomedical tasks.

### Know-How System (`biomni/know_how/`)
- Markdown documents with best practices (e.g., sgRNA design, single-cell annotation).
- `loader.py` parses frontmatter metadata and makes docs available to the agent.

### Environment Descriptions (`biomni/env_desc.py`, `biomni/env_desc_cm.py`)
- Large modules (~24-25KB) containing data lake descriptions, software library lists, and tool catalogs.
- `env_desc_cm.py` is the commercial-mode variant with license-filtered content.

### Extension Points
- **Custom tools**: `agent.add_tool(function)` — auto-generates schema via LLM.
- **MCP servers**: `agent.add_mcp(config_path)` — loads from YAML config.
- **Custom data/software**: `agent.add_data()`, `agent.add_software()`.

## Code Style

- **Line length**: 120 characters.
- **Formatter/Linter**: Ruff (replaces black + isort + flake8).
- **Python**: 3.11+ required.
- **Ruff rules**: F, E, W, I, B, TID, C4, BLE, UP, RUF100, TCH. Long lines (E501) are explicitly allowed.
- **No direct commits to `main`** — enforced by pre-commit hook (`no-commit-to-branch`).
- **Line endings**: LF only.

## Key Files

| File | Purpose |
|------|---------|
| `biomni/agent/a1.py` | Primary agent implementation |
| `biomni/utils.py` | Utilities (code execution, parsing, ~2400 lines) |
| `biomni/tool/database.py` | Database query tools (~200KB, largest module) |
| `biomni/config.py` | Configuration management |
| `biomni/llm.py` | Multi-provider LLM factory |
| `biomni/env_desc.py` | Data lake and environment descriptions |
| `CONTRIBUTION.md` | Contributing guidelines and tool addition process |

## Important Notes

- First run downloads an **~11GB datalake** to the `data/` directory.
- Code execution runs with **full system privileges** — the agent can execute arbitrary Python.
- The project uses **LangChain/LangGraph** extensively — agent state management, tool binding, and LLM calls all go through LangChain abstractions.
- Gradio version is pinned to `>=5.0,<6.0` due to breaking API changes across major versions.
- `biomni/version.py` holds the version string (currently 0.0.8).
