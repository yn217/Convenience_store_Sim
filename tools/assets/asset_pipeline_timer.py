from __future__ import annotations

import argparse
import hashlib
import json
import os
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def read_events(path: Path) -> list[dict]:
    if not path.exists():
        return []
    events = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            events.append(json.loads(line))
    return events


def append_event(path: Path, event: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(event, ensure_ascii=False, sort_keys=True) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Append lightweight asset pipeline phase timings as JSONL.")
    parser.add_argument("action", choices=("start", "finish"))
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--asset-id", default="")
    parser.add_argument("--task-id", default="")
    parser.add_argument("--agent-id", default=None)
    parser.add_argument("--phase", default="")
    parser.add_argument("--result", default="")
    parser.add_argument("--failure-reason", default="")
    parser.add_argument("--retry-count", type=int, default=0)
    parser.add_argument("--input-hash", default="")
    parser.add_argument("--output-hash", default="")
    parser.add_argument("--output-path", default="")
    parser.add_argument("--wait-reason", default="")
    parser.add_argument("--event-scope", default="")
    args = parser.parse_args()

    log = args.log.resolve()
    state_dir = log.with_name(log.name + ".active")
    state_dir.mkdir(parents=True, exist_ok=True)
    state = state_dir / (hashlib.sha256(args.run_id.encode("utf-8")).hexdigest() + ".json")
    if args.action == "start":
        if state.exists():
            parser.error(f"run_id already active: {args.run_id}")
        start_epoch = time.perf_counter_ns()
        event = {
            "event_id": str(uuid.uuid4()), "run_id": args.run_id, "asset_id": args.asset_id,
            "task_id": args.task_id, "agent_id": args.agent_id or "parent", "phase": args.phase,
            "event": "start", "timestamp_utc": utc_now(), "result": "started",
            "input_hash": args.input_hash, "wait_reason": args.wait_reason,
            "event_scope": args.event_scope,
        }
        append_event(log, event)
        active = {"event_id": event["event_id"], "asset_id": args.asset_id,
                               "task_id": args.task_id, "agent_id": event["agent_id"],
                               "phase": args.phase, "perf_counter_ns": start_epoch,
                               "started_at_utc": event["timestamp_utc"], "input_hash": args.input_hash,
                               "event_scope": args.event_scope}
        state.write_text(json.dumps(active, ensure_ascii=False, indent=2), encoding="utf-8")
        print(event["event_id"])
        return 0

    if not state.exists():
        parser.error(f"no active run_id: {args.run_id}")
    start = json.loads(state.read_text(encoding="utf-8"))
    duration_ms = round((time.perf_counter_ns() - start["perf_counter_ns"]) / 1_000_000, 3)
    event = {
        "event_id": start["event_id"], "run_id": args.run_id, "asset_id": args.asset_id or start["asset_id"],
        "task_id": args.task_id or start["task_id"], "agent_id": args.agent_id or start["agent_id"],
        "phase": args.phase or start["phase"], "event": "finish", "timestamp_utc": utc_now(),
        "duration_ms": duration_ms, "result": args.result or "completed",
        "failure_reason": args.failure_reason, "retry_count": args.retry_count,
        "input_hash": args.input_hash or start["input_hash"], "output_hash": args.output_hash,
        "output_path": args.output_path, "wait_reason": args.wait_reason,
        "event_scope": args.event_scope or start["event_scope"],
    }
    append_event(log, event)
    state.unlink(missing_ok=True)
    print(f"{duration_ms:.3f} ms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
