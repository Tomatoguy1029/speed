## 機体の強化
## 強化画面で部品を使って上げる、ランをまたいで残る強化。効果はラン開始時に反映される。
## ---
## 値の正は res://data/meta_upgrades/*.tres。
class_name MetaUpgradeDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 7

## 伸ばす能力
## max_speed（最高速度）、max_hp（最大 HP）、attack（攻撃力）、charge_time（ゲージの充填時間）、pickup（回収範囲）、xp（経験値）、reroll（3択のリロールの回数）、length（線の長さ）。
## 単位：文字
@export var stat: StringName
## 1段階ごとの効果
## 1段階ごとに伸ばす量。最大 HP とリロールの回数は足す量、ほかは割合（0.05 なら 5%）。充填時間は短くする割合。
## 単位：割合、HP、回
@export var per_level: float
## 段階ごとの費用
## 1段階目から順に、上げるのに必要な部品の数。数の個数が最大の段階になる。
## 単位：個（カンマ区切り）
@export var costs: PackedInt32Array

## 見分けるための ID
@export_group("ID")
## ID
## 強化を見分ける名前。セーブにこの名前で段階を保存する。変えると保存した段階が消える。
## 単位：文字
@export var id: StringName
## 並び順
## 強化画面で並べる順番（小さいほど上）。
## 単位：番号
@export var order: int

## 画面に出る名前と説明。編集元は docs/game/text.md。翻訳キーは strings.csv の meta.<ID>.name／.desc。
func get_display_name() -> String:
	return tr("meta.%s.name" % id)

func get_description() -> String:
	return tr("meta.%s.desc" % id)
