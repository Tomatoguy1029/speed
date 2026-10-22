## 冠の短距離の渦（みなみのかんむり座の Behavior が持つ）。敵の表の同じ個体を保持し、通常 AI だけを旋回・投擲に置き換える。
## 保持している個体は敵の表の held を 1 にし、EnemySystem はその行の行動を止める。
## owners[row].types[type] は個体の配列。members[row].slot と末尾交換で O(1) で除去する。
## 抽選は現在ある種類だけを回り、個体数を重みに加えない。
extends RefCounted

const ATTACK := Color("#ff3b3b")
const CORE := Color("#ffb36b")
var owners: Dictionary = {}
var members: Dictionary = {}
var _near := PackedInt32Array()

func clear() -> void:
	owners.clear()
	members.clear()

func _live(m: EnemySystem, row: int, id: int) -> bool:
	return m.is_same(row, id) and m.table.dead[row] == 0

func _cancel(m: EnemySystem, i: int, o: Dictionary) -> void:
	if m.projectiles.director != null:
		m.projectiles.director.cancel_wait(m._lab_owner(i), m.table.id[i])
	o.selected = -1
	o.selected_id = -1
	o.wait = 0.0
	m.table.mode[i] = EnemyTable.Mode.MOVE
	m.table.charge[i] = 0.0

## 死亡・行解放・冠の再配置はここを通す。投擲済みも冠の死で通常敵へ戻る。
func release(m: EnemySystem, i: int) -> void:
	if owners.has(i):
		for j in members.keys():
			if int(members[j].owner) == i:
				_detach(m, j)
		owners.erase(i)
	if members.has(i):
		_detach(m, i)

func _detach(m: EnemySystem, j: int) -> void:
	var a: Dictionary = members[j]
	_unstock(j, a)
	members.erase(j)
	m.table.held[j] = 0
	if _live(m, j, int(a.id)):
		m.table.mode[j] = EnemyTable.Mode.MOVE
		m.table.charge[j] = 0.0
		m.table.timer[j] = 0.0
		# 元の個体・HP・装甲・ゲートを保ち、通常 AI の速さへ戻す。
		m.table.vel[j] = m.table.vel[j].limit_length(m.table.speed[j])

func _unstock(j: int, a: Dictionary) -> void:
	if a.thrown or not owners.has(a.owner):
		return
	var o: Dictionary = owners[a.owner]
	var bucket: Array = o.types[a.type]
	var last: int = bucket.back()
	bucket[int(a.slot)] = last
	members[last].slot = a.slot
	bucket.pop_back()
	o.count -= 1
	if bucket.is_empty():
		o.types.erase(a.type)
	if int(o.selected) == j:
		o.selected = -1
		o.selected_id = -1

func _capture(m: EnemySystem, i: int, o: Dictionary, p: Dictionary) -> void:
	var t := m.table
	# 既存の戦闘格子を使う。直前の世界更新の位置なので、実距離も必ず確かめる。
	m.projectiles.combat.nearby(t.pos[i], float(p.pull_radius), _near)
	for j in _near:
		if int(o.count) >= int(p.capture_max):
			break
		if j == i or members.has(j) or t.dead[j] != 0 or t.is_boss[j] != 0 or t.meteor_index[j] >= 0 \
				or t.parent[j] >= 0 or t.def[j] == null or t.def[j].rank > 2 or t.gate[j] != EnemyTable.Gate.NONE \
				or t.stone[j] > 0.0 or t.knock_t[j] > 0.0 or t.shove_time[j] > 0.0:
			continue
		var kind := String(t.type[j])
		if float(p.get("throw_weight_" + kind, 0.0)) <= 0.0 or not p.has("throw_damage_" + kind):
			continue
		var offset := t.pos[j] - t.pos[i]
		if offset.length() > float(p.pull_radius):
			continue
		if not o.types.has(kind):
			o.types[kind] = []
		var bucket: Array = o.types[kind]
		members[j] = {"id": t.id[j], "owner": i, "owner_id": t.id[i], "type": kind, "slot": bucket.size(),
			"angle": offset.angle(), "radius": maxf(offset.length(), 1.0), "settled": false, "thrown": false,
			"life": 0.0, "release_fraction": 0.0, "from": t.pos[j], "ship_from": m.state.ship_pos, "damage": 0.0, "effect": float(p.throw_effect_scale)}
		bucket.append(j)
		o.count += 1
		t.held[j] = 1
		t.charge[j] = 0.0

func choose_type(o: Dictionary, weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for kind in o.types:
		total += maxf(0.0, float(weights.get("throw_weight_" + kind, 0.0)))
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for kind in o.types:
		roll -= maxf(0.0, float(weights.get("throw_weight_" + kind, 0.0)))
		if roll < 0.0:
			return kind
	return ""

## rows は冠の行。
func tick(m: EnemySystem, dt: float, rows: PackedInt32Array) -> void:
	var t := m.table
	# 通常 AI の更新が終わり、冠の移動を確定してから渦を進める（LOD は適用しない）。
	for i in rows:
		if t.dead[i] != 0:
			continue
		if not owners.has(i):
			owners[i] = {"id": t.id[i], "types": {}, "count": 0, "capture_t": 0.0,
				"selected": -1, "selected_id": -1, "wait": 0.0, "center": t.pos[i]}
		var o: Dictionary = owners[i]
		var p: Dictionary = t.def[i].params
		if t.stone[i] > 0.0:
			_cancel(m, i, o)
			o.center = t.pos[i]
			continue
		# Hydra と同じ短距離の重力減衰。高速突進・滑走中は吸い込みを振り切る。
		var fast := m.state.tracing or m.state.glide or m.state.ship_vel.length() >= m.state.stats.max_speed * m.cfg.ram_speed_ratio
		if not fast:
			m.state.ship_vel += m.field._well_pull(t.pos[i], m.state.ship_pos, float(p.pull_radius), float(p.pull) * dt)
		o.capture_t -= dt
		if float(o.capture_t) <= 0.0:
			o.capture_t = maxf(float(p.capture_interval), dt)
			_capture(m, i, o, p)
		t.fire_t[i] = maxf(0.0, t.fire_t[i] - dt)
		# 内側では予告も中止。再び外へ出たときは予告を最初から見せる。
		var inside := t.pos[i].distance_to(m.state.ship_pos) <= float(p.ring) + m.cfg.ship_radius
		if inside or int(o.count) == 0:
			_cancel(m, i, o)
		elif int(o.selected) < 0 and t.fire_t[i] <= 0.0 and m._lab_admit(i, dt):
			var kind := choose_type(o, p, m.state.rng)
			if not kind.is_empty():
				var bucket: Array = o.types[kind]
				o.selected = bucket[m.state.rng.randi_range(0, bucket.size() - 1)]
				o.selected_id = t.id[int(o.selected)]
				o.wait = float(p.telegraph)
				t.mode[i] = EnemyTable.Mode.WINDUP
		if int(o.selected) >= 0:
			o.wait = float(o.wait) - dt
			t.charge[i] = clampf(1.0 - float(o.wait) / maxf(float(p.telegraph), 0.001), 0.0, 1.0)
			# 動く標的に永久に構え続けない。解除後も同じ個体は渦に残る。
			if float(o.wait) < -TAU / maxf(absf(float(p.spin)), 0.1):
				_cancel(m, i, o)
				t.fire_t[i] = float(p.fire_interval)
	for j in members.keys():
		if not members.has(j):
			continue
		var a: Dictionary = members[j]
		if not _live(m, j, int(a.id)) or not _live(m, int(a.owner), int(a.owner_id)) \
				or t.stone[j] > 0.0 or t.shove_time[j] > 0.0 or t.knock_t[j] > 0.0:
			_detach(m, j)
			continue
		t.age[j] += dt
		t.hit_cd[j] = maxf(0.0, t.hit_cd[j] - dt)
		t.guard[j] = maxf(0.0, t.guard[j] - dt)
		t.flash[j] = maxf(0.0, t.flash[j] - dt)
		var o: Dictionary = owners[a.owner]
		var p: Dictionary = t.def[int(a.owner)].params
		a.from = t.pos[j]
		a.ship_from = m.state.ship_pos
		a.release_fraction = 0.0
		if a.thrown:
			a.life = float(a.life) - dt
			if float(a.life) <= 0.0:
				_detach(m, j)
				continue
			t.pos[j] += t.vel[j] * dt
		elif t.stone[int(a.owner)] <= 0.0:
			_orbit(m, j, a, o, p, dt)
		else:
			t.vel[j] = Vector2.ZERO
		# 天体へ当たったら保持・攻撃を終え、既存の押し戻しを使う。
		if members.has(j) and m.field.first_body_hit(a.from, t.pos[j], t.r[j]) != null:
			m.field.collide_enemy(j, a.from)
			_detach(m, j)
	for i in owners:
		owners[i].center = t.pos[i]

## 可視の速度＝冠の並進＋円の接線。吸い込み中の半径も連続的に ring へ近づける。
func _orbit(m: EnemySystem, j: int, a: Dictionary, o: Dictionary, p: Dictionary, dt: float) -> void:
	var t := m.table
	var i := int(a.owner)
	var center0: Vector2 = o.center
	var center1 := t.pos[i]
	var center_v := (center1 - center0) / dt
	var angle0 := float(a.angle)
	var radius0 := float(a.radius)
	var radius1 := move_toward(radius0, float(p.ring), maxf(0.0, float(p.pull)) * dt)
	var spin := float(p.spin)
	var angle1 := angle0 + spin * dt
	var start := t.pos[j]
	var finish := center1 + Vector2.from_angle(angle1) * radius1
	var ready := bool(a.settled) and is_equal_approx(radius0, float(p.ring)) and int(o.selected) == j and int(o.selected_id) == t.id[j] and float(o.wait) <= 0.0
	if ready:
		# 刻みをまたぐ一致は両端の角度誤差の符号で拾う。±PI の折り返しは除く。
		var e0 := _error(center0, center_v, angle0, radius0, spin, m.state.ship_pos)
		var e1 := _error(center1, center_v, angle1, radius1, spin, m.state.ship_pos)
		var crosses := e0 * e1 <= 0.0 and absf(e1 - e0) < PI
		var f := -1.0
		if crosses:
			var lo := 0.0
			var hi := 1.0
			for step in 10:
				var mid := (lo + hi) * 0.5
				var e := _error(center0.lerp(center1, mid), center_v, lerpf(angle0, angle1, mid), radius1, spin, m.state.ship_pos)
				if e * e0 > 0.0: lo = mid
				else: hi = mid
			f = (lo + hi) * 0.5
		elif absf(e0) <= float(p.align_angle):
			f = 0.0
		if f >= 0.0:
			var angle := lerpf(angle0, angle1, f)
			var at := center0.lerp(center1, f) + Vector2.from_angle(angle) * radius1
			var direction := _velocity(center_v, angle, radius1, spin).normalized()
			if direction != Vector2.ZERO and direction.dot((m.state.ship_pos - at).normalized()) > 0.0:
				_unstock(j, a)
				a.thrown = true
				a.life = float(p.throw_life)
				a.damage = float(p["throw_damage_" + String(a.type)])
				a.from = at
				a.release_fraction = f
				t.vel[j] = direction * float(p.throw_speed)
				# 同じ更新の残り時間だけ直進。発射点へのワープや複製を作らない。
				t.pos[j] = at + t.vel[j] * dt * (1.0 - f)
				t.facing[j] = direction.angle()
				_cancel(m, i, o)
				t.fire_t[i] = float(p.fire_interval)
				return
	a.angle = angle1
	a.radius = radius1
	a.settled = is_equal_approx(radius1, float(p.ring))
	t.pos[j] = finish
	t.vel[j] = (finish - start) / dt
	t.facing[j] = t.vel[j].angle()

static func _velocity(center_v: Vector2, angle: float, radius: float, spin: float) -> Vector2:
	return center_v + Vector2(-sin(angle), cos(angle)) * radius * spin

static func _error(center: Vector2, center_v: Vector2, angle: float, radius: float, spin: float, target: Vector2) -> float:
	var at := center + Vector2.from_angle(angle) * radius
	return Geom.angle_diff((target - at).angle(), _velocity(center_v, angle, radius, spin).angle())

## 機体の移動・通常戦闘の後に判定。倒された弾薬は当たらず、1投につき1回で既存の無敵・盾を通す。
func hit_thrown(m: EnemySystem, ship: ShipSystem) -> void:
	for j in members.keys():
		var a: Dictionary = members[j]
		if not a.thrown or not _live(m, j, int(a.id)):
			continue
		var reach := m.table.r[j] * float(a.effect) + m.cfg.ship_radius
		# 機体の移動も差し引いた相対線分で、高速のすれ違いを判定する。
		var ship_from: Vector2 = a.ship_from.lerp(m.state.ship_pos, float(a.release_fraction))
		if Geom.seg_circle_t(a.from - ship_from, m.table.pos[j] - m.state.ship_pos, Vector2.ZERO, reach) >= 0.0:
			var damage := float(a.damage)
			_detach(m, j)
			ship.damage(damage, 0.0, &"corona_throw", &"corona")
			if m.state.phase != RunState.Phase.PLAY:
				return

## 差し替え用の図形。攻撃色は既存の敵弾の赤と爆発の橙。尾は飾りで、判定は頭の円。
func draw(c: CanvasItem, m: EnemySystem, view: Rect2) -> void:
	var t := m.table
	for i in owners:
		if not _live(m, i, int(owners[i].id)) or not view.grow(200).has_point(t.pos[i]):
			continue
		var p: Dictionary = t.def[i].params
		var ring := float(p.ring)
		var time := m.state.world_time * float(p.spin)
		for k in 3:
			var angle := time + k * TAU / 3.0
			c.draw_arc(t.pos[i], ring * (0.72 + k * 0.14), angle, angle + 1.8, 20, Color("#b6a2db", 0.3), 3.0, true)
		if t.mode[i] == EnemyTable.Mode.WINDUP:
			c.draw_arc(t.pos[i], t.r[i] * 1.2, -PI / 2.0, -PI / 2.0 + maxf(0.02, t.charge[i]) * TAU, 32, ATTACK, 4.0, true)
	for j in members:
		var a: Dictionary = members[j]
		if not _live(m, j, int(a.id)) or not view.grow(180).has_point(t.pos[j]):
			continue
		var at := t.pos[j]
		var r := t.r[j] * float(a.effect)
		if a.thrown:
			var u := t.vel[j].normalized()
			var side := Vector2(-u.y, u.x) * r
			c.draw_polygon(PackedVector2Array([at + side, at - u * r * 4.5, at - side]),
				PackedColorArray([Color(ATTACK, 0.5), Color(ATTACK, 0.0), Color(ATTACK, 0.5)]))
			c.draw_circle(at, r, Color(ATTACK, 0.15))
			c.draw_arc(at, r, 0, TAU, 32, ATTACK, 3.0, true)
			c.draw_arc(at, r * 1.08, u.angle() - 1.2, u.angle() + 1.2, 18, CORE, 3.0, true)
		elif owners.has(a.owner) and int(owners[a.owner].selected) == j:
			var pulse := 0.65 + 0.35 * sin(m.state.world_time * 18.0)
			c.draw_arc(at, r, 0, TAU, 24, Color(ATTACK, pulse), 3.0, true)
			c.draw_line(t.pos[int(a.owner)], at, Color(ATTACK, 0.35), 2.0, true)
