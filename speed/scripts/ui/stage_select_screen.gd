## ステージ選択（仕様書 3・2.1）。前のステージをクリアしないと次は選べない。
## エンドレスモードの入口もここに置く（中身は未実装）。
extends UiScreen

func _ready() -> void:
	for i in range(1, ConfigManager.stage_count() + 1):
		var def := ConfigManager.stage(i)
		var b := Button.new()
		b.custom_minimum_size = Vector2(420, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var unlocked := SaveManager.is_stage_unlocked(i)
		b.text = ("ステージ %d　%s" % [i, def.display_name]) if unlocked else ("ステージ %d　（前のステージをクリアすると選べる）" % i)
		b.disabled = not unlocked
		b.pressed.connect(_start.bind(i))
		%Content.add_child(b)
	var endless := Button.new()
	endless.custom_minimum_size = Vector2(420, 56)
	endless.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	endless.text = "エンドレス（準備中）"
	endless.disabled = true
	%Content.add_child(endless)
	super()

func _start(stage: int) -> void:
	AudioManager.play(&"ui")
	GameManager.start_run(stage)
