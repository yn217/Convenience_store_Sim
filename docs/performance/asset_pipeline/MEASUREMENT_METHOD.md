# アセットパイプライン計測方法

## 既存証拠の扱い

- ImageGen tool eventの`started_at_ms`と`completed_at_ms`差を**tool event elapsed**とする。内部GPU推論、待ち行列、保存時間を分離しない。
- command/process durationはそのコマンド境界だけを記録。Godot起動＋capture混在を分解しない。
- Git commit、ファイル作成時刻、コメント間隔は履歴タイムスタンプであり作業時間ではない。
- agent turn durationはactive workではない。start/end両方を記録できた場合もwall intervalと明記。

## 次回からの必須項目

`run_id, asset_id, task_id, agent_id, phase, event(start|finish), timestamp_utc, duration_ms, result, failure_reason, retry_count, input_hash, output_hash, output_path, wait_reason`。開始・終了は同じIDに紐付ける。並列タスクは個別durationの合計とwall makespanを別にする。active_timeは人/agentが意識的に作業した区間の記録がある場合だけ報告する。

## Logger

`tools/assets/asset_pipeline_timer.py` writes JSONL. Commands:

```powershell
python tools/assets/asset_pipeline_timer.py start --log build/asset-timing/runs.jsonl --run-id shelf-open-empty-r0 --asset-id shelf_general --task-id issue-157 --agent-id parent --phase image_generation
python tools/assets/asset_pipeline_timer.py finish --log build/asset-timing/runs.jsonl --run-id shelf-open-empty-r0 --result generated --output-path assets/source/fixtures/shelf_general/open_empty_r0.png
```

Start stores UTC timestamp and epoch nanoseconds in a per-run state file beside the log. Because `start` and `finish` are separate CLI processes, elapsed wall duration is derived from epoch time; this is cross-process compatible but can be affected by a system clock adjustment. For a same-process benchmark, prefer Python `perf_counter` instead. Keep `build/asset-timing/` out of Git unless sanitized as an approved measurement artifact. For tool calls whose start/finish are external, log immediately before and after and label `event_scope=tool_call`; do not claim internal inference time. Do not put secrets or full prompts in general logs; save prompt file reference/hash instead.

## Resource sampling

Optional before/after samples: CPU, RAM, GPU/VRAM and disk I/O, with timestamp and sampling source. Do not poll at high frequency unless studying resource contention. Record resolution, output format, tool/model version and settings.

## QA and tests

Record each image QA, Godot boot, capture and targeted test as separate phases. No full-suite run is required. Follow project instruction: avoid excessive full testing. Never infer a test duration from assertion counts.
