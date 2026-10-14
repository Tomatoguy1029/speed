## ステージ選択（仕様書 3・2.2）。開発版では全ステージを選べる（仕様書 20）。
## エンドレスモードの入口もここに置く（中身は未実装）。
extends UiScreen

func _ready() -> void:
	if OS.is_debug_build():
		var hint := Label.new()
		hint.text = tr("stage_select.debug")
		%Content.add_child(hint)
	for i in range(1, ConfigManager.stage_count() + 1):
		var def := ConfigManager.stage(i)
		var b := Button.new()
		b.custom_minimum_size = Vector2(420, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var unlocked := OS.is_debug_build() or SaveManager.is_stage_unlocked(i)
		b.text = tr("stage_select.stage").format({n = i, name = def.get_display_name()}) if unlocked else tr("stage_select.locked").format({n = i})
		b.disabled = not unlocked
		b.pressed.connect(_start.bind(i))
		%Content.add_child(b)
	var endless := Button.new()
	endless.custom_minimum_size = Vector2(420, 56)
	endless.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	endless.text = tr("stage_select.endless")
	endless.disabled = true
	%Content.add_child(endless)
	super()

func _start(stage: int) -> void:
	AudioManager.play(&"ui")
	GameManager.start_run(stage)
