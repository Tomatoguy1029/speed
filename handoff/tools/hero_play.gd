extends Node
# 検証用：本物のゲームをステージから始め、英雄を救出した状態にしてプレイヤーへ渡す（そのあとは何もしない）。
# 武器選択の画面では 1 を押し、救出の演出などで操作できない間は3秒待ってから1秒おきに画面をクリックして閉じる。
# 一時作業場所の project.godot に autoload として足して使う（本体には入れない）。
# 使い方：Godot --path <一時作業場所/speed> -- --hero-play <gemini|hercules|leo|perseus> [ステージ] [持たせる武器,…]
var hero_id := ""
var stage := 3
var session: Node
var phase := 0
var wait := 1.5
var blocked := 0.0
var poke := 0.0
var weapons: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--hero-play")
	if at < 0 or at + 1 >= args.size():
		set_process(false)
		return
	hero_id = args[at + 1]
	if at + 2 < args.size(): stage = int(args[at + 2])
	if at + 3 < args.size(): weapons = Array(args[at + 3].split(","))
	RunManager.session_created.connect(func(s): session = s)

func _ui() -> Dictionary:
	if session == null or session.bridge == null: return {}
	var snapshot: Dictionary = session.bridge.latest_frame()
	return snapshot.value.get("ui", {}) if snapshot.ok and snapshot.value is Dictionary else {}

## 武器選択なら 1 を押し、操作できない間は3秒待ってから1秒おきにクリックする。操作できるようになったら true
func _clear_screens(delta: float) -> bool:
	var ui := _ui()
	if ui.is_empty(): return false
	poke -= delta
	if int(ui.get("phase", 0)) == 1:
		if poke <= 0.0:
			poke = 0.5
			for pressed in [true, false]:
				var key := InputEventKey.new()
				key.keycode = KEY_1
				key.physical_keycode = KEY_1
				key.pressed = pressed
				Input.parse_input_event(key)
		return false
	if ui.get("input_enabled", false):
		blocked = 0.0
		return true
	blocked += delta
	if blocked > 3.0 and poke <= 0.0:
		poke = 1.0
		var center := get_viewport().get_visible_rect().size * 0.5
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = center
			click.global_position = center
			click.pressed = pressed
			Input.parse_input_event(click)
	return false

func _process(delta: float) -> void:
	if wait > 0.0:
		wait -= delta
		return
	match phase:
		0:
			GameManager.start_run(stage)
			phase = 1
		1:
			if not _clear_screens(delta): return
			session.bridge.command("dev_hero_place", {"id": hero_id})
			phase = 2
			wait = 0.3
		2:
			var hero: Dictionary = _ui().get("hero", {})
			if hero.is_empty(): return
			var links: PackedInt32Array = hero.links
			for i in range(0, links.size(), 2):
				session.bridge.command("dev_hero_pass", {"from": hero.stars[links[i]], "to": hero.stars[links[i + 1]], "dash": i})
			phase = 3
			wait = 1.0
		3:
			if not _clear_screens(delta): return
			for id in weapons: session.bridge.command("dev_grant_equipment", {"id": id, "kind": "weapon", "levels": 3})
			print("[hero_play] %s を救出した。Q で発動" % hero_id)
			set_process(false)
