## 出現タイムラインの対象テスト用。ゲームデータを保存せず、編集するプロパティだけ持つ。
@tool
extends Resource

@export var clips: Array[Resource] = []
@export var phases: Array[Resource] = []
@export var zako_curves: Array[Resource] = []
@export var track_names: PackedStringArray = []
@export var boss_enabled := false
@export var boss_time := -1.0
@export var time_limit := -1.0
