## ボス
## ステージの最後に出るボス。動きと攻撃はボスごとのシーンで作り、ここでは大きさ・強さ・攻撃の値を決める。
## ---
## 値の正は res://data/bosses/*.tres。
class_name BossDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 6

## 攻撃の値（params）の名前・説明・単位
const PARAMS_DOCS := {
	"fire_interval": ["撃つ間隔", "扇状の射撃を撃ってから次に撃つまでの時間。予告の長さはボスのシーンの攻撃の動き（volley）で決まる。", "世界秒"],
	"volley": ["一度に撃つ弾の数", "1回の射撃で扇状に撃つ弾の数。", "発"],
	"spread": ["扇の角度", "一度に撃つ弾を広げる角度。", "ラジアン"],
	"bullet_speed": ["弾の速さ", "撃った弾が飛ぶ速さ。", "単位/秒"],
	"bullet_dmg": ["弾のダメージ", "弾が当たったときのダメージ。", "HP"],
	"slow": ["当たったときの減速", "弾が当たったとき、機体の速さをこの割合だけ減らす。", "割合（0〜1）"],
}

## 半径
## 当たり判定と見た目の大きさ。
## 単位：単位（距離）
@export var radius: float
## HP（今は使っていない）
## 今は調整値の「ボスの HP」を使う。
## 単位：HP
@export var hp: float
## 装甲（今は使っていない）
## 今は調整値の「ボスの装甲」を使う。
## 単位：攻撃力
@export var armor: float
## 速さ
## 機体を追う速さ。
## 単位：単位/秒
@export var speed: float
## 加速
## 狙った速さに近づく強さ。
## 単位：毎秒の割合
@export var accel: float
## 向きを変える速さ
## 機体の方を向く速さ。
## 単位：ラジアン/秒
@export var turn: float
## 接触ダメージ
## 機体が触れたときに受けるダメージ。
## 単位：HP
@export var contact: float
## 経験値
## 倒したときに落とす経験値。
## 単位：経験値
@export var xp: float
## 背面の弱点の広さ
## 背面のこの角度（片側）に当てると必ずクリティカルになる。0 なら弱点なし。
## 単位：ラジアン
@export var weak_arc: float
## 攻撃の値
## 射撃の間隔や弾の数など。
## 単位：—
@export var params: Dictionary

## 見分けるための ID と、画面に出る名前・説明
@export_group("名前と ID")
## ID
## ボスを見分ける名前。ステージのデータがこの名前で指す。変えるとつながりが切れる。
## 単位：文字
@export var id: StringName
## 名前
## ボスの名前。
## 単位：文字
@export var display_name: String
## シーン
## ボスの動きと攻撃を作ったシーンのファイル。
## 単位：ファイル
@export var scene_path: String
