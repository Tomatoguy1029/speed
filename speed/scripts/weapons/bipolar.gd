## W22 双極ビーム：なぞり始めの点に発射器を残し、なぞりの終わりに発射器と機体の間を太いビームで貫く（彗星限定。一覧 docs/game/catalog/weapons.md）。
## 弾かれて終わったときも、実際に止まった位置まで撃つ。
extends WeaponBehavior

## 発射器の位置（なぞっていない間は null）
var origin = null
var _buf := PackedInt32Array()
var pending: Array[Dictionary] = []

func on_launch(_full: bool) -> void:
	origin = state.ship_pos

func on_end() -> void:
	if origin == null:
		return
	var from: Vector2 = origin
	origin = null
	var to := state.ship_pos
	var d := to - from
	var length := d.length()
	if length <= float(p("min_length")):
		return
	pending.append({"from":from,"to":to,"delay":0.18})
	state.emit(&"bipolar_charge",{"from":from,"to":to})

func tick(dt: float, _busy: bool) -> void:
	for shot in pending:
		shot.delay-=dt
		if shot.delay<=0.0:_fire(shot.from,shot.to)
	pending=pending.filter(func(s):return s.delay>0.0)

func _fire(from: Vector2, to: Vector2) -> void:
	var d:=to-from
	var length:=d.length()
	var u := d / length
	var width := float(p("width")) * radius_k()
	var pad := Vector2(width / 2.0, width / 2.0)
	ctx.combat.in_rect(from.min(to) - pad, from.max(to) + pad, _buf)
	var dmg := atk() * float(p("damage")) * dmg_k()
	var t := ctx.enemies.table
	for i in _buf:
		if t.dead[i] != 0 or Geom.seg_circle_t(from, to, t.pos[i], t.r[i] + width / 2.0) < 0.0:
			continue
		ctx.combat.damage_enemy(i, dmg, {"cause": &"bipolar", "dir": u, "knock": p("knock")})
		if state.phase != RunState.Phase.PLAY:
			return
	var color := Color(p("color", "#69fff0"))
	var life := float(p("life"))
	state.emit(&"beam", {"from": from, "to": to, "width": width, "color": color, "life": life,
		"visual_key": "weapon/bipolar", "width_scale": radius_k()})
	state.emit(&"ring", {"pos": from, "radius": 65.0, "color": color, "life": life,
		"visual_key": "weapon/bipolar"})
	state.emit(&"ring", {"pos": to, "radius": 65.0, "color": color, "life": life,
		"visual_key": "weapon/bipolar"})
