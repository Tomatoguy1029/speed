## ステージ
## ステージ選択で選ぶステージ。使う時間帯の並び、ボス、撃破でもらえる伝説のモジュールを決める。
## ---
## 値の正は res://data/stages/*.tres。
class_name StageDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 5

## 番号
## ステージの番号。前の番号のステージをクリアすると選べるようになる。
## 単位：番号
@export var index: int
## 名前
## ステージ選択に出る名前。
## 単位：文字
@export var display_name: String
## 配置のシーン
## ステージの配置を置いたシーンのファイル。
## 単位：ファイル
@export var scene_path: String
## 使う時間帯
## このステージで使う時間帯（開始時刻の順）。中身は「時間帯」で調整する。
## 単位：—
@export var phases: Array
## ボス
## このステージのボスの ID。
## 単位：文字
@export var boss_id: StringName
## もらえる伝説のモジュール
## ボスを倒すと手に入る伝説のモジュールの ID。空ならなし。
## 単位：文字
@export var legendary_module_id: StringName
