## 調整値と定義データを読み込んで持つ。Autoload（設計書 4.3・8.3）。
##
## 元の .tres（res://data/）は書き換えない。調整パネルは実行時の複製 `cfg` だけを書き換え、
## reset_runtime() で元の値に戻せる。武器・特性・敵などの定義はここから ID で引く。
extends Node

const CONFIG_PATH := "res://data/config.tres"

## 元の調整値（読み込んだまま）
var source_hashes: Dictionary = {}
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
var heroes: Dictionary = {}

func _ready() -> void:
	base = load(CONFIG_PATH) as GameConfig
	source_hashes[CONFIG_PATH] = FileAccess.get_sha256(CONFIG_PATH)
	reset_runtime()
	_load_dir("res://data/enemies", enemies, "id")
	_load_dir("res://data/phases", phases, "id")
	_load_dir("res://data/stages", stages, "index")
	_load_dir("res://data/bosses", bosses, "id")
	_load_dir("res://data/weapons", weapons, "id")
	_load_dir("res://data/traits", traits, "id")
	_load_dir("res://data/meta_upgrades", meta_upgrades, "id")
	_load_dir("res://data/legendary_modules", legendary_modules, "id")
	_load_dir("res://data/heroes", heroes, "id")

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
func _load_dir(dir_path: String, into: Dictionary, key: String, mode := ResourceLoader.CACHE_MODE_REUSE) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	var healthy := true
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := ResourceLoader.load(dir_path.path_join(name), "", mode)
		if res == null or res.get(key) == null:
			healthy = false
			push_warning("ConfigManager: %s を読めない" % name)
			continue
		into[res.get(key)] = res
		source_hashes[dir_path.path_join(name)] = FileAccess.get_sha256(dir_path.path_join(name))
	return healthy

## 調整した敵と出現・ボス・共通値を新しいリソースとして読む。既存ランの参照を変更しない。
func reload_experiment_data() -> bool:
	var fresh := ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameConfig
	if fresh == null: return false
	var registries := {"enemies": "id", "phases": "id", "stages": "index", "bosses": "id"}
	var loaded := {}
	var old_hashes := source_hashes.duplicate()
	for name in registries:
		var table := {}
		var healthy := _load_dir("res://data/" + name, table, registries[name], ResourceLoader.CACHE_MODE_IGNORE)
		if not healthy or table.is_empty():
			source_hashes = old_hashes
			return false
		loaded[name] = table
	for stage: StageDef in loaded.stages.values():
		var phase_list := []
		for phase: PhaseDef in stage.phases:
			# タイムラインで追加した時間帯はステージ内に保存し、その値を直接使う。
			if phase.resource_path.contains("::"):
				phase_list.append(phase)
				continue
			if not loaded.phases.has(phase.id):
				source_hashes = old_hashes
				return false
			phase_list.append(loaded.phases[phase.id])
		stage.phases = phase_list
	for name in registries: set(name, loaded[name])
	base = fresh
	reset_runtime()
	source_hashes[CONFIG_PATH] = FileAccess.get_sha256(CONFIG_PATH)
	return true
