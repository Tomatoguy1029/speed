## ボス共通の技の編集元。実行コードと内部Timelineが同じ値を読む。
## 技のスクリプトはこれを継承し、使う値を @export で並べ、動きを Runner で返す。
@tool
extends Resource
class_name BossTechnique
@export var technique: StringName
@export var category: StringName = &"single"
## エディターとゲーム内に出す技の名前。空なら技IDを使う。
@export var display_name := ""
@export_range(0.0, 30.0, 0.05, "or_greater") var post_gap := 0.0
## 予告の間、自機を追って狙いと向きを更新する。OFFでは予告を始めた時の狙いへ撃つ。
## りゅう座は画面外からの配置を終えた最初の狙いで固定し、渦の中心移動は対象外。
@export var track_during_warn := true
## その技だけの予告の絵・エフェクト。必要な技だけ。
@export var visual: PackedScene
var _values := {}
var _values_dirty := true
## 継承した技のスクリプトが値として並べた名前。
var _field_cache: Array[String] = []

## 技の実行状態。Resourceを共有しても、再生ごとに新しいRunnerを作る。
class Runner extends RefCounted:
	func begin(_actor: BossActor) -> void: pass
	func windup(_actor: BossActor, _dt: float) -> void: pass
	func tick(_actor: BossActor, _dt: float) -> void: pass
	func end(_actor: BossActor, _cancelled: bool) -> void: pass
	func recover(_actor: BossActor, _dt: float) -> void: pass
	func pose(_actor: BossActor) -> void: pass

## エディターと実験場が使う @export の型・範囲・単位。
func field_property(name: String) -> Dictionary:
	for property in get_property_list():
		if String(property.name) == name: return property
	return {}

## 説明は編集時にスクリプトの ## から読む。戦闘中の値の取得では解析しない。
func field_description(name: String) -> String:
	var script: Script = get_script()
	var member := RegEx.new()
	member.compile("(?:^|\\s)var\\s+" + name + "(?:\\s|:|=|$)")
	while script != null and script != BossTechnique:
		var lines: Array[String] = []
		for source in script.source_code.split("\n"):
			if source.begins_with("##"):
				lines.append(source.trim_prefix("##").strip_edges())
			elif member.search(source) != null:
				return "\n".join(lines)
			elif not source.begins_with("@"):
				lines.clear()
		script = script.get_base_script()
	return ""

## 技の動きを1回分作る。技のスクリプトが Runner を返す。
func make_runner() -> RefCounted:
	return null

## 技のスクリプトで値を並べた技か。
func is_scripted() -> bool:
	return get_script() != BossTechnique

## 技のスクリプトで @export した値の名前。
func field_names() -> Array[String]:
	if _field_cache.is_empty():
		var shared := {}
		for property in BossTechnique.new().get_property_list(): shared[property.name] = true
		for property in get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_EDITOR and not shared.has(property.name) and property.name != "head_kind":
				_field_cache.append(String(property.name))
	return _field_cache

func has_field(name: String) -> bool:
	return name in field_names()

func field(name: String) -> Variant:
	return get(name)

func set_field(name: String, value: Variant) -> void:
	var current: Variant = get(name)
	if current is Array and value is Array:
		var typed: Array = current.duplicate()
		typed.assign(value)
		set(name, typed)
	else: set(name, value)
	_values_dirty = true
	emit_changed()

## 技の値をまとめた辞書。戦闘中に何度も読むので、値を変えるまで同じ辞書を返す。
func values() -> Dictionary:
	if _values_dirty:
		_values = {}
		for name in field_names(): _values[name] = get(name)
		_values_dirty = false
	return _values

## 辞書の値をまとめて入れる。持っていない名前は無視する。
func assign_values(value: Dictionary) -> void:
	for name in value:
		if has_field(String(name)): set_field(String(name), value[name])
	_values_dirty = true
	emit_changed()

func _validate_property(property: Dictionary) -> void:
	if property.name == "technique": property.usage |= PROPERTY_USAGE_READ_ONLY

func range_info(_values: Dictionary) -> Dictionary:
	return {"origin": "head", "max": INF}
