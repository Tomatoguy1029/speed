## ボスが所有する技の見た目。シーンを再利用し、進行と同じ時刻でアニメーションを合わせる。
extends RefCounted
var actor: BossActor
var nodes := {}
var selected: StringName

func configure(owner_actor: BossActor, moves: Dictionary) -> void:
	clear()
	actor = owner_actor
	for id in moves:
		var scene: PackedScene = moves[id].visual
		if scene == null: continue
		var node := scene.instantiate() as Node2D
		if node == null: continue
		actor.add_child(node)
		if "actor" in node: node.actor = actor
		node.visible = false
		nodes[id] = node

func sync(id: StringName, phase: StringName, elapsed: float, duration: float) -> void:
	selected = id
	for key in nodes:
		var node: Node2D = nodes[key]
		node.visible = key == id or ("retained" in node and node.retained)
		if not node.visible: continue
		if node.has_method("update_technique"): node.update_technique()
		var player := node.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var animation: StringName = &"recover" if phase == &"recovery" else phase
		if key == id and player != null and player.has_animation(animation):
			if player.current_animation != animation: player.play(animation)
			player.seek(player.get_animation(animation).length * clampf(elapsed / maxf(0.001, duration), 0.0, 1.0), true)
			player.pause()
		node.queue_redraw()

func event(value: Dictionary) -> void:
	for node: Node2D in nodes.values():
		if node.has_method("on_event"): node.on_event(value)

func clear() -> void:
	for node: Node2D in nodes.values():
		if is_instance_valid(node): node.queue_free()
	nodes.clear()
