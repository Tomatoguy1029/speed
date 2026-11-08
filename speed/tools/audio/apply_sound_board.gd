## 音づけ表から取り込んだ値で音の表を上書きする。tools/audio/import_sound_board.py から呼ぶ。
## 合成音の設定は表に残し、素材のない欄でだけ使う。
extends SceneTree

const TABLE := "res://assets/audio/sound_table.tres"
const SoundTableScript = preload("res://scripts/data_types/sound_table.gd")
const SoundEntryScript = preload("res://scripts/data_types/sound_entry.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0])) if not args.is_empty() else null
	if not plan is Dictionary:
		push_error("取り込みの指示を読めません")
		quit(1)
		return
	var table: Resource = ResourceLoader.load(TABLE, "", ResourceLoader.CACHE_MODE_IGNORE) if ResourceLoader.exists(TABLE) else SoundTableScript.new()
	var entries := {}
	for row: Dictionary in plan.slots:
		var id := StringName(row.id)
		var entry: Resource = table.entries.get(id)
		if entry == null: entry = SoundEntryScript.new()
		var path: String = row.stream
		entry.stream = load(path) as AudioStream if path != "" else null
		if path != "" and entry.stream == null:
			push_error("音を読み込めません: %s %s" % [id, path])
			quit(1)
			return
		entry.volume_db = float(row.volume_db)
		entry.pitch_min = float(row.pitch_min)
		entry.pitch_max = maxf(float(row.pitch_min), float(row.pitch_max))
		entry.max_voices = int(row.max_voices)
		entry.loop = bool(row.loop)
		entry.trim_start = float(row.trim_start)
		entry.trim_end = float(row.trim_end)
		entry.loop_start = float(row.loop_start)
		var synth: Dictionary = row.get("synth", {})
		if entry.synth_wave == "" and not synth.is_empty():
			entry.synth_wave = synth.wave
			entry.synth_from_hz = float(synth.from_hz)
			entry.synth_to_hz = float(synth.to_hz)
			entry.synth_seconds = float(synth.seconds)
		entries[id] = entry
	table.entries = entries
	var error := ResourceSaver.save(table, TABLE)
	if error != OK: push_error("音の表を保存できません: %s" % error_string(error))
	quit(0 if error == OK else 1)
