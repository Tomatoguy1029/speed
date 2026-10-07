## 調整値と定義データを読み込んで持つ。Autoload（設計書 4.3・8.3）。
##
## 元の .tres（res://data/）は書き換えない。調整パネルは実行時の複製 `cfg` だけを書き換え、
## reset_runtime() で元の値に戻せる。武器・特性・敵などの定義はここから ID で引く。
extends Node

const CONFIG_PATH := "res://data/config.tres"

## 元の調整値（読み込んだまま）
var base: GameConfig
## 実行時に使う調整値（調整パネルが書き換える）
var cfg: GameConfig

var enemies: Dictionary = {}
var phases: Dictionary = {}
var stages: Dictionary = {}
var bosses: Dictionary = {}
var weapons: Dictionary = {}
var traits: Dictionary = {}
var meta_upgrades: Dictionary = {}
var legendary_modules: Dictionary = {}

func _ready() -> void:
	base = load(CONFIG_PATH) as GameConfig
	reset_runtime()
	_load_dir("res://data/enemies", enemies, "id")
	_load_dir("res://data/phases", phases, "id")
	_load_dir("res://data/stages", stages, "index")
	_load_dir("res://data/bosses", bosses, "id")
	_load_dir("res://data/weapons", weapons, "id")
	_load_dir("res://data/traits", traits, "id")
	_load_dir("res://data/meta_upgrades", meta_upgrades, "id")
	_load_dir("res://data/legendary_modules", legendary_modules, "id")

## 調整値を .tres の値に戻す。
func reset_runtime() -> void:
	cfg = base.duplicate() as GameConfig

## ステージの数。
func stage_count() -> int:
	return stages.size()

## ステージの定義。なければ null。
func stage(index: int) -> StageDef:
	return stages.get(index) as StageDef

## order（または id）の順に並べた定義の一覧。
func sorted(table: Dictionary) -> Array:
	var list := table.values()
	list.sort_custom(func(a, b): return _order_key(a) < _order_key(b))
	return list

func _order_key(def: Resource) -> String:
	if "order" in def and def.order > 0:
		return "%04d" % def.order
	return String(def.id)

## フォルダ内の .tres を読み、key の値で引けるようにする。
## 書き出したゲームでは .tres が .tres.remap になっているので、その末尾を外して読む。
func _load_dir(dir_path: String, into: Dictionary, key: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := load(dir_path.path_join(name))
		if res == null:
			push_warning("ConfigManager: %s を読めない" % name)
			continue
		into[res.get(key)] = res
