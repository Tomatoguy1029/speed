## 角・蹄の予告と、連続突進・薙ぎ・乱舞の仮表示。体のパーツは本体の表示が描く。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var technique_id: StringName
@export var pixel_size := 3.0
var _frame: Array = []
const WARNING := Color("#f2b567")
const ENERGY := Color("#9fe8ff")
@export_range(0.5, 16.0, 0.25) var telegraph_line_width := 6.0
@export_range(0.5, 16.0, 0.25) var locked_line_width := 7.0
@export_range(0.0, 1.0, 0.05) var warning_opacity := 0.3
@export_range(0.25, 3.0, 0.05) var jet_radius_scale := 1.0
@export_range(0.0, 1.0, 0.05) var jet_opacity := 0.35
func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)
func apply_frame(values: Array) -> void:
	if values==_frame: return
	_frame = values
	queue_redraw()

func _draw_frame() -> void:
	for row: Dictionary in _frame:
		if row.get("technique","") not in ["charge","kick","sweep","lance","return_charge"]: continue
		if row.get("technique","")=="sweep":
			if row.stage==0 and row.get("sequence_stage",-1)==1:
				var forward := Vector2.from_angle(float(row.facing))
				var at: Vector2 = row.position+forward*float(row.radius)*0.65
				var k: float = row.stop_progress
				for j in 3:
					var offset := forward*float(j)*8.0+forward.orthogonal()*float(j-1)*8.0
					draw_circle(at+offset,lerpf(10.0,24.0,k)*jet_radius_scale,Color(ENERGY,jet_opacity*(1.0-k)))
			continue
		if row.stage==0 and row.get("technique","")=="kick":
			draw_line(row.horn[0],row.horn[1],Color(WARNING,warning_opacity),float(row.width),false)
			draw_line(row.horn[0],row.horn[1],WARNING,locked_line_width,false)
			if row.locked: draw_rect(Rect2(row.horn[1]-Vector2(6,6),Vector2(12,12)),WARNING)
		elif row.stage==0 and row.get("technique","") not in ["charge","return_charge"]:
			draw_line(row.horn[0],row.warning[1],Color(WARNING,warning_opacity),telegraph_line_width,false)
		elif row.stage==3:
			var at: Vector2 = row.horn[1]
			for j in 3:
				draw_line(at+Vector2(-15,j*10-10),at+Vector2(15,j*10-10),WARNING,pixel_size,false)

func _draw() -> void:
	_draw_frame()
