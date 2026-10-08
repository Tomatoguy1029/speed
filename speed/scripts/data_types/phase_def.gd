## 時間帯
## ランの時間を区切った区間ごとの、敵の数・強さ・種類の出方。名前は作り手用で、ゲーム画面には出さない。
## 敵の数とレベルは、区間の開始の値から終了の値へ時間とともに変わる。
## ---
## 値の正は res://data/phases/*.tres。どのステージがどの時間帯を使うかはステージのデータで決める。
class_name PhaseDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 4

## 開始の時刻
## ラン開始からこの時刻に、この時間帯が始まる。
## 単位：実秒
@export var start: float
## 終了の時刻
## この時刻に、この時間帯が終わる。
## 単位：実秒
@export var end: float
## 敵の数（開始時）
## 時間帯の始めに、フィールドにいてほしい敵の数。調整値の「敵の密度倍率」が掛かる。
## 単位：体
@export var pop_from: float
## 敵の数（終了時）
## 時間帯の終わりに、フィールドにいてほしい敵の数。
## 単位：体
@export var pop_to: float
## 敵のレベル（開始時）
## 時間帯の始めに出る敵のレベル。
## 単位：レベル
@export var level_from: float
## 敵のレベル（終了時）
## 時間帯の終わりに出る敵のレベル。
## 単位：レベル
@export var level_to: float
## 補充の速さ
## 敵が足りないとき、1秒に補充する数。調整値の「敵の密度倍率」が掛かる。
## 単位：体/秒
@export var rate: float
## 経験値の倍率
## この時間帯に倒した敵の経験値に掛ける。0 は 1 倍として扱う。
## 単位：倍
@export var xp_bonus: float
## 群れの間隔
## この間隔ごとに、スウォームの群れをまとめて出す。0 なら出さない。
## 単位：実秒
@export var wave_interval: float
## 出力コアを出す
## オンにすると、この時間帯にフィールドの中心付近へ出力コアが出る。
## 単位：オン／オフ
@export var cores: bool
## 出現の重み
## 敵の種類ごとの出やすさ。大きいほどよく出る（全体に対する比で決まる）。
## 単位：重み
@export var mix: Dictionary

## 見分けるための ID と、画面に出る名前・説明
@export_group("名前と ID")
## ID
## 時間帯を見分ける名前。ステージのデータがこの時間帯を指すのに使う。
## 単位：文字
@export var id: StringName
## 名前
## 作り手用の名前。ゲーム画面には出さない。
## 単位：文字
@export var display_name: String
