## ボス
## ステージの最後に出るボス。動きと攻撃はボスごとのシーンで作り、ここでは大きさ・強さ・攻撃の値を決める。
## ---
## 値の正は res://data/bosses/*.tres。
class_name BossDef
extends Resource

## データ編集の画面での並び順
const EDITOR_ORDER := 6

## 表示パーツの塗装色と元の配置からの位置補正。戦闘判定とは独立する。
@export var part_appearance: Dictionary = {}

static func valid_part_appearance(value) -> bool:
	if not value is Dictionary or value.size() > 128: return false
	for key in value:
		if not key is String or key.length() > 160 or not value[key] is Dictionary: return false
		for field in value[key]:
			var entry = value[key][field]
			if field == "color":
				if not entry is String or entry.length() != 6 or not Color.html_is_valid(entry): return false
			elif field == "offset":
				if not entry is Array or entry.size() != 2: return false
				for number in entry:
					if typeof(number) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(number)) or absf(float(number)) > 256: return false
			else: return false
	return true

## 攻撃の値（params）の名前・説明・単位
const PARAMS_DOCS := {
	"fire_interval": ["撃つ間隔", "扇状の射撃を撃ってから次に撃つまでの時間。予告の長さはボスのシーンの攻撃の動き（volley）で決まる。", "世界秒"],
	"volley": ["一度に撃つ弾の数", "1回の射撃で扇状に撃つ弾の数。", "発"],
	"spread": ["扇の角度", "一度に撃つ弾を広げる角度。", "ラジアン"],
	"bullet_speed": ["弾の速さ", "撃った弾が飛ぶ速さ。", "単位/秒"],
	"bullet_dmg": ["弾のダメージ", "弾が当たったときのダメージ。", "HP"],
	"slow": ["当たったときの減速", "弾が当たったとき、機体の速さをこの割合だけ減らす。", "割合（0〜1）"],
	"engage": ["近づき始める距離", "うみへび座：機体がこれより離れると、機体の方へ泳いで近づく。", "単位（距離）"],
	"neck_rest": ["首の長さ", "うみへび座：普段の首の長さ（本体の縁から頭まで）。", "単位（距離）"],
	"neck_segments": ["首の節数", "うみへび座：首1本を分割する数。増やすと曲線が滑らかになり、計算量が増える。", "節（4〜32）"],
	"neck_iterations": ["首の補正回数", "うみへび座：1更新で節長を補正する往復の上限。増やすと長さの誤差が減り、計算量が増える。", "回（1〜12）"],
	"neck_slack": ["首の余長", "うみへび座：通常の全長に掛ける倍率。余った長さを曲がりに使い、頭を遠くへ出すと首全体を伸ばす。", "倍率（1以上）"],
	"neck_wave_amplitude": ["首のうねりの幅", "うみへび座：骨組みを横方向へ曲げる波の振幅。伸びきるほど弱まる。", "単位（距離）"],
	"neck_wave_frequency": ["首のうねりの数", "うみへび座：首の全長に入る波の数。", "波"],
	"neck_wave_speed": ["首のうねりの速さ", "うみへび座：世界秒で進む波の位相の速さ。", "ラジアン/世界秒"],
	"neck_response": ["首の追従の強さ", "うみへび座：骨組みが曲がりの目標へ近づく強さ。", "毎世界秒"],
	"head_hp": ["頭の HP", "うみへび座：頭1つの HP（調整値の「敵の HP 倍率」も掛かる）。", "HP"],
	"regrow": ["再生の基本猶予", "うみへび座：次の頭を倒すまでの基本猶予。残り首数の猶予を加え、倒すたびに倒れた全首へ延長する。", "世界秒"],
	"regrow_per_head": ["残り首ごとの猶予", "うみへび座：生きている首1本ごとに基本猶予へ加える時間。", "世界秒"],
	"north_reach": ["集中噛みつきの到達距離", "うみへび座：北の大技で各根元から届く最大距離。標的位置と予告を同じ距離で制限する。", "単位（距離）"],
	"north_spread": ["集中噛みつきの広がり", "うみへび座：標的位置を狙う首の左右に、ほかの首の到達点を広げる半幅。", "単位（距離）"],
	"regrow_combo": ["まとめて落としたときの遅れ", "うみへび座：1本の線でまとめて落とした頭が1本増えるごとに、生え直す時間がこの割合だけ延びる。", "割合"],
	"expose_time": ["不死の首がむき出しの時間", "うみへび座：普段の頭が全部落ちてから、不死の首がむき出しになっている時間。", "世界秒"],
	"debris_dmg": ["首の残骸の破片のダメージ", "うみへび座：頭を落としたときに飛ぶ破片が、敵に与えるダメージ。", "HP"],
	"attack_cd": ["首の攻撃の間隔", "うみへび座：首ごとの攻撃の間隔の目安。", "世界秒"],
	"bite_reach": ["噛みつきの届く長さ", "うみへび座：噛みつく首が伸びきったときの首の長さ。", "単位（距離）"],
	"bite_radius": ["噛みつきの範囲", "うみへび座：噛みついた所の当たりの半径。", "単位（距離）"],
	"bite_dmg": ["噛みつきのダメージ", "うみへび座：噛みつきのダメージ。不死の首の衝撃はこの 0.6 倍。", "HP"],
	"vortex_radius": ["渦の大きさ", "うみへび座：渦の首が置く渦の、置いたときの半径。", "単位（距離）"],
	"vortex_life": ["渦の時間", "うみへび座：渦が縮んで消えるまでの時間。", "世界秒"],
	"vortex_pull": ["渦の強さ", "うみへび座：渦の中心の引き寄せる加速。", "単位/秒²"],
	"rubble_count": ["瓦礫の数", "うみへび座：瓦礫の首が1回に吐く瓦礫の数。", "個"],
	"lump_speed": ["塊の速さ", "うみへび座：瓦礫の塊を投げる速さ。", "単位/秒"],
	"lump_r": ["塊の大きさ", "うみへび座：瓦礫の塊の半径。", "単位（距離）"],
	"lump_dmg": ["塊のダメージ", "うみへび座：瓦礫の塊のダメージ。", "HP"],
	"beam_len": ["ビームの長さ", "うみへび座：ビームの首のビームの長さ。", "単位（距離）"],
	"beam_dmg": ["ビームのダメージ", "うみへび座：太いビームのダメージ。細いビームはこの 0.7 倍。", "HP"],
	"missile_speed": ["ホーミング弾の速さ", "うみへび座：ホーミング弾の首のホーミング弾の速さ。", "単位/秒"],
	"missile_dmg": ["ホーミング弾のダメージ", "うみへび座：ホーミング弾と、輪の弾のダメージ。", "HP"],
	"ring_speed": ["輪の弾の速さ", "うみへび座：浮かべた輪の弾を放つ速さ。", "単位/秒"],
	"shock_radius": ["不死の首の衝撃の広さ", "うみへび座：むき出しの不死の首が出す衝撃の届く半径。", "単位（距離）"],
	"tech_cd": ["技別クールダウンの基準", "うみへび座：大技の終了から同じ技を再使用するまでの基準時間。BT の実行タスクの倍率を掛ける。", "世界秒"],
	"tech_recovery": ["大技後の攻めどき", "うみへび座：大技の終了・中断後に、通常首と大技の攻撃を休む時間。", "世界秒"],
	"shard_speed": ["瓦礫の破片の速さ", "うみへび座：強めの技で砕けた瓦礫の破片（敵の弾）の速さ。", "単位/秒"],
	"shard_dmg": ["瓦礫の破片のダメージ", "うみへび座：強めの技で砕けた瓦礫の破片のダメージ。", "HP"],
}

## 半径
## 当たり判定と見た目の大きさ。
## 単位：単位（距離）
@export var radius: float
## 専用ステータスを使う場合のHP。
## use_def_stats がfalseなら共通調整値の「ボスの HP」を使う。
## 単位：HP
@export var hp: float
## HPと装甲をこの定義から読み、共通の敵倍率を掛ける。
@export var use_def_stats := false
## 専用ステータスを使う場合の装甲。
## use_def_stats がfalseなら共通調整値の「ボスの装甲」を使う。
## 単位：攻撃力
@export var armor: float
## ヒットストップ時間倍率
## この種類への一撃撃破・体当たりクリティカルの停止実時間に掛ける。1で共通値、0で停止なし。
## 停止時間は共通の累積上限内に収める。世界の速度倍率と白色化・振動は独立。
## 単位：倍（0以上）
@export_range(0.0, 10.0, 0.05, "or_greater") var hitstop_multiplier: float = 1.0
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
