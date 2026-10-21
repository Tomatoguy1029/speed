## 出現のクリップ
## ステージのタイムラインに置く、強敵の出現。開始から長さの間だけ働き、その間、選んだ種類の組み合わせの群れを出し続ける。
## 群れは、フォーメーション（敵の組み合わせのシーン）からランダムに1つ選び、その配置（使う並び）と出現位置をランダムに1つずつ選んで出す。
## ---
## 値の正は res://data/stages/*.tres の clips。
@tool
class_name SpawnClip
extends Resource

## ラベル
## タイムラインに出す名前（作り手用）。
## 単位：文字
@export var label: String
## トラック
## タイムラインで置く行の番号（0 から）。-1 なら、クリップの並びの番号の行に置く。出し方には関係しない。
## 単位：番号
@export var track: int = -1
## 種類の組み合わせ
## このクリップが出す敵の種類。ステージの敵の一覧から選ぶ。フォーメーションには、ここで選んだ種類だけを置ける。
## 単位：type ID
@export var types: Array[StringName] = []
## フォーメーション
## 群れの形（res://data/formations/*.tscn）。出すたびにランダムに1つ選ぶ。
## 単位：シーン
@export var formations: Array[PackedScene] = []
## 使う並び
## フォーメーションの配置のうち、このクリップで使うもの（「フォーメーションのファイル名/配置のノード名」）。
## 選んだ並びが1つもないフォーメーションは使わない。空なら、すべての並びを使う。
## 単位：並びの名前
@export var layouts: Array[StringName] = []
## 並びごとの共有override。「シーンのファイル名/並びのノード名」→正の小数。
## 保存済みの整数も共有overrideとして読む。キーがなければ個体ごとの自動計算。
@export var formation_values: Dictionary = {}
## 攻撃優先度
## このクリップから出る敵の攻撃待ちの優先度（0〜5の整数）。大きいほど先。同じ値は同率で、待ち時間で公平に順番を決める。
## 初期値・保存項目のないクリップは0。0も明示設定としてステージの種類別優先度より優先する。
## 部位・分裂体・増援も引き継ぐ。
@export_range(0, 5, 1) var attack_priority: int = 0

## 開始の時刻
## ラン開始からこの時刻に、このクリップが働き始める。
## 単位：実秒
@export_storage var time: float
## 長さ
## 開始からこの時間だけ働く。
## 単位：実秒
@export_storage var length: float = 60.0
## 同時の群れの数
## 働いている間、このクリップから出た群れがフィールドにいてほしい数。足りなければ出す。
## 単位：群れ
@export var groups: int = 1
## 出す間隔
## このクリップから群れを出してから、次の群れを出すまでの最短の時間。
## 単位：実秒
@export var interval: float = 10.0

## 同じ並びから1回で出た群れ全体の共有override。未設定は -1（個体ごと）。
func formation_value(scene_path: String, layout_name: String) -> float:
	var key := String(layout_key(scene_path, layout_name))
	if not formation_values.has(key):
		return -1.0
	var value := float(formation_values[key])
	return value if is_finite(value) and value > 0.0 else 1.0

## 実際に出す種類だけを数えた、指定配置の個体valueの合計。選択の有無はUIで別表示する。
func automatic_value(stage: StageDef, layout: Dictionary) -> float:
	var total := 0.0
	for marker: Dictionary in layout.get("markers", []):
		var type := StringName(marker.type)
		if not types.is_empty() and not types.has(type):
			continue
		total += stage.enemy_attack_value(type) if stage != null else 1.0
	return total

## 終わりの時刻。
func end_time() -> float:
	return time + length

## フォーメーション scene の配置 layout_name を指す、使う並びの名前。
static func layout_key(scene_path: String, layout_name: String) -> StringName:
	return StringName(scene_path.get_file().get_basename() + "/" + layout_name)

## フォーメーション scene の、ゲーム中に使う形 data のうち、このクリップで使う配置の番号。
func allowed_layouts(scene_path: String, data: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var ls: Array = data.get("layouts", [])
	for k in ls.size():
		if layouts.is_empty() or layouts.has(layout_key(scene_path, str(ls[k].get("name", "")))):
			out.append(k)
	return out
