"""Biomni FastAPI REST API wrapping the A1 agent."""

import asyncio
import json
import os

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

app = FastAPI(
    title="Biomni API",
    description="REST API for the Biomni biomedical AI agent",
    version="0.0.8",
)

# Agent instance — initialized at startup
_agent = None
_agent_lock = asyncio.Lock()


class InvokeRequest(BaseModel):
    prompt: str


class InvokeResponse(BaseModel):
    result: str
    steps: list[str]


def _get_agent():
    """Lazily initialize the A1 agent on first request."""
    global _agent
    if _agent is not None:
        return _agent

    from biomni.agent import A1

    kwargs_json = os.environ.get("BIOMNI_AGENT_KWARGS", "{}")
    kwargs = json.loads(kwargs_json)
    _agent = A1(**kwargs)
    return _agent


@app.get("/api/health")
async def health():
    return {
        "status": "ok",
        "model": os.environ.get("BIOMNI_LLM", "unknown"),
    }


@app.post("/api/invoke", response_model=InvokeResponse)
async def invoke(req: InvokeRequest):
    """Run the agent synchronously and return the final result."""
    agent = _get_agent()
    try:
        async with _agent_lock:
            log, result = await asyncio.to_thread(agent.go, req.prompt)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return InvokeResponse(result=result, steps=log)


@app.post("/api/stream")
async def stream(req: InvokeRequest):
    """Stream agent execution steps as Server-Sent Events."""
    agent = _get_agent()

    async def event_generator():
        try:
            async with _agent_lock:
                for step in await asyncio.to_thread(
                    lambda: list(agent.go_stream(req.prompt))
                ):
                    yield f"data: {json.dumps(step)}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as exc:
            yield f"data: {json.dumps({'error': str(exc)})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")
