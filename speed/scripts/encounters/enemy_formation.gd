## 敵の組み合わせのシーンの根。子に配置（FormationLayout）と出現位置（FormationEntry）を何種類か置く。
## シーンの原点に機体がいて、機体は上（y の負の向き）を向いている前提で作る。
## 出すときは、配置と出現位置を重みでランダムに1つずつ選び、配置の中心と正面を出現位置の点と向きにそろえ、
## 機体の向きに合わせて回してワールド座標に置く（EnemyManager.spawn_formation）。出たあとに隊列は保たない。
## エディターでは、機体・止まっているときの画面の枠・回しても画面に入らない目安の円を描き、
## preview_layout と preview_entry で選んだ組を、出現位置に重ねて薄く描く。円の内側に入る敵があれば警告する。
@tool
class_name EnemyFormation
extends Node2D

## 目安の円の、画面の対角線の半分に足す余白（先を見せる分のずれも含む）
const SAFE_MARGIN := 300.0
## 画面の縦横比（エディターの目安の枠に使う）
const ASPECT := 16.0 / 9.0

## 置ける敵の種類（空なら、どの種類でも置ける）。クリップの種類の組み合わせに合わせる
@export var types: Array[StringName] = []:
	set(value):
		types = value
		update_configuration_warnings()
## エディターで重ねて見る配置と出現位置の番号（-1 なら見せない）
@export var preview_layout := 0:
	set(value):
		preview_layout = value
		queue_redraw()
		update_configuration_warnings()
@export var preview_entry := 0:
	set(value):
		preview_entry = value
		queue_redraw()
		update_configuration_warnings()

func _ready() -> void:
	if Engine.is_editor_hint():
		child_order_changed.connect(queue_redraw)

## 止まっているときの画面の短い辺に映る距離（config.base_view）。
static func base_view() -> float:
	var cfg: Resource = load("res://data/config.tres")
	return float(cfg.get("base_view")) if cfg != null else 1100.0

## 回しても画面に入らない目安の円の半径。
static func safe_radius() -> float:
	var short := base_view()
	return Vector2(short * ASPECT, short).length() / 2.0 + SAFE_MARGIN

func layouts() -> Array[FormationLayout]:
	var out: Array[FormationLayout] = []
	for c in get_children():
		if c is FormationLayout:
			out.append(c)
	return out

func entries() -> Array[FormationEntry]:
	var out: Array[FormationEntry] = []
	for c in get_children():
		if c is FormationEntry:
			out.append(c)
	return out

## 配置の置き場所 m を、出現位置 e にそろえたときの、シーンの中での変換。
static func placed(e: FormationEntry, m: FormationMarker) -> Transform2D:
	return Transform2D(e.rotation, e.position) * Transform2D(m.rotation, m.position)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var short := base_view()
	var half := Vector2(short * ASPECT, short) / 2.0
	draw_rect(Rect2(-half, half * 2.0), Color(1, 1, 1, 0.35), false, 2.0)
	draw_arc(Vector2.ZERO, safe_radius(), 0.0, TAU, 96, Color(1.0, 0.45, 0.4, 0.6), 2.0)
	# 機体（上を向いている）
	draw_colored_polygon(PackedVector2Array([Vector2(0, -26), Vector2(16, 18), Vector2(0, 8), Vector2(-16, 18)]),
		Color(0.8, 0.95, 1.0, 0.9))
	var ls := layouts()
	var es := entries()
	if preview_layout < 0 or preview_layout >= ls.size() or preview_entry < 0 or preview_entry >= es.size():
		return
	var e := es[preview_entry]
	for m in ls[preview_layout].markers():
		var xf := placed(e, m)
		var inside := xf.origin.length() < safe_radius()
		m.draw_enemy(self, xf, Color(1.0, 0.4, 0.4, 0.8) if inside else Color(1, 1, 1, 0.55))

func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	var ls := layouts()
	var es := entries()
	if ls.is_empty():
		out.append("配置（FormationLayout）が1つもない")
	if es.is_empty():
		out.append("出現位置（FormationEntry）が1つもない")
	var r := safe_radius()
	for l in ls:
		for m in l.markers():
			if not types.is_empty() and m.enemy != &"" and not types.has(m.enemy):
				out.append("%s の %s（%s）は、置ける種類（types）にない" % [l.name, m.name, m.enemy])
		for e in es:
			for m in l.markers():
				if placed(e, m).origin.length() < r:
					out.append("%s を %s に置くと、%s が目安の円の内側に入る" % [l.name, e.name, m.name])
	return out

## ゲーム中に使う形に直す。{"layouts": [{"weight", "markers": [{"type", "pos", "rot"}]}], "entries": [{"weight", "pos", "rot"}]}
## 位置と向きは、配置は群れの中心と正面からの相対、出現位置は機体（上向き）からの相対。
func to_data() -> Dictionary:
	var ls := []
	for l in layouts():
		var ms := []
		for m in l.markers():
			if m.enemy != &"":
				ms.append({"type": m.enemy, "pos": m.position, "rot": m.rotation})
		if not ms.is_empty():
			ls.append({"weight": l.weight, "markers": ms})
	var es := []
	for e in entries():
		# 向きは、エディターで開いていないシーンでも機体を向くように、位置から求める
		es.append({"weight": e.weight, "pos": e.position, "rot": FormationEntry.facing_origin(e.position)})
	return {"layouts": ls, "entries": es}
