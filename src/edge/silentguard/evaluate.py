from __future__ import annotations

import argparse
import csv
import json
import statistics
from collections.abc import Iterable
from dataclasses import asdict
from itertools import product
from pathlib import Path
from typing import Any

from .config import EdgeConfig, FallConfig, load_config
from .engine import PoseFallEngine
from .state_machine import FallStateMachine
from .types import PoseObservation


def load_manifest(path: str | Path) -> list[dict[str, Any]]:
    manifest_path = Path(path).resolve()
    rows: list[dict[str, Any]] = []
    with manifest_path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            video_path = Path(row["path"])
            if not video_path.is_absolute():
                video_path = (manifest_path.parent / video_path).resolve()
            label = row.get("label", "normal").strip().lower()
            if label not in {"fall", "normal"}:
                raise ValueError(f"Unsupported label {label!r} for {video_path}")
            fall_at = row.get("fall_at_sec", "").strip()
            rows.append(
                {
                    "path": str(video_path),
                    "label": label,
                    "fall_at_sec": float(fall_at) if fall_at else None,
                    "notes": row.get("notes", "").strip(),
                }
            )
    if not rows:
        raise ValueError("Evaluation manifest is empty")
    return rows


def collect_observations(config: EdgeConfig, manifest: list[dict[str, Any]]) -> dict[str, Any]:
    engine = PoseFallEngine(config)
    clips: list[dict[str, Any]] = []
    for item in manifest:
        result = engine.process_video(item["path"], keep_diagnostics=True)
        clips.append(
            {
                **item,
                "frames": result.frames,
                "duration_sec": result.duration_sec,
                "inference_ms": result.inference_ms,
                "observation_frames": [
                    {
                        "frame_index": diagnostic.frame_index,
                        "timestamp": diagnostic.timestamp,
                        "observations": [observation.to_dict() for observation in diagnostic.observations],
                    }
                    for diagnostic in result.diagnostics
                    if diagnostic.observations
                ],
            }
        )
    return {
        "model": asdict(config.model),
        "fall": asdict(config.fall),
        "clips": clips,
    }


def replay_clip(clip: dict[str, Any], fall_config: FallConfig) -> list[dict[str, Any]]:
    machine = FallStateMachine(fall_config)
    incidents: list[dict[str, Any]] = []
    for frame in clip.get("observation_frames", []):
        timestamp = float(frame["timestamp"])
        for item in frame.get("observations", []):
            incident = machine.update(PoseObservation.from_dict(item))
            if incident is not None:
                incidents.append(
                    {
                        "event_id": incident.event_id,
                        "track_id": incident.track_id,
                        "detected_at": incident.detected_at,
                        "confidence": incident.confidence,
                    }
                )
        machine.expire(timestamp)
    return incidents


def calculate_metrics(cache: dict[str, Any], fall_config: FallConfig) -> dict[str, Any]:
    tp = fp = tn = fn = duplicates = 0
    time_to_detect: list[float] = []
    all_inference: list[float] = []
    pose_frames = total_frames = 0
    clip_results: list[dict[str, Any]] = []

    for clip in cache["clips"]:
        incidents = replay_clip(clip, fall_config)
        predicted = bool(incidents)
        expected = clip["label"] == "fall"
        if expected and predicted:
            tp += 1
        elif expected:
            fn += 1
        elif predicted:
            fp += 1
        else:
            tn += 1
        duplicates += max(0, len(incidents) - 1)
        if expected and incidents and clip.get("fall_at_sec") is not None:
            time_to_detect.append(max(0.0, incidents[0]["detected_at"] - float(clip["fall_at_sec"])))
        all_inference.extend(float(value) for value in clip.get("inference_ms", []))
        pose_frames += len(clip.get("observation_frames", []))
        total_frames += int(clip.get("frames", 0))
        clip_results.append(
            {
                "path": clip["path"],
                "label": clip["label"],
                "predicted": "fall" if predicted else "normal",
                "incidents": incidents,
                "passed": predicted == expected and len(incidents) <= 1,
            }
        )

    precision = tp / (tp + fp) if tp + fp else 0.0
    recall = tp / (tp + fn) if tp + fn else 0.0
    beta = 1.5
    fbeta = (
        (1 + beta**2) * precision * recall / (beta**2 * precision + recall)
        if precision and recall
        else 0.0
    )
    timings = sorted(all_inference)
    p95_index = max(0, min(len(timings) - 1, int(len(timings) * 0.95) - 1)) if timings else 0
    mean_ms = statistics.fmean(timings) if timings else 0.0
    return {
        "summary": {
            "tp": tp,
            "fp": fp,
            "tn": tn,
            "fn": fn,
            "precision": round(precision, 4),
            "recall": round(recall, 4),
            "f_beta_1_5": round(fbeta, 4),
            "duplicate_alerts": duplicates,
            "mean_time_to_detect_sec": round(statistics.fmean(time_to_detect), 3) if time_to_detect else None,
            "p95_time_to_detect_sec": round(_percentile(time_to_detect, 0.95), 3) if time_to_detect else None,
            "pose_availability": round(pose_frames / total_frames, 4) if total_frames else 0.0,
            "mean_inference_ms": round(mean_ms, 3),
            "p95_inference_ms": round(timings[p95_index], 3) if timings else 0.0,
            "effective_inference_fps": round(1000 / mean_ms, 3) if mean_ms else 0.0,
        },
        "fall_config": asdict(fall_config),
        "clips": clip_results,
    }


def sweep_thresholds(cache: dict[str, Any], base: FallConfig) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    velocity_values = sorted({round(base.descending_velocity_bh_s * factor, 3) for factor in (0.75, 1.0, 1.25)})
    angle_values = sorted({max(35.0, min(70.0, base.lying_torso_angle_deg + delta)) for delta in (-5, 0, 5)})
    confirmation_values = sorted({max(0.5, base.lying_confirmation_sec + delta) for delta in (-0.25, 0, 0.25)})
    for velocity, angle, confirmation in product(velocity_values, angle_values, confirmation_values):
        values = asdict(base)
        values.update(
            descending_velocity_bh_s=velocity,
            lying_torso_angle_deg=angle,
            lying_confirmation_sec=confirmation,
        )
        config = FallConfig(**values)
        report = calculate_metrics(cache, config)
        summary = report["summary"]
        candidates.append({"fall_config": asdict(config), "summary": summary})
    candidates.sort(
        key=lambda item: (
            item["summary"]["duplicate_alerts"] == 0,
            item["summary"]["f_beta_1_5"],
            item["summary"]["precision"],
            item["summary"]["recall"],
        ),
        reverse=True,
    )
    return candidates


def _percentile(values: Iterable[float], fraction: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    return ordered[max(0, min(len(ordered) - 1, int(len(ordered) * fraction) - 1))]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate SilentGuard Fall Engine V2")
    parser.add_argument("--config", default="showcase.yaml")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--cache", default="reports/observations.json")
    parser.add_argument("--report", default="reports/evaluation.json")
    parser.add_argument("--reuse-cache", action="store_true")
    parser.add_argument("--sweep", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    cache_path = Path(args.cache)
    if args.reuse_cache:
        cache = json.loads(cache_path.read_text(encoding="utf-8"))
    else:
        cache = collect_observations(config, load_manifest(args.manifest))
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(cache, indent=2), encoding="utf-8")

    report = calculate_metrics(cache, config.fall)
    if args.sweep:
        report["threshold_sweep_top_10"] = sweep_thresholds(cache, config.fall)[:10]
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report["summary"], indent=2))
    print(f"Report: {report_path}")


if __name__ == "__main__":
    main()
