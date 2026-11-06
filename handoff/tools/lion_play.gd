extends Node
# 検証用：本物のゲームをステージから始め、しし座を救出した状態にしてプレイヤーへ渡す（そのあとは何もしない）。
# 一時作業場所の project.godot に autoload として足して使う（本体には入れない）。
# 使い方：Godot --path <一時作業場所/speed> -- --lion-play [ステージ]
var stage := 2
var session: Node
var phase := 0
var wait := 0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--lion-play")
	if at < 0:
		set_process(false)
		return
	if at + 1 < args.size(): stage = int(args[at + 1])
	RunManager.session_created.connect(func(s): session = s)
	wait = 1.5

func _ui() -> Dictionary:
	if session == null or session.bridge == null: return {}
	var snapshot: Dictionary = session.bridge.latest_frame()
	return snapshot.value.get("ui", {}) if snapshot.ok and snapshot.value is Dictionary else {}

func _process(delta: float) -> void:
	if wait > 0.0:
		wait -= delta
		return
	match phase:
		0:
			GameManager.start_run(stage)
			phase = 1
		1:
			if not _ui().get("input_enabled", false): return
			session.bridge.command("dev_hero_place", {"id": "leo"})
			phase = 2
			wait = 0.3
		2:
			var hero: Dictionary = _ui().get("hero", {})
			if hero.is_empty(): return
			var links: PackedInt32Array = hero.links
			for i in range(0, links.size(), 2):
				session.bridge.command("dev_hero_pass", {"from": hero.stars[links[i]], "to": hero.stars[links[i + 1]], "dash": i})
			print("[lion] しし座を救出した。Q で発動")
			set_process(false)
