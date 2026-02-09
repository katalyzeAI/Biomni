# AWS Deployment Research — Biomni on ECS Fargate

## Decision Record

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Compute | ECS Fargate | Serverless containers, no EC2 management |
| Interface | Gradio web UI (port 7860) + FastAPI API (port 8000) | Gradio for interactive use, FastAPI for programmatic access |
| Data lake | EBS volume from snapshot | Fast mount, no download at startup, read-only fits ephemeral model |
| IaC | Terraform | Industry standard, good state management |
| API approach | FastAPI wrapper | LangServe not viable (A1 not a Runnable), LangGraph Platform needs upgrade. FastAPI+uvicorn already installed. |

## Codebase Investigation Findings

### Data Lake Download Mechanism

**Location:** `biomni/agent/a1.py:155-194`

The `A1.__init__` constructor has a `expected_data_lake_files` parameter:
- `None` (default): downloads all 76 files from `https://biomni-release.s3.amazonaws.com/data_lake/` + benchmark.zip
- Any non-None value (e.g., `[]`): **skips all downloads** (line 163)

After download/skip, `self.path` is set to `{path}/biomni_data` (line 194).

**Directory structure expected:**
```
{BIOMNI_DATA_PATH}/
└── biomni_data/
    ├── data_lake/       # 76 files (parquet, csv, pkl, json, obo, txt, tsv)
    └── benchmark/
        └── hle/         # Presence of this dir = benchmark is complete (line 178)
```

### Gradio Launch API

**Location:** `biomni/agent/a1.py:2627`

```python
def launch_gradio_demo(self, thread_id=42, share=False, server_name="0.0.0.0", require_verification=False):
```

- `server_name="0.0.0.0"` is the default — already correct for container deployment
- `require_verification=True` adds an access code (good for internet-facing deployment)
- Uses WebSockets for streaming — ALB idle timeout must be high

### Docker Image

**Base:** `continuumio/miniconda3:24.11.1-0`
**Size:** ~30GB (full E1 environment with conda, R, CLI tools)
**Ports:** 7860 (Gradio), 8888 (Jupyter — not needed)
**Entrypoint:** Custom script that activates `biomni_e1` conda env then executes command

### AWS SDK Already in Dependencies

From `biomni_env/bio_env.yml`:
- `boto3`, `botocore` — AWS SDK
- `s3fs==2025.7.0` — S3 filesystem access
- `aiobotocore` — Async AWS SDK

These are already installed in the Docker image, no additional packages needed.

### Configuration Environment Variables

From `biomni/config.py`:
- `BIOMNI_DATA_PATH` / `BIOMNI_PATH` — data directory override
- `BIOMNI_LLM` / `BIOMNI_LLM_MODEL` — model selection
- `BIOMNI_TIMEOUT_SECONDS` — execution timeout
- `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` — LLM API keys

## EBS on Fargate — Technical Details

ECS Fargate EBS volume support (launched Jan 2024):
- Volumes are **ephemeral** — created from snapshot at task launch, deleted when task stops
- Requires `configuredAtLaunch: true` in task definition volumes
- Requires an ECS infrastructure IAM role with `AmazonECSInfrastructureRolePolicyForVolumes`
- Max 200 GiB by default
- Supports gp3, io1, io2 volume types
- Filesystem: ext4 or xfs

For a 15 GiB read-only data lake, gp3 is the right choice (cheapest, adequate IOPS).

## Cold Start Analysis

| Phase | Duration | Notes |
|-------|----------|-------|
| EBS creation from snapshot | 15-30s | gp3, 15 GiB |
| Fargate provisioning | 30-60s | ENI, SG |
| Image pull | 2-5 min | ~30GB from ECR |
| Container start | 10-20s | conda activate |
| A1 init + tool registry | 30-60s | Heavy imports |
| Gradio ready | 5-10s | Server binding |
| **Total** | **3-7 min** | Set health check grace period ≥300s |

## Cost Breakdown (us-east-1)

### Always-on (24/7)
- Fargate 8 vCPU: 8 × $0.04048/hr × 730 = $236
- Fargate 32 GB: 32 × $0.004445/hr × 730 = $104
- Fargate ephemeral 20 GiB overage: 20 × $0.000111/hr × 730 = $1.62
- NAT Gateway: $32 fixed + ~$5 data = $37
- ALB: $22 fixed + ~$6 LCU = $28
- ECR 30GB: $3
- EBS snapshot 15 GiB: $0.75
- Secrets Manager (2): $0.80
- **Total: ~$470/month**

### Business hours only (12h/day, 5d/week ≈ 260h)
- Fargate: (236+104) × 260/730 = $121
- Fixed costs remain: $37 + $28 + $3 + $0.75 + $0.80 = $70
- **Total: ~$191/month**

## Data Lake File Inventory (76 files)

Source: `biomni/env_desc.py:2-79`

Full list of files that must be on the EBS snapshot:
- 6 protein interaction files (affinity_capture, co-fractionation, proximity_label, reconstituted_complex, two-hybrid)
- 4 DepMap files (CRISPRGeneDependency, CRISPRGeneEffect, Model, OmicsExpression)
- 8 DDInter drug interaction files
- 8 EveBio screening files
- 10 MSigDB gene set files
- 6 MouseMine gene set files
- 3 miRTarBase + 1 miRDB files
- 3 GeneBass variant files
- 2 sgRNA files
- Various individual files (DisGeNET, GO, GTEx, GWAS, HPO, KG, etc.)
- 2 TXGNN files

Plus the `benchmark/` folder (downloaded as ZIP, contains `hle/` subdirectory).

## API Exposure Investigation

### Why Not LangServe
The A1 class does NOT implement the LangChain `Runnable` interface — no `invoke()` or `ainvoke()` methods. LangServe requires a Runnable. Also, LangServe is being deprecated in favor of LangGraph Platform.

### Why Not LangGraph Platform
Current langgraph version is 0.3.18. LangGraph Server/Platform requires 0.4+. Would need a version upgrade and repackaging.

### FastAPI Approach (Chosen)
- `fastapi==0.116.1` and `uvicorn==0.35.0` already installed in the environment
- Wrap `go(prompt)` → POST /api/invoke (returns `{"result": str, "steps": list}`)
- Wrap `go_stream(prompt)` → POST /api/stream (SSE stream yielding `{"output": str}` per step)
- GET /api/health for ALB health checks

### Concurrency Constraint
A1 agent is **stateful**: `go()` mutates `self.log`, `self._conversation_state`, uses hardcoded `thread_id=42`. Must serialize with `asyncio.Lock` or run separate process per interface. The entrypoint uses `multiprocessing` to give Gradio and FastAPI each their own agent instance.

### ALB Routing
Path-based routing on the single ALB:
- `/api/*` → target group on port 8000 (FastAPI)
- `/*` (default) → target group on port 7860 (Gradio)
