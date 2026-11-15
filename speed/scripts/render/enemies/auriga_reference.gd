## ぎょしゃ座の左右の轍を、寿命を持つ区間から連続した帯として描く。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const FX := preload("res://scripts/render/fx/fx_reference_primitives.gd")
var _raster := SpeedFxRaster.new()
var _settings: Dictionary = SETTINGS.for_id("G12-auriga")
## 炎の帯が燃えている間だけ鳴らすループの音
const FLAME_SOUND := &"elite.auriga.flame"
const FLAME_FADE := 0.3
var _flame: AudioStreamPlayer

func render(rows: Array, canvas, clock: float) -> void:
	_flame_sound(not rows.is_empty())
	var groups := {}
	for row: Dictionary in rows:
		var key := "%s/%s" % [row.owner_id, row.side]
		if not groups.has(key): groups[key] = []
		groups[key].append(row)
		var left := float(row.life) - float(row.age)
		var fade_time := 0.6 * float(_settings.timing)
		if left < fade_time:
			var middle: Vector2 = (row["from"] + row["to"]) * 0.5
			FX.sparks(canvas.front, canvas.to_logical(middle), fposmod(fade_time - left, 0.4), (clock - float(row.age)) * 7, 2, Color("ffe6b0"), 20, 0.4, -PI / 2.0, 0.8)
	if groups.is_empty(): return
	_raster.begin_painter(canvas.back, canvas.world_scale, canvas._camera_position, true, true)
	var flags := 0
	for group: Array in groups.values():
		group.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.order) < int(b.order))
		flags |= _draw_trail(group, canvas, clock)
	canvas.back.colors = _raster.take_colors()
	canvas.back.lights = _raster.take_lights()
	canvas.back.has_color = canvas.back.has_color or (flags & 1) != 0
	canvas.back.has_light = canvas.back.has_light or (flags & 2) != 0

func _draw_trail(rows: Array, canvas, clock: float) -> int:
	var points := PackedVector2Array()
	var strengths := PackedFloat64Array()
	var intensity := minf(1.0, float(_settings.intensity))
	for row: Dictionary in rows:
		var age := float(row.age)
		var left := float(row.life) - age
		if left <= 0.0: continue
		var k := minf(1.0, clampf(age / 0.12, 0.0, 1.0) * (0.3 + 0.7 * clampf(left / (0.6 * float(_settings.timing)), 0.0, 1.0))) * intensity
		if points.is_empty():
			points.append(canvas.to_logical(row["from"]))
			strengths.append(k)
		points.append(canvas.to_logical(row["to"]))
		strengths.append(k)
	var width: float = float(rows[0].width) * 0.5 * canvas.world_scale * float(_settings.size)
	return _raster.auriga_trail(points, strengths, width, PackedColorArray(FX.ramp(Color(_settings.color))), clock, canvas.back.fade, canvas.back.light_strength)

## 帯が1つでも残っている間は炎の音を繰り返し、すべて消えたら短く消す。
## 再生口は今の場面の下に置き、ランを抜けると一緒に消え、ポーズ中は止まる。
func _flame_sound(active: bool) -> void:
	if active:
		if _flame != null and is_instance_valid(_flame): return
		var stream := AudioManager.sound(FLAME_SOUND)
		var tree := Engine.get_main_loop() as SceneTree
		if stream == null or tree == null or tree.current_scene == null: return
		_flame = AudioStreamPlayer.new()
		_flame.bus = &"SFX"
		_flame.stream = stream
		_flame.volume_db = float(AudioManager.settings(FLAME_SOUND).get("volume_db", 0.0))
		_flame.pitch_scale = AudioManager.pitch(FLAME_SOUND)
		tree.current_scene.add_child(_flame)
		_flame.play()
	elif _flame != null:
		var player := _flame
		_flame = null
		if not is_instance_valid(player): return
		var tween := player.create_tween()
		tween.tween_property(player, "volume_db", -60.0, FLAME_FADE)
		tween.tween_callback(player.queue_free)
