import json
from pathlib import Path
import tempfile
import unittest
from combat_log_summary import summarize


class CombatSummaryTest(unittest.TestCase):
    def run_rows(self, rows, suffix="", **filters):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "log.jsonl"
            path.write_text("\n".join(json.dumps(row) for row in rows) + "\n" + suffix)
            return summarize(path, **filters)

    def test_legacy_unknown_rows_and_no_inferred_miss(self):
        data = self.run_rows([{"type": "start", "schema_version": 4}, {"type": "hurt", "amount": 9}, {"type": "future_unknown"}, {"type": "end"}])
        self.assertEqual(data["coverage"], "unavailable")
        self.assertEqual(data["observed_outcomes"], {})
        self.assertEqual(data["applied_damage"], {})

    def test_damage_counted_once_and_scopes_kept_separate(self):
        data = self.run_rows([
            {"type": "start", "combat_version": 1, "missing_prefix": False},
            {"type": "hurt", "amount": 50},
            {"type": "combat_damage", "sequence": 1, "target": "player", "applied": 30, "reason": "applied"},
            {"type": "boss_action", "sequence": 2, "boss": "draco", "action": "star_fan", "step": "completed", "outcome": "no_hit_observed"},
            {"type": "boss_effect", "sequence": 3, "boss": "draco", "action": "star_fan", "step": "end", "outcome": "hit"},
            {"type": "end", "combat_summary": {"rate_or_count_dropped": 0}},
        ])
        self.assertEqual(data["applied_damage"], {"player": 30})
        self.assertEqual(len(data["observed_outcomes"]), 2)
        self.assertEqual(data["coverage"], "recorded_interval")

    def test_truncated_or_dropped_records_are_partial(self):
        data = self.run_rows([{"type": "start", "combat_version": 1}, {"type": "boss_phase", "sequence": 3}], suffix='{"type":')
        self.assertEqual(data["coverage"], "partial")
        self.assertEqual(data["sequence_gaps"], 2)
        self.assertEqual(len(data["parse_errors"]), 1)
        self.assertFalse(data["has_end"])

    def test_filter_does_not_hide_global_loss(self):
        data = self.run_rows([{"type": "start", "combat_version": 1}, {"type": "boss_phase", "sequence": 1, "boss": "monoceros"}, {"type": "boss_phase", "sequence": 2, "boss": "draco"}, {"type": "end", "combat_summary": {"size_dropped": 2}}], boss="draco")
        self.assertEqual(data["events"], {"boss_phase": 1})
        self.assertEqual(data["sequence_gaps"], 0)
        self.assertEqual(data["coverage"], "partial")


if __name__ == "__main__":
    unittest.main()
