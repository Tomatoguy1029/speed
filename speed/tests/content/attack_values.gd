## 個体・共有overrideの会計、小数、整数保存の互換読み込み、表示用合計だけを確認する。
## godot --headless --path speed res://tests/content/attack_values.tscn
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS

var failed := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)

func _ready() -> void:
	var stage := StageDef.new()
	stage.enemy_attack_values = {"telescope": 1.0, "reticle": 0.5, "aquarius": 4.0}
	var clip := SpawnClip.new()
	var data := {"layouts": [{"name": "pair", "weight": 1.0, "markers": [
		{"type": &"telescope", "pos": Vector2.ZERO, "rot": 0.0},
		{"type": &"reticle", "pos": Vector2(100, 0), "rot": 0.0}]}],
		"entries": [{"weight": 1.0, "pos": Vector2(0, -1500), "rot": 0.0}]}
	check(is_equal_approx(clip.automatic_value(stage, data.layouts[0]), 1.5), "Auto sums actual marker types including fractional costs")
	clip.types = [&"reticle"]
	check(is_equal_approx(clip.automatic_value(stage, data.layouts[0]), 0.5), "Auto respects clip type filter")
	stage.enemy_attack_values.reticle = 1.5
	check(is_equal_approx(clip.automatic_value(stage, data.layouts[0]), 1.5), "Auto refresh reads changed stage values")
	stage.enemy_attack_values.reticle = 0.5
	clip.types.clear()
	stage.enemy_attack_values.telescope = 0.0
	stage.enemy_attack_values.reticle = 0.0
	check(stage.enemy_attack_value(&"telescope") == 0.0 and clip.automatic_value(stage, data.layouts[0]) == 0.0,
		"Zero type values reach Auto without a compatibility fallback")
	stage.enemy_attack_values.reticle = 1e-18
	check(stage.enemy_attack_value(&"reticle") == 1e-18 and clip.automatic_value(stage, data.layouts[0]) == 1e-18,
		"Auto preserves a deliberate tiny positive value")
	stage.enemy_attack_values.reticle = -0.5
	check(stage.enemy_attack_value(&"reticle") == 1.0, "Negative type value keeps compatibility fallback")
	stage.enemy_attack_values.reticle = INF
	check(stage.enemy_attack_value(&"reticle") == 1.0, "Nonfinite type value keeps compatibility fallback")
	stage.enemy_attack_values = {"telescope": 1.0, "reticle": 0.5}
	clip.formation_values = {"fixture/pair": 3}
	const SAVE := "/tmp/speed-attack-values-fixture.tres"
	check(ResourceSaver.save(clip, SAVE) == OK, "Legacy integer fixture saves")
	var loaded: SpawnClip = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.formation_value("fixture.tscn", "pair") == 3.0 and loaded.formation_values["fixture/pair"] is int, "Legacy integer is preserved as explicit shared override")
	check(loaded.formation_value("fixture.tscn", "other") < 0.0, "Missing override uses individual accounting")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	clip.formation_values = {"fixture/pair": 0.0}
	check(ResourceSaver.save(clip, SAVE) == OK, "Zero shared override saves")
	loaded = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.formation_value("fixture.tscn", "pair") == 0.0,
		"Zero shared override reopens as zero")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	clip.formation_values = {"fixture/pair": 1e-18}
	check(clip.formation_value("fixture.tscn", "pair") == 1e-18,
		"Tiny positive shared override remains positive")
	clip.formation_values = {"fixture/pair": -0.5}
	check(clip.formation_value("fixture.tscn", "pair") == 1.0,
		"Negative shared override keeps compatibility fallback")
	clip.formation_values = {"fixture/pair": INF}
	check(clip.formation_value("fixture.tscn", "pair") == 1.0,
		"Nonfinite shared override keeps compatibility fallback")
	var scene: PackedScene = load("res://data/formations/telescope_reticle.tscn")
	var source_layout: Dictionary = load("res://tools/content/build_runtime_stage.gd").formation(scene).layouts[0]
	var prepared_clip := SpawnClip.new()
	prepared_clip.formations = [scene]
	prepared_clip.formation_values = {String(SpawnClip.layout_key(scene.resource_path, str(source_layout.name))): 0.0}
	var prepared = load("res://tools/content/build_runtime_stage.gd").clip(prepared_clip)
	check(prepared.prepared.size() == 1 and prepared.prepared[0].layouts[0].value == 0.0,
		"Build-time RuntimeClip keeps a zero shared override")
	check(not prepared.prepared[0].layouts[0].attack_managed, "共有value 0は生成時に管理対象外と確定する")
	print("[attack_values] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
