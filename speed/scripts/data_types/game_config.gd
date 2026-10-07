## 調整できる数値の定義（設計書 8.3）。値の正は res://data/config.tres。
##
## ここに書く既定値はすべて 0 にしておく。Godot は既定値と同じ値を .tres に保存しないため、
## 既定値を実際の値にすると、.tres から数値が消えて「.tres が正」が崩れる。
## 意味と単位は仕様書（docs/spec.md）の対応する章を参照。
class_name GameConfig
extends Resource

@export_group("ラン（仕様書 2）")
@export var run_time: float
@export var boss_time: float
@export var boss_hp: float
@export var boss_armor: float
@export var clear_bonus: int
@export var speed_to_kms: float

@export_group("演出（仕様書 14）")
@export var boss_finish_replay_window: float
@export var boss_finish_slow_time: float
@export var boss_finish_zoom: float
@export var boss_finish_blast_time: float
@export var boss_finish_clear_time: float
@export var death_freeze_time: float
@export var death_world_dim: float
@export var death_explosion_time: float
@export var death_game_over_time: float
@export var ship_hurt_time: float
@export var ship_hurt_shake: float
@export var block_spark_count: int
@export var block_impact_life: float
@export var weak_flame_count: int
@export var weak_impact_life: float
@export var corpse_trail_life: float
@export var corpse_trail_points: int

@export_group("フィールド（仕様書 11）")
@export var field_radius: float
@export var planet_radius: float
@export var zone_inner: float
@export var zone_outer: float
@export var start_radius: float
@export var moon_count: int
@export var moon_orbit_speed: float
@export var dust_count: int
@export var dust_drag: float
@export var boundary_push: float
@export var crash_restitution: float
@export var crash_damage: float

@export_group("機体（仕様書 3）")
@export var base_max_speed: float
@export var base_hp: float
@export var ship_radius: float
@export var invuln_time: float
@export var pickup_radius: float
@export var level_speed_growth: float
@export var level_atk_growth: float
@export var level_hp_growth: float
@export var level_heal: float
@export var steer_rate: float
@export var steer_accel: float
@export var steer_cruise: float
@export var stick_cruise_max: float
@export var stick_dead_zone: float
@export var stick_radius: float
@export var mouse_dead_zone: float
@export var cruise_drag: float
@export var cruise_floor: float
@export var overcap_decay: float
## なぞりの開始時の速さ：最高速度 × launch_ratio × 充填率 ＋ 同じ向きの今の速さ × carry
@export var launch_ratio: float
@export var carry: float
## 発射後に減速しない時間（秒）と、その後に残す速さの割合
@export var boost_duration: float
@export var energy_cut: float
## これより遅いときは向きを変えない（速さ）
@export var pivot_speed: float

@export_group("ゲージと描画（仕様書 4）")
@export var dash_charge_time: float
@export var draw_min_charge: float
@export var draw_length: float
@export var draw_time_scale: float
@export var draw_run_slow_ref: float
@export var draw_run_scale_min: float
@export var draw_run_time: float
@export var draw_step: float
@export var wave_radius: float
@export var wave_damage: float

@export_group("戦闘（仕様書 5）")
@export var base_attack: float
@export var atk_scale: float
@export var base_crit_chance: float
@export var crit_mult: float
@export var ram_speed_ratio: float
## クリティカルの体当たりで装甲の判定に使う割合
@export var crit_armor: float
## 弾かれたときに残す速さの割合と、最低の速さ
@export var bounce_keep: float
@export var bounce_min_speed: float
## 同じ敵に続けて当たらない時間（世界秒）
@export var contact_cooldown: float
@export var kill_hitstop: float
@export var kill_hitstop_cap: float
@export var kill_hitstop_regen: float
@export var hitstop_big_mult: float
@export var hitstop_crit_mult: float
@export var enemy_aim_lag: float
@export var enemy_aim_speed: float

@export_group("敵（仕様書 9）")
@export var enemy_hp_mult: float
@export var enemy_armor_mult: float
@export var density_mult: float
@export var enemy_pursuit_spread: float
@export var enemy_approach_cycle: float
@export var enemy_approach_time: float
@export var enemy_approach_blend: float
@export var enemy_roam_turn: float
@export var enemy_split_overflow: float
@export var danger_level: float
@export var spawn_margin: float
@export var spawn_refill_time: float
@export var spawn_recycle_scale: float
@export var titan_max: int
## 当たり判定の格子の大きさと、敵の半径の最大値（格子の検索の余白）
@export var grid_cell: float
@export var max_enemy_radius: float
@export var battleship_max: int

@export_group("大型の敵の破片（仕様書 9.5）")
@export var hull_debris_min_radius: float
@export var hull_debris_max_pieces: int
@export var hull_debris_life: float
@export var hull_debris_damage: float
@export var hull_debris_speed: float
@export var hull_debris_force_speed: float
@export var hull_debris_knock: float
@export var hull_debris_spread: float

@export_group("ドロップ（仕様書 8）")
@export var drop_base: float
@export var drop_power_exp: float
@export var drop_max: float
@export var capsule_xp_frac: float
@export var drift_capsule_xp_frac: float
@export var drift_capsule_count: int
@export var drift_capsule_interval: float
@export var meteor_count: int
@export var meteor_coin_chance: float
@export var meteor_heal_chance: float
@export var meteor_heal_frac: float
@export var meteor_magnet_chance: float
@export var core_boost: float
@export var core_start_time: float
@export var pickup_life: float
@export var gem_max: int

@export_group("成長（仕様書 6・7）")
@export var xp_base: float
@export var xp_growth: float
@export var xp_curve: float
@export var weapon_slots: int
@export var weapon_max_level: int
@export var trait_slots: int
@export var trait_max_stacks: int
@export var owned_card_bias: float
@export var fallback_heal: float

@export_group("カメラ（仕様書 13）")
@export var base_view: float
@export var zoom_ref_speed: float
@export var zoom_exp: float
@export var zoom_min: float
@export var look_ahead: float
