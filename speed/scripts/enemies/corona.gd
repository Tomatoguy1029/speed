## みなみのかんむり座：機体を追いながら、近くの雑魚を短距離の渦に捕まえて回し、機体の方へ投げる。
extends EnemyBehavior

const VORTEX := preload("res://scripts/enemies/corona_vortex.gd")
var vortex := VORTEX.new()

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	# 投げる瞬間に自分で攻撃の枠を取る
	admission = false
	watches_rows = true

func step(i: int, dt: float) -> void:
	_chase(i, dt)

## 冠の移動を確定してから渦を進める。
func after_tick(dt: float) -> void:
	vortex.tick(m, dt, rows())

## 機体の移動と通常の戦闘のあとに、投げた敵の当たりを調べる。
func after_combat() -> void:
	vortex.hit_thrown(m, m.ctx.ship)

## 冠や抱えている敵が倒れた・空きに戻った・再配置された。
func on_row_gone(i: int) -> void:
	vortex.release(m, i)

func clear() -> void:
	vortex.clear()

func admit_due(i: int, dt: float) -> bool:
	return table.fire_t[i] <= dt

func admit_duration(i: int) -> float:
	var p: Dictionary = table.def[i].params
	return float(p.telegraph) + TAU / maxf(absf(float(p.spin)), 0.1) + float(p.throw_life)
