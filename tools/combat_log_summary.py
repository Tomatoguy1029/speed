#!/usr/bin/env python3
"""Summarize SPEED JSONL without inferring unobserved attacks or double-counting hurt rows."""
import argparse
from collections import Counter
import json
from pathlib import Path

COMBAT_TYPES = {"boss_decision", "boss_action", "boss_effect", "boss_phase", "combat_damage"}


def summarize(path, boss=None, action=None, timeline=False):
    counts, reasons, outcomes = Counter(), Counter(), Counter()
    applied, damage_reasons = Counter(), Counter()
    start, end, errors, trace = {}, {}, [], []
    sequence, sequence_gaps, combat_rows = None, 0, 0
    with Path(path).open(encoding="utf-8") as stream:
        for number, line in enumerate(stream, 1):
            try:
                row = json.loads(line)
                if not isinstance(row, dict):
                    raise ValueError("expected object")
            except (ValueError, json.JSONDecodeError) as error:
                errors.append({"line": number, "error": str(error)[:100]})
                continue
            kind = row.get("type", "unknown")
            if kind == "start":
                start = row
            if kind == "end":
                end = row
            if kind not in COMBAT_TYPES:
                continue
            combat_rows += 1
            current = row.get("sequence")
            if isinstance(current, int):
                sequence_gaps += max(0, current - (sequence or 0) - 1)
                sequence = current
            if boss and row.get("boss") != boss:
                continue
            if action and row.get("action") != action and action not in row.get("selected", []):
                continue
            counts[kind] += 1
            if kind == "boss_decision":
                for candidate in row.get("candidates", []):
                    for reason in candidate.get("reasons", []):
                        reasons[f"{candidate.get('id', '?')}:{reason}"] += 1
            if kind in {"boss_action", "boss_effect"} and "outcome" in row:
                # Keep interrupted, incomplete, and detached effect scopes separate.
                key = f"{kind}/{row.get('boss', '?')}/{row.get('action', '?')}/{row.get('step', '?')}:{row['outcome']}"
                outcomes[key] += 1
            if kind == "combat_damage":
                target = row.get("target", "unknown")
                applied[target] += row.get("applied", 0)
                damage_reasons[f"{target}:{row.get('reason', 'unknown')}"] += 1
            if timeline:
                fields = ("t", "world_t", "sequence", "type", "boss", "body_id", "phase", "decision_id", "action_id", "action", "origin", "step", "reason", "selected", "candidates", "aim", "player_pos", "outcome", "effect_id", "applied")
                trace.append({key: row[key] for key in fields if key in row})
    loss = end.get("combat_summary", {})
    available = start.get("combat_version") == 1 or combat_rows > 0
    return {
        "file": str(path), "schema_version": start.get("schema_version"),
        "combat_available": available, "configured_level": start.get("combat_config", {}).get("level"),
        "run_id": start.get("run_id"), "stage": start.get("stage"),
        "missing_prefix": start.get("missing_prefix", None), "has_end": bool(end),
        "sequence_gaps": sequence_gaps, "loss": loss, "parse_errors": errors,
        "coverage": "unavailable" if not available else "disabled" if start.get("combat_config", {}).get("level") == 0 and not combat_rows else "partial" if not end or start.get("missing_prefix") or errors or sequence_gaps or loss.get("rate_or_count_dropped", 0) or loss.get("size_dropped", 0) else "recorded_interval",
        "events": dict(counts), "candidate_rejections": dict(reasons),
        "observed_outcomes": dict(outcomes), "applied_damage": dict(applied), "damage_reasons": dict(damage_reasons),
        **({"timeline": trace} if timeline else {}),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logs", nargs="+", type=Path)
    parser.add_argument("--boss", help="e.g. monoceros or draco")
    parser.add_argument("--action", help="e.g. charge")
    parser.add_argument("--timeline", action="store_true", help="include decisions, aim and outcome rows")
    parser.add_argument("--json", action="store_true", help="machine-readable summaries")
    args = parser.parse_args()
    summaries = [summarize(path, args.boss, args.action, args.timeline) for path in args.logs]
    if args.json:
        print(json.dumps(summaries, ensure_ascii=False, indent=2))
    else:
        for summary in summaries:
            print(f"{summary['file']}: stage={summary['stage']} coverage={summary['coverage']} level={summary['configured_level']}")
            if not summary["combat_available"]:
                print("  This recording has no combat diagnostics; outcomes remain unknown.")
            for key in ("events", "candidate_rejections", "observed_outcomes", "applied_damage", "damage_reasons", "loss"):
                if summary[key]:
                    print(f"  {key}: {json.dumps(summary[key], ensure_ascii=False, sort_keys=True)}")
            for row in summary.get("timeline", []):
                print(json.dumps(row, ensure_ascii=False))
            if summary["parse_errors"]:
                print(f"  parse_errors: {summary['parse_errors']}")
    return int(any(s["parse_errors"] for s in summaries))


if __name__ == "__main__":
    raise SystemExit(main())
