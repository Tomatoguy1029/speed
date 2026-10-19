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
## 出現のクリップ
## 強敵の出現。タイムラインに置き、開始から長さの間、選んだ種類の群れを出し続ける（ステージ全体の時刻で持つ）。
## 単位：—
@export var clips: Array[SpawnClip] = []
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
