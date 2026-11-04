## 槍の表示は本体と同じ姿勢・戦闘時計から描く。
extends Node2D
@export var technique_id: StringName = &"lance"
var retained := false
func apply_frame(_rows: Array, _clock: float) -> void: pass
func frame_event(_event: Dictionary) -> void: pass
func reset_frame() -> void: pass
