## 敵の表（設計書 6）。1行が1体で、項目ごとの列で持つ。隕石とボスも同じ表に入る。
##
## 生きている敵は、撃破されて空きに戻るまで同じ行にいる。空いた行は次に出る敵に使い回す。
## 行を加える・空きに戻すのは EnemyManager だけ。値の書き換えは、敵を動かす処理（戦闘・武器・ボス）も行う。
## 何フレームもまたいで敵を覚えるときは、行番号と id の組で覚え、EnemyManager.is_same で確かめる。
## 列の一覧と、どの種類の敵が使う列かは設計書 6.2 の表。列を足したら同じ作業で表も直す。
class_name EnemyTable
extends RefCounted

enum Mode { MOVE, WINDUP, DASH, RECOVER }
## 行動の種類（EnemyDef.behavior を生成時に数値へ直したもの）
enum Beh { CHASE, DASH, SPLIT, GUNNER, MISSILE, BATTLESHIP, DRIFT }

# ── 共通：全部の行 ────────────────────────────────────────────────

## 1 なら使用中の行
var alive := PackedByteArray()
## 通し番号。行を使い回しても、同じ番号は二度と使わない
var id := PackedInt32Array()
var def: Array[EnemyDef] = []
var type: Array[StringName] = []
var beh := PackedByteArray()
## 行動の種類ごとの行番号の一覧の中での位置（一覧に入っていなければ -1）
var beh_slot := PackedInt32Array()
var is_boss := PackedByteArray()
## 隕石の配置の通し番号（隕石でなければ -1）
var meteor_index := PackedInt32Array()
## 1 なら撃破済み（その回の終わりに空きへ戻る）
var dead := PackedByteArray()
var level := PackedFloat64Array()
var elite := PackedByteArray()
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var facing := PackedFloat64Array()
var r := PackedFloat64Array()
var hp := PackedFloat64Array()
var max_hp := PackedFloat64Array()
var armor := PackedFloat64Array()
var contact := PackedFloat64Array()
var xp := PackedFloat64Array()
## 背面の弱点の半角（0 なら弱点なし）
var weak_arc := PackedFloat64Array()
var color := PackedColorArray()
## 同じ敵に続けて当たらない時間、被弾の光、年齢
var hit_cd := PackedFloat64Array()
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

# ── 追跡の広域移動：追跡する雑魚（仕様書 11.5）─────────────────────

## 周期のずれ、移動先の向きと広がり（敵ごとに決まった値）
var roam_phase := PackedFloat64Array()
var roam_angle := PackedFloat64Array()
var roam_radius := PackedFloat64Array()

# ── 行動の状態：種類ごと ──────────────────────────────────────────

## 突進型：予告 → 突進 → 回復の段階と、その残り時間
var mode := PackedByteArray()
var timer := PackedFloat64Array()
## 射撃型・ミサイル艇・戦艦：次の射撃までの時間、予告の溜め（0〜1。ボスも使う）
var fire_t := PackedFloat64Array()
var charge := PackedFloat64Array()
## 分裂型：次の分裂までの時間と、分裂した数
var bud_t := PackedFloat64Array()
var buds := PackedInt32Array()
## 漂流する敵・隕石の回転の速さ
var spin := PackedFloat64Array()

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
