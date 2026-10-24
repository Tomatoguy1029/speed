## 共通フローの接続確認用。ゲーム中の別ボスの挙動は変更しない。
extends RefCounted
var started: Array = []
var remaining := 0.0
var time := 0.0
var last_kick := -100.0
func advance(dt: float) -> void:
	time += dt
	remaining = maxf(0.0, remaining - dt)
func blocked() -> bool: return false
func running() -> bool: return remaining > 0.0
func candidates(query: Dictionary) -> Dictionary:
	var distance: float = Vector2(query.get("player", Vector2.ZERO)).length()
	var result: Array = []
	if distance <= 250.0: result.append({"id": "strike", "cost": 1.0, "parts": [0], "category": "single"})
	if distance <= 160.0 and time - last_kick >= 6.0: result.append({"id": "kick", "cost": 1.0, "parts": [0], "category": "single"})
	return {"candidates": result, "reason": "射程・再使用待ち"}
func start(actions: Array) -> bool:
	if running() or actions.size() != 1: return false
	started.append(actions[0].id)
	if actions[0].id == "kick": last_kick = time
	remaining = 1.0
	return true
