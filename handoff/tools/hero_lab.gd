extends Node
# 検証用：通常のランを通さず、敵・ルート実験場を開いて英雄の力を選び、試遊の状態にして渡す（武器選択や救出の画面を出さない）。
# 一時作業場所の project.godot に autoload として足して使う（本体には入れない）。
# 使い方：Godot --path <一時作業場所/speed> res://gyms/enemy_lab/enemy_lab.tscn -- --hero-lab <gemini|hercules|leo|perseus>
# 実験場のシーンを直接開く（タイトル画面を通らない）
var hero_id := ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--hero-lab")
	if at < 0 or at + 1 >= args.size():
		set_process(false)
		return
	hero_id = args[at + 1]

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not ("session" in scene) or scene.session == null or not is_instance_valid(scene.session.run): return
	scene.session.perform("hero", {"id": hero_id})
	scene._set_mode(3)
	print("[hero_lab] %s を選んだ試遊。Q で発動" % hero_id)
	set_process(false)
