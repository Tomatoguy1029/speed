## 1回のランの状態（設計書 4.4 の決まり3：状態と処理を分ける）。
##
## ラン中の Manager はこの状態を読み書きし、処理だけを持つ。敵・弾・ドロップのように数の多いものは、
## それぞれの Manager が配列で持つ（設計書 6）。ここには数の少ない状態と、Manager の間で共有する値を置く。
class_name RunState
extends RefCounted

enum Phase { PLAY, LEVELUP, PAUSED, DYING, FINISHING, ENDED }

var stage_index := 1
var endless := false
var stage: StageDef
var phase: Phase = Phase.PLAY
var rng := RandomNumberGenerator.new()

# ── 時計（仕様書 1・4.1） ────────────────────────────────────────────
## ランの時計（実秒）。ポーズ・3択で止まる
var time := 0.0
## 世界の時間（世界秒）
var world_time := 0.0
## 世界の速さ（描画中・なぞり中に遅くなる。ヒットストップ中は 0）
var world_scale := 1.0
## ヒットストップの残り（実秒）と、突進ごとの上限の残り
var hitstop := 0.0
var hitstop_budget := 0.0

# ── 機体（仕様書 5） ───────────────────────────────────────────────
var ship_pos := Vector2.ZERO
var ship_vel := Vector2.ZERO
## 機体の向き（進む向き。ほぼ止まっているときは最後に操作した向き）
var ship_heading := Vector2.UP
## 発射後に減速しない残り時間と、その後の減速の残り時間（世界秒）
var ship_boost_t := 0.0
var ship_fade_t := 0.0
var ship_hp := 0.0
var ship_invuln := 0.0
## 被弾の赤い表示の残り（実秒）
var ship_hurt := 0.0
## なぞり終えたあとの勢いがあるか（仕様書 6.6）
var glide := false
## 減速型のオーラによる抵抗（毎更新で集計し直す）
var leech_drag := 0.0
## 能力値（基礎値・レベル・特性・強化から計算する。BuildManager が更新する）
var stats := ShipStats.new()

# ── ゲージと描画（仕様書 6） ─────────────────────────────────────────
## 充填率（0〜1）
var gauge := 1.0
var drawing := false
## 描き始めたか（Space で始めたときは、クリックするまで線を引かない）
var draw_started := false
## 線が惑星・月に届いたか
var draw_blocked := false
## 描画で使う充填の量（容量 × 充填率）
var draw_gauge := 0.0
var draw_points := PackedVector2Array()
var draw_limit := 0.0
var draw_length := 0.0
var draw_start_charge := 0.0
## なぞり中か、なぞる線、進み具合（0〜1）、満タンから始めたか
var tracing := false
var trace_path := PackedVector2Array()
var trace_lengths := PackedFloat32Array()
var trace_total := 0.0
var trace_progress := 0.0
var trace_full_charge := false
## なぞり（と勢い）1回ぶんの通し番号。同じ突進で同じ敵に何度も当てないために使う
var dash_id := 0

# ── 成長（仕様書 8・9） ─────────────────────────────────────────────
var level := 1
var xp := 0.0
## 武器の管理 ID → Lv、特性の管理 ID → 重ね数
var weapons: Dictionary = {}
var traits: Dictionary = {}
## 保留中のレベルアップの数と、表示中の3択
var pending_levels := 0
var cards: Array[Dictionary] = []
## このランで残っている、3択を引き直せる回数
var rerolls_left := 0

# ── 敵の狙い・カメラ（仕様書 7.5・15） ────────────────────────────────
var enemy_aim := Vector2.ZERO
## 画面に映っている世界の範囲の半分（カメラの位置とズームから毎フレーム求める）
var view_center := Vector2.ZERO
var view_half := Vector2(640, 360)
var camera_zoom := 1.0
var camera_locked := false

# ── ボス（仕様書 12.2） ─────────────────────────────────────────────
var boss_spawned := false
var boss_dead := false

# ── 結果 ──────────────────────────────────────────────────────────
var kills := 0
var coins := 0
var peak_speed := 0.0
## このランで手に入れたモジュール（図鑑に記録する）
var modules_obtained: Array[StringName] = []
var cleared := false

## 1回の更新で起きた出来事（命中・撃破など）。表示・音・UI が読む（設計書 4.3）。
var events: Array[Dictionary] = []

func emit(type: StringName, data := {}) -> void:
	data.type = type
	events.append(data)

func view_rect() -> Rect2:
	return Rect2(view_center - view_half, view_half * 2.0)
