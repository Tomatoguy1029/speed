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

    def test_cpp_envelopes_and_player_hp_loss(self):
        data = self.run_rows([
            {"type": "header", "format": "cpp_events_v1", "during_run": False},
            {"type": "xp_drop", "sequence": 8, "payload": {"base_xp": 2}},
            {"type": "hurt", "sequence": 9, "payload": {"amount": 100}},
            {"type": "combat_player_damage", "sequence": 10, "payload": {"hp_before": 30, "hp_after": 28, "amount": 100, "reason": "applied", "cause": "rain"}},
            {"type": "combat_player_damage", "sequence": 11, "payload": {"hp_before": 28, "hp_after": 28, "reason": "shield"}},
            {"type": "end"},
        ])
        self.assertEqual(data["applied_damage"], {"player": 2})
        self.assertEqual(data["sequence_gaps"], 0)
        self.assertEqual(data["damage_reasons"], {"player:applied": 1, "player:shield": 1})

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

    def test_cpp_missing_transport_is_partial_without_visible_sequence_gap(self):
        for loss in [{"transport_complete": False}, {"effect_tracking_dropped": 2}]:
            with self.subTest(loss=loss):
                data = self.run_rows([
                    {"type": "start", "format": "cpp_events_v2", "combat_version": 1,
                     "combat_config": {"level": 2}, "event_sequence_at_start": 20},
                    {"type": "boss_action", "sequence": 21},
                    {"type": "end", "combat_summary": loss},
                ])
                self.assertEqual(data["sequence_gaps"], 0)
                self.assertEqual(data["coverage"], "partial")

    def test_cpp_disabled_diagnostics_keep_normal_damage_outside_limits(self):
        data = self.run_rows([
            {"type": "start", "format": "cpp_events_v2", "combat_version": 1,
             "combat_config": {"level": 0}, "event_sequence_at_start": 8},
            {"type": "hurt", "sequence": 9, "amount": 2},
            {"type": "combat_player_damage", "sequence": 10, "hp_before": 8, "hp_after": 6},
            {"type": "end", "combat_summary": {"transport_complete": True}},
        ])
        self.assertEqual(data["coverage"], "disabled")
        self.assertEqual(data["applied_damage"], {"player": 2})


if __name__ == "__main__":
    unittest.main()
