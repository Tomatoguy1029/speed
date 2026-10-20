## ステージ
## ステージ選択で選ぶステージ。使う時間帯の並び、ボス、撃破でもらえる伝説のモジュールを決める。
## ---
## 値の正は res://data/stages/*.tres。
class_name StageDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 5

## 番号
## ステージの番号。
## 単位：番号
@export var index: int
## 配置のシーン
## ステージの配置を置いたシーンのファイル。
## 単位：ファイル
@export var scene_path: String
## 使う時間帯
## このステージで使う時間帯（開始時刻の順）。中身は「時間帯」で調整する。
## 単位：—
@export var phases: Array
## ステージの敵
## このステージに出る敵の種類。出現のクリップは、この中から種類の組み合わせを選ぶ。
## 単位：type ID
@export var enemies: Array[StringName] = []
## 雑魚の目標の数
## 雑魚の種類ごとの、時刻ごとの目標の数の曲線。1つでもあれば、雑魚はこの曲線で補充し、時間帯の敵の数と重みは使わない。
## 単位：—
@export var zako_curves: Array[SpawnCurve] = []
## 出現のクリップ
## 強敵の出現。タイムラインに置き、開始から長さの間、選んだ種類の群れを出し続ける（ステージ全体の時刻で持つ）。
## 単位：—
@export var clips: Array[SpawnClip] = []
## トラックの名前
## 出現タイムラインの通常トラックの名前と行数（番号順。空の名前なら番号を表示する）。空の行も保持する。
## 単位：文字
@export var track_names: PackedStringArray
## ボスの出現時刻
## ラン開始からボスが出る時刻。負の値なら共通設定の時刻と幅を使う。
## 単位：実秒
@export var boss_time: float = -1.0
## ボスの出現を使う
## タイムラインのボスピンを配置するとオン、削除するとオフになる。
## 単位：オン／オフ
@export var boss_enabled: bool = true
## 強化帯の開始
## 敵の数・撃つ敵の割合・エリート確率を段階的に増やし始める時刻。負の値なら共通設定を使う。
## 単位：実秒
@export var surge_start: float = -1.0
## 強化帯の終了
## この時刻で強化の進行を止め、その時点の強さを保つ。負の値なら強化を続ける。
## 単位：実秒
@export var surge_end: float = -1.0
## 時間帯ごとの強化のON/OFF。未指定の時間帯は既存の強化帯を使う。タイムラインから編集する。
@export_storage var surge_phases: Dictionary = {}
## ステージの制限時間
## この時刻にランの time_limit_reached フラグを立てる。負の値なら制限時間を使わない。
## 単位：実秒
@export var time_limit: float = -1.0
## ボス
## このステージのボスの ID。
## 単位：文字
@export var boss_id: StringName
## もらえる伝説のモジュール
## ボスを倒すと手に入る伝説のモジュールの ID。空ならなし。
## 単位：文字
@export var legendary_module_id: StringName

## ステージ選択に出る名前。文章の正は res://data/text/strings.csv の stage.<番号>.name。
func get_display_name() -> String:
	return tr("stage.%d.name" % index)

## 敵の見た目
## このステージで、敵の絵を替える種類（type ID → 絵の名前。絵は res://assets/pixel/<絵の名前>.png）。
## 全ステージ共通の雑魚の見た目を、ステージごとに替えるのに使う。載っていない種類は type ID と同じ名前の絵。
## 単位：—
@export var enemy_looks: Dictionary = {}

## このステージでの、敵の種類 type の絵のファイル。
func enemy_sprite_path(type: StringName) -> String:
	return "res://assets/pixel/%s.png" % String(enemy_looks.get(String(type), type))

## 採用した実験の設定
## enabled を指定したステージと時間帯で使う攻撃枠・配置規則。
## 単位：設定
@export var encounter_profile: Dictionary = {}

func boss_start(cfg: GameConfig) -> float:
	return boss_time if boss_time >= 0.0 else cfg.boss_time

func surge_begin(cfg: GameConfig) -> float:
	return surge_start if surge_start >= 0.0 else cfg.surge_start

## 時間帯のON/OFFを反映した強化区間。隣り合う区間はつなげる。
func surge_windows(cfg: GameConfig) -> Array[Vector2]:
	var start := surge_begin(cfg)
	var end := maxf(start, surge_end) if surge_end >= 0.0 else INF
	var windows: Array[Vector2] = []
	if surge_phases.is_empty():
		windows.append(Vector2(start, end))
		return windows
	for k in phases.size():
		var phase: PhaseDef = phases[k]
		var finish: float = phases[k + 1].start if k + 1 < phases.size() else INF
		var key := String(phase.id)
		var from := maxf(phase.start, start)
		var to := minf(finish, end)
		if surge_phases.has(key):
			if not surge_phases[key]:
				continue
			from = phase.start
			to = finish
		var point_in_phase := start == end and start >= phase.start and start < finish
		if to < from or (to == from and not point_in_phase):
			continue
		if not windows.is_empty() and from <= windows[-1].y:
			windows[-1] = Vector2(windows[-1].x, maxf(windows[-1].y, to))
		else:
			windows.append(Vector2(from, to))
	return windows
