## 衝撃波は本体の戦闘状態から論理画素へ描く。
extends Node2D
@export var technique_id: StringName = &"horn_wave"
var retained := false
func apply_frame(_waves: Array, _clock: float) -> void: pass
func frame_event(_event: Dictionary) -> void: pass
func reset_frame() -> void: pass
