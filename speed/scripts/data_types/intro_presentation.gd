## 導入の仮演出。絵と尺はこのリソースで差し替える。
class_name IntroPresentation
extends Resource

@export_group("映像の尺（実秒）")
@export_range(0.1,20.0) var focus_time := 3.0
@export_range(0.1,20.0) var devour_time := 3.0
@export_range(0.1,20.0) var depart_time := 2.0
@export_range(0.1, 20.0) var flight_time := 7.5
@export_range(0.1, 20.0) var transform_time := 4.0
@export_range(0.1, 20.0) var handoff_time := 2.0
@export_range(0.1, 20.0) var restore_time := 3.0
@export_range(0.1, 20.0) var omen_time := 6.0
@export_range(0.1, 20.0) var motive_time := 3.0
@export_range(0.0, 20.0) var hint_delay := 0.0

@export_group("差し替え用の仮素材")
## 既存のドリフターを練習に流用する。敵の本番データは変更しない。
@export var practice_enemy: EnemyDef
@export var transform_texture: Texture2D
## 星図の一角獣の絵を、夜空へ投影する仮素材。
@export var unicorn_texture: Texture2D
@export var aura_color := Color(0.7, 0.012, 0.004, 1.0)
@export var star_color := Color(1.0, 0.92, 0.65, 1.0)

@export_group("遠い上空の星座")
## 画面内の相対位置。戦闘の中心と離れた、上方の星空に置く。
@export var sky_anchor := Vector2(0.70, 0.26)
## 画面の短辺に対する表示枠の割合。
@export_range(0.04, 0.28) var sky_size := 0.20
## 暗い星空の中でも読み取れる、半透明の不穏な光。
@export var sky_glow_color := Color(0.95, 0.055, 0.035, 0.8)


@export_group("練習の配置と見本線")
## 機体からの位置。見本線が複数の敵を曲がって通るように並べる。
@export var practice_offsets := PackedVector2Array([Vector2(230, -80), Vector2(370, -150), Vector2(490, -20), Vector2(620, -110)])
@export var guide_color := Color(0.95, 0.86, 0.6, 0.62)
