## W22 双極ビーム：なぞり始めの点に発射器を残し、なぞりの終わりに発射器と機体の間を太いビームで貫く（彗星限定。一覧 docs/game/catalog/weapons.md）。
## 弾かれて終わったときも、実際に止まった位置まで撃つ。
extends WeaponBehavior

## 発射器の位置（なぞっていない間は null）
var origin = null
var _buf := PackedInt32Array()

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
	var u := d / length
	var width := float(p("width")) * radius_k()
	var pad := Vector2(width / 2.0, width / 2.0)
	build.combat.in_rect(from.min(to) - pad, from.max(to) + pad, _buf)
	var dmg := atk() * float(p("damage")) * dmg_k()
	var t := build.enemies.table
	for i in _buf:
		if t.dead[i] != 0 or Geom.seg_circle_t(from, to, t.pos[i], t.r[i] + width / 2.0) < 0.0:
			continue
		build.combat.damage_enemy(i, dmg, {"cause": &"bipolar", "dir": u, "knock": p("knock")})
		if state.phase != RunState.Phase.PLAY:
			return
	var color := Color(p("color", "#69fff0"))
	var life := float(p("life"))
	state.emit(&"beam", {"from": from, "to": to, "width": width, "color": color, "life": life})
	state.emit(&"ring", {"pos": from, "radius": 65.0, "color": color, "life": life})
	state.emit(&"ring", {"pos": to, "radius": 65.0, "color": color, "life": life})
