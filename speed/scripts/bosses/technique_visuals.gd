## ボスが所有する技の見た目。シーンを再利用し、進行と同じ時刻でアニメーションを合わせる。
extends RefCounted
var actor: BossActor
var nodes := {}
var selected: StringName
var _body_revision := -1

func configure(owner_actor: BossActor, moves: Dictionary) -> void:
	clear()
	actor = owner_actor
	for id in moves:
		var scene: PackedScene = moves[id].visual
		if scene == null: continue
		var node := scene.instantiate() as Node2D
		if node == null: continue
		node.set_meta("visual_profile", "boss/move/%s/%s" % [actor.def.id, id])
		actor.add_child(node)
		if "actor" in node: node.actor = actor
		if "visual_kind" in node: node.visual_kind = node.technique_id
		if "technique_id" in node: node.technique_id = StringName(id)
		# 独自の_readyを持つ専用表示も、同じ所有元の設定を初期化する。
		preload("res://data/visuals/effect_settings.tres").apply_to(node)
		node.visible = false
		nodes[id] = node

func sync(id: StringName, phase: StringName, elapsed: float, duration: float) -> void:
	var settings := preload("res://data/visuals/effect_settings.tres")
	if selected != id or _body_revision != settings.preview_revision:
		var body := actor.get("_presentation") as CanvasItem
		if body != null:
			settings.apply_body(body, String(actor.def.id), String(id))
			_body_revision = settings.preview_revision
	selected = id
	for key in nodes:
		var node: Node2D = nodes[key]
		node.visible = key == id or ("retained" in node and node.retained)
		if not node.visible: continue
		if node.has_method("update_technique"): node.update_technique()
		var player := node.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var sample: Dictionary = node.phase_state() if node.has_method("phase_state") else {}
		var stage: StringName = sample.get("phase", phase)
		var stage_elapsed: float = sample.get("elapsed", elapsed)
		var stage_duration: float = sample.get("duration", duration)
		var animation: StringName = &"recover" if stage == &"recovery" else stage
		if (key == id or not sample.is_empty()) and player != null and player.has_animation(animation):
			if player.current_animation != animation: player.play(animation)
			player.seek(player.get_animation(animation).length * clampf(stage_elapsed / maxf(0.001, stage_duration), 0.0, 1.0), true)
			player.pause()
		node.queue_redraw()

func event(value: Dictionary) -> void:
	for node: Node2D in nodes.values():
		if node.has_method("on_event"): node.on_event(value)

func clear() -> void:
	for node: Node2D in nodes.values():
		if is_instance_valid(node): node.queue_free()
	nodes.clear()
	selected = &""
	_body_revision = -1
