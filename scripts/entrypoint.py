#!/usr/bin/env python
"""Container entrypoint — starts Gradio UI and FastAPI API server in parallel."""

import json
import multiprocessing
import os
import sys


def start_gradio(agent_kwargs: dict):
    """Launch Gradio demo in its own process with a dedicated A1 instance."""
    from biomni.agent import A1

    agent = A1(**agent_kwargs)
    agent.launch_gradio_demo(server_name="0.0.0.0")


def start_api(agent_kwargs: dict):
    """Launch the FastAPI server in its own process."""
    import uvicorn

    os.environ["BIOMNI_AGENT_KWARGS"] = json.dumps(agent_kwargs)
    uvicorn.run("scripts.api_server:app", host="0.0.0.0", port=8000)


def main():
    data_path = os.environ.get("BIOMNI_DATA_PATH", "/mnt/data")
    data_lake_dir = os.path.join(data_path, "biomni_data", "data_lake")

    if not os.path.isdir(data_lake_dir):
        print(
            f"ERROR: Data lake not found at {data_lake_dir}. "
            "Ensure the EBS volume is mounted at BIOMNI_DATA_PATH.",
            file=sys.stderr,
        )
        sys.exit(1)

    # expected_data_lake_files=[] tells A1.__init__ to skip the S3 download
    # (the data is already on the EBS volume).
    kwargs = {"path": data_path, "expected_data_lake_files": []}

    gradio_proc = multiprocessing.Process(target=start_gradio, args=(kwargs,), name="gradio")
    api_proc = multiprocessing.Process(target=start_api, args=(kwargs,), name="api")

    gradio_proc.start()
    api_proc.start()

    # If either process dies, exit the container so ECS restarts the task.
    gradio_proc.join()
    api_proc.join()

    exit_code = gradio_proc.exitcode or api_proc.exitcode or 0
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
