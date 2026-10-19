## 敵の組み合わせのシーンの、敵1体の置き場所（配置の子）。
## 位置と向きは、配置の中心と正面（y の負の向き）からの相対。向きの既定は配置の正面と同じ。
## エディターでは敵の絵を、正面へ向けて描く。
@tool
class_name FormationMarker
extends Node2D

## 敵の種類（type ID）
@export var enemy: StringName = &"":
	set(value):
		enemy = value
		_texture = null
		_radius = 0.0
		queue_redraw()

var _texture: Texture2D
var _radius := 0.0

func _validate_property(property: Dictionary) -> void:
	if property.name == "enemy":
		var ids := PackedStringArray()
		# 組み合わせのシーンに置ける種類が決まっていれば、その中から選ぶ
		var root := get_parent().get_parent() if get_parent() != null else null
		var allowed: Array = root.get("types") if root != null and root.get("types") != null else []
		if not allowed.is_empty():
			for t in allowed:
				ids.append(String(t))
		else:
			for f in DirAccess.get_files_at("res://data/enemies"):
				if f.ends_with(".tres"):
					ids.append(f.get_basename())
		ids.sort()
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(ids)

func _ready() -> void:
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		var root := get_parent().get_parent() if get_parent() != null else null
		if root is CanvasItem:
			(root as CanvasItem).queue_redraw()

## 敵の半径（敵の定義から読む。読めなければ仮の大きさ）。
func enemy_radius() -> float:
	if _radius <= 0.0:
		var path := "res://data/enemies/%s.tres" % enemy
		var def: Resource = load(path) if enemy != &"" and ResourceLoader.exists(path) else null
		_radius = float(def.get("radius")) if def != null else 20.0
	return _radius

## 敵の絵。
func enemy_texture() -> Texture2D:
	if _texture == null and enemy != &"":
		var path := "res://assets/pixel/%s.png" % enemy
		if ResourceLoader.exists(path):
			_texture = load(path)
	return _texture

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_enemy(self, Transform2D.IDENTITY, Color.WHITE)

## 敵の絵を、この置き場所の正面（y の負の向き）へ向けて描く。xf は描く先での置き場所の変換。
func draw_enemy(c: CanvasItem, xf: Transform2D, tint: Color) -> void:
	var r := enemy_radius()
	var tex := enemy_texture()
	c.draw_set_transform_matrix(xf)
	if tex == null:
		c.draw_circle(Vector2.ZERO, r, Color(tint, 0.5))
	else:
		var size := tex.get_size() / maxf(tex.get_width(), tex.get_height()) * r * 2.0
		# 絵の正面は下向き（一部の絵は上向き）なので、正面が y の負の向きになるように回す
		var native: bool = enemy in EnemyDef.NATIVE_SPRITES
		c.draw_set_transform_matrix(xf * Transform2D(0.0 if native else PI, Vector2.ZERO))
		c.draw_texture_rect(tex, Rect2(-size / 2.0, size), false, tint)
		c.draw_set_transform_matrix(xf)
	c.draw_line(Vector2.ZERO, Vector2(0, -r * 1.4), Color(1.0, 0.85, 0.3, tint.a), 2.0)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
