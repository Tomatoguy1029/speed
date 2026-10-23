## 敵の表（設計書 6）。1行が1体で、項目ごとの列で持つ。隕石とボスも同じ表に入る。
##
## 生きている敵は、撃破されて空きに戻るまで同じ行にいる。空いた行は次に出る敵に使い回す。
## 行を加える・空きに戻すのは EnemySystem だけ。値の書き換えは、敵を動かす処理（戦闘・武器・ボス）も行う。
## 何フレームもまたいで敵を覚えるときは、行番号と id の組で覚え、EnemySystem.is_same で確かめる。
## 列の一覧と、どの種類の敵が使う列かは設計書 6.2 の表。列を足したら同じ作業で表も直す。
class_name EnemyTable
extends RefCounted

enum Mode { MOVE, WINDUP, DASH, RECOVER }
## 特殊な倒し方の種類（EnemyDef.gate を生成時に数値へ直したもの）
enum Gate { NONE, BACK, MEMBRANE, CLAW, GUARD, SOLID, GHOST, IMMORTAL }
## 攻撃が当たったときの扱い：通常どおり／貫通するがダメージなし／弾かれる（失敗）
enum GateResult { ALLOW, PASS, BOUNCE }

# ── 共通：全部の行 ────────────────────────────────────────────────

## 1 なら使用中の行
var alive := PackedByteArray()
## 通し番号。行を使い回しても、同じ番号は二度と使わない
var id := PackedInt32Array()
var def: Array[EnemyDef] = []
var type: Array[StringName] = []
## 行動の種類の番号（EnemySystem.behaviors の位置。その戦いで出た順に振る）
var beh := PackedByteArray()
## 行動の種類ごとの行番号の一覧の中での位置（一覧に入っていなければ -1）
var beh_slot := PackedInt32Array()
var is_boss := PackedByteArray()
## 隕石の配置の通し番号（隕石でなければ -1）
var meteor_index := PackedInt32Array()
## overrideを使う群れの通し番号。0なら個体ごとの攻撃枠。
var attack_group := PackedInt32Array()
## 個体の攻撃value、またはoverride群れが共有するvalue。
var attack_value := PackedFloat64Array()
## 出現元から引き継いだ攻撃待ちの優先度。0も独立した値として持つ。
var attack_priority := PackedFloat64Array()
## 1 なら撃破済み（その回の終わりに空きへ戻る）
var dead := PackedByteArray()
var elite := PackedByteArray()
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var facing := PackedFloat64Array()
var r := PackedFloat64Array()
var hp := PackedFloat64Array()
var max_hp := PackedFloat64Array()
var armor := PackedFloat64Array()
var xp := PackedFloat64Array()
## 背面の弱点の半角（0 なら弱点なし）
var weak_arc := PackedFloat64Array()
## 特殊な倒し方の種類（Gate）
var gate := PackedByteArray()
var color := PackedColorArray()
## 同じ敵に続けて当たらない時間、被弾の光、年齢
var hit_cd := PackedFloat64Array()
## 生まれてから攻撃を受けない残り時間（分裂体が、親を倒した攻撃で一緒に倒れないように）
var guard := PackedFloat64Array()
var flash := PackedFloat64Array()
var age := PackedFloat64Array()
## 大型の敵の撃破で、破片を飛ばし終えたか
var hull_scattered := PackedByteArray()

# ── 動き：行動する雑魚 ────────────────────────────────────────────

var speed := PackedFloat64Array()
var accel := PackedFloat64Array()
var turn := PackedFloat64Array()
## 天体の近傍確認の省略：前回確かめたときの、天体の表面までの距離（負なら次の更新で確かめる）・位置・世界時刻
var body_gap := PackedFloat64Array()
var body_gap_pos := PackedVector2Array()
var body_gap_time := PackedFloat64Array()


# ── 行動の状態：種類ごと ──────────────────────────────────────────

## 攻撃の段階と残り時間。ほうおう座は MOVE が離脱、WINDUP が着地点予告、DASH が飛び込み、RECOVER が着地後の停止。
var mode := PackedByteArray()
var timer := PackedFloat64Array()
## 射撃型・ミサイル艇・戦艦：次の射撃までの時間、予告の溜め（0〜1。ボスも使う）
var fire_t := PackedFloat64Array()
var charge := PackedFloat64Array()
## 分裂型：次の分裂までの時間と、分裂した数。ポンプ座は buds に吸い込んだ敵の数を持つ
var bud_t := PackedFloat64Array()
var buds := PackedInt32Array()
## からす座：回収して運んでいる経験値の量
var carry := PackedFloat64Array()
## レチクル座：狙っている岩の行番号と id（狙っていなければ -1）。ケフェウス座の兵：仕える王の行番号と id
var target := PackedInt32Array()
var target_id := PackedInt32Array()
## ケフェウス座：隊列の基準の位置。ほうおう座：離脱先・予告した着地点。
var anchor := PackedVector2Array()
## 漂流する敵・隕石の回転の速さ
var spin := PackedFloat64Array()
## 敵に付いて動く攻撃の形の行番号（ProjectileSystem の hazard_ の行。とけい座の針など）
var links: Array[PackedInt32Array] = []
## 部位：親の敵の行番号と id（部位でなければ -1）。親は部位の行番号と id を交互に並べて持つ
var parent := PackedInt32Array()
var parent_id := PackedInt32Array()
var parts: Array[PackedInt32Array] = []
## 1 なら目印の星を持つ敵（倒すと、ミニマップに英雄の星座への線が出る）
var landmark := PackedByteArray()
## 最後に火（ヘルクレス座の力）でダメージを受けた世界時刻
var fire_hit := PackedFloat64Array()
## 石になっている残り時間（ペルセウス座の力。石の間は動かず、触れると砕ける）
var stone := PackedFloat64Array()
## 1 ならほかの敵に抱えられている（みなみのかんむり座の渦など）。抱えている側が動かし、自分の行動は止まる
var held := PackedByteArray()

# ── 吹き飛ばされている間 ──────────────────────────────────────────

## 吹き飛ばされて追跡をやめている時間
var knock_t := PackedFloat64Array()
## 吹き飛ばし衝角で押し出されている間の値
var shove_time := PackedFloat64Array()
var shove_vel := PackedVector2Array()
var shove_dmg := PackedFloat64Array()
## 押し出されている間に当てた敵（id → true）
var shove_hits: Array[Dictionary] = []
var shove_from := PackedVector2Array()
var shoved := PackedByteArray()

# ── なぞりで当たったとき ──────────────────────────────────────────

## 1回の突進で最初に触れたときに満タンだったか（ヒットストップの一撃の判定、仕様書 7.4）
var dash_seen := PackedInt32Array()
var dash_fresh := PackedByteArray()
