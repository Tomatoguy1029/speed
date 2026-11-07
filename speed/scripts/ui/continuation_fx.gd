## 継続演出（1回目 Iris・2回目 Star Iris・3回目 Shatter）。承認済みの試作 .local/continuation-fx/main.js を同じ式と順で描く。
## 640×360 の透明な層へ描き、普通の重ね（source-over）と光の足し（lighter）を試作のコード順に切り替える。
## 星・花火・紙吹雪の画素は SpeedPixelFx（pixelfx 0.3.0、MIT, Patch / Hugo Duprez）が描く。
extends Node2D

signal settled

const W := 640.0
const H := 360.0
const CX := 320.0
const CY := 172.0
const CYAN := Color("#5bc8db")
const NEON := Color("#7ff3ff")
const GOLD := Color("#efcb70")
const MAG := Color("#ff4fd8")
const SUB := Color("#a6b4cb")
const WHITE := Color(1, 1, 1)
const TIER := {1: NEON, 2: GOLD, 3: WHITE}
const ADD_SHADER := preload("res://assets/ui/rewards/continuation_add.gdshader")
const TINT_SHADER := preload("res://assets/ui/rewards/continuation_tint.gdshader")
const INK_SHADER := preload("res://assets/ui/rewards/continuation_ink.gdshader")

## 試作の調整値
const START_SCALE := 0.1
const APPROACH := {1: 0.16, 2: 0.26, 3: 0.14}
const BOUNCE := 0.5
const FREQ := 3.6
const DAMPING := 0.26
const SPIN_TURNS := 2.0
const SHAKE := {1: 5.0, 2: 8.0, 3: 11.0}
const STARS := 260
const FIRE_EVERY := 0.42
const CONFETTI_EVERY := 0.9
const SQUASH := 0.26
const WIGGLE := 4.0
const PICK_DELAY := 0.1
const TR := {1: {close = 0.22, open0 = 0.28, open1 = 0.6, full = 420.0}, 2: {close = 0.26, open0 = 0.32, open1 = 0.74, full = 980.0}}
const CRACK := 0.18
const CARD_AT := {1: 0.28, 2: 0.32, 3: 0.18}
const WIG_BASE := [Vector2(-86, -106), Vector2(4, -111), Vector2(88, -102), Vector2(91, 6), Vector2(84, 106), Vector2(-3, 104), Vector2(-90, 101), Vector2(-87, -3)]
const FW_PALS := [
	["#04202a", "#0a4a5c", "#127d94", "#2fb8d0", "#7ff3ff", "#d4fbff", "#ffffff"],
	["#3d0a33", "#701560", "#b0228f", "#f53cd1", "#ff86e6", "#ffd2f6", "#ffffff"],
	["#1e1206", "#86520c", "#c48412", "#f0b424", "#ffe066", "#fff6c4", "#ffffff"],
	["#0c1430", "#1f4f94", "#2f7fcc", "#58b4ec", "#9bdcff", "#d8f4ff", "#ffffff"],
]
const CONF_PAL := ["#ff4fd8", "#5bc8db", "#ffe066", "#7ff3ff", "#3a7bff", "#9bff6a", "#ffffff"]
const STAR_COLS := ["#ffffff", "#fff6c4", "#ffe066", "#f0b424", "#9bdcff"]
const NEON_COLS := ["#ffffff", "#7ff3ff", "#5bc8db", "#ff86e6", "#ffe066"]
const P_SPARK := 0
const P_STAR := 6

enum Mode {NORMAL, ADD, TINT, INK}

## 表示に使う文字と、カード3択の写し・その中の選んだカードの範囲（640×360の座標）
var heading := ""
var hint := ""
var count_format := "{n} 連続！"
var font: Font
var bold_font: Font
var select_snapshot: Texture2D
var picked_rect := Rect2()

var _time := 0.0
var _screen := {}
var _chain := {}
var _hold_t := 0.0
var _pick_t := -1.0
var _cards := {}
var _shard_snap: Texture2D
var _shakes: Array = []
var _flash := 0.0
var _flash_col := WHITE
var _crt := 0.0
var _timers: Array = []
var _streaks: Array = []
var _rings: Array = []
var _bits: Array = []
var _flares: Array = []
var _celebrating := false
var _fw_acc := 0.0
var _cf_acc := 0.0
var _cf_side := 0
var _tw_acc := 0.0
var _fw_seed := 1
var _rng := RandomNumberGenerator.new()
var _wig_rng := RandomNumberGenerator.new()
var _pixels: Object
var _confetti: Object
var _pixel_tex: ImageTexture
var _confetti_tex: ImageTexture
var _hex_lines := PackedVector2Array()
var _items: Array[RID] = []
var _used := 0
var _item := RID()
var _mode := -1
var _xf := Transform2D.IDENTITY
var _materials := {}
var _ink: ShaderMaterial
var _glow_core: GradientTexture2D
var _glow_rim: GradientTexture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_materials[Mode.NORMAL] = null
	for pair in [[Mode.ADD, ADD_SHADER], [Mode.TINT, TINT_SHADER], [Mode.INK, INK_SHADER]]:
		var material := ShaderMaterial.new()
		material.shader = pair[1]
		_materials[pair[0]] = material
	_ink = _materials[Mode.INK]
	_pixels = ClassDB.instantiate(&"SpeedPixelFx")
	_confetti = ClassDB.instantiate(&"SpeedPixelFx")
	_build_hex_grid()
	_glow_core = _radial_texture([[0.0, 0.9], [0.25, 0.0]])
	_glow_rim = _radial_texture([[0.0, 0.0], [0.25, 0.5], [1.0, 0.0]])
	reset()

func _exit_tree() -> void:
	for rid in _items: RenderingServer.free_rid(rid)
	_items.clear()

func reset() -> void:
	_screen = {}
	_chain = {}
	_hold_t = 0.0
	_pick_t = -1.0
	_cards.clear()
	_shard_snap = null
	for list in [_shakes, _timers, _streaks, _rings, _bits, _flares]: list.clear()
	_flash = 0.0
	_crt = 0.0
	_celebrating = false
	_fw_acc = 0.0
	_cf_acc = 0.0
	_tw_acc = 0.0
	_rng.seed = 5
	_wig_rng.seed = 31
	if _pixels != null: _pixels.configure(int(W), int(H), 3, PackedColorArray([WHITE, Color("#fff6c4"), Color("#ffe066"), Color("#f0b424")]))
	if _confetti != null: _confetti.configure(320, 180, 11, PackedColorArray([WHITE]))
	position = Vector2.ZERO

## 連鎖を始める。step 1 は3択の写しを閉じ、2 は前の継続画面を閉じ、3 は shard_snapshot を割る。
func begin(step: int, card: Texture2D, shard_snapshot: Texture2D = null) -> void:
	_cards[step] = card
	if step == 1:
		_screen = {kind = &"select"}
		_pick_t = 0.0
		_chain = {step = 0, phase = &"wait", t = 0.0}
		_later(PICK_DELAY, func(): _start_chain(1))
		return
	_shard_snap = shard_snapshot
	if _screen.is_empty(): _screen = {kind = &"reward", step = step - 1, card_t = 9.0}
	_start_chain(step)

## 止まって次のクリックを待っているか。
func is_holding() -> bool:
	return not _chain.is_empty() and _chain.phase == &"hold"

func _start_chain(step: int) -> void:
	_chain = {step = step, t = 0.0, phase = &"play", landed = false, fired = {}, shards = {}}
	if step == 3:
		_chain.shards = _make_shards(CX, CY)
		_screen = {kind = &"reward", step = 3, card_t = -1.0}

func _later(delay: float, fn: Callable) -> void:
	_timers.append({at = _time + delay, fn = fn})

func _process(delta: float) -> void:
	if _screen.is_empty(): return
	var dt := minf(delta, 0.05)
	_time += dt
	for i in range(_timers.size() - 1, -1, -1):
		if _time >= _timers[i].at:
			var fn: Callable = _timers[i].fn
			_timers.remove_at(i)
			fn.call()
	if _pick_t >= 0.0: _pick_t += dt
	if not _chain.is_empty() and _chain.phase == &"play":
		_chain.t += dt
		var s: int = _chain.step
		var t: float = _chain.t
		if s < 3:
			if _screen.kind == &"select" or _screen.step != s:
				if t >= TR[s].close:
					_screen = {kind = &"reward", step = s, card_t = -1.0}
					_crt = 0.12
					_shake(2.0, 0.1)
			if t >= CARD_AT[s]: _screen.card_t = t - CARD_AT[s]
		else:
			if t >= CARD_AT[3]: _screen.card_t = t - CARD_AT[3]
			if t >= CRACK and not _chain.fired.has("burst"):
				_chain.fired.burst = true
				_do_flash(0.95)
				_shake(SHAKE[3], 0.45)
			if t < CRACK and not _chain.fired.has("crk"):
				_chain.fired.crk = true
				_shake(3.0, CRACK)
		if not _chain.landed and _screen.kind == &"reward" and _screen.step == s and _screen.card_t >= APPROACH[s]:
			_chain.landed = true
			_on_land(s)
		var done_t: float = 1.6 if s == 3 else TR[s].open1
		if t >= done_t and _screen.card_t > APPROACH[s] + 0.45:
			_chain.phase = &"hold"
			_hold_t = 0.0
			settled.emit()
	elif not _chain.is_empty() and _chain.phase == &"hold":
		_hold_t += delta
		if _screen.kind == &"reward": _screen.card_t += dt
	if _screen.kind == &"reward" and not _chain.is_empty() and _chain.get("landed", false): _hold_tick(dt, _screen.step)
	if _celebrating: _celebrate_tick(dt)
	_redraw(dt)

# ---- 描画の順番 ----

func _begin_draw() -> void:
	for rid in _items: RenderingServer.canvas_item_clear(rid)
	_used = 0
	_mode = -1
	_xf = Transform2D.IDENTITY

func _use(mode: int) -> void:
	if mode == _mode and _used > 0: return
	if _used == _items.size():
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, get_canvas_item())
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		_items.append(rid)
	_item = _items[_used]
	RenderingServer.canvas_item_set_draw_index(_item, _used)
	var material: Material = _materials[mode]
	RenderingServer.canvas_item_set_material(_item, material.get_rid() if material != null else RID())
	_used += 1
	_mode = mode
	if _xf != Transform2D.IDENTITY: RenderingServer.canvas_item_add_set_transform(_item, _xf)

func _set_xf(xf: Transform2D) -> void:
	_xf = xf
	if _used > 0: RenderingServer.canvas_item_add_set_transform(_item, xf)

func _rect(mode: int, r: Rect2, c: Color) -> void:
	_use(mode)
	RenderingServer.canvas_item_add_rect(_item, r, c)

func _poly(mode: int, pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3: return
	_use(mode)
	RenderingServer.canvas_item_add_polygon(_item, pts, PackedColorArray([c]))

func _tri(mode: int, pts: PackedVector2Array, colors: PackedColorArray) -> void:
	_use(mode)
	RenderingServer.canvas_item_add_polygon(_item, pts, colors)

## Canvas2D の stroke。blur>0 は shadowBlur の光をにじませた線の束で近づける。
func _stroke(mode: int, pts: PackedVector2Array, c: Color, width: float, closed := false, blur := 0.0, blur_color := Color(0, 0, 0, 0)) -> void:
	if pts.size() < 2: return
	_use(mode)
	var line := pts.duplicate()
	if closed: line.append(pts[0])
	if blur > 0.0:
		var glow := blur_color if blur_color.a > 0.0 else c
		# 標準偏差 blur/2 のぼかしを、幅を少しずつ広げた薄い線の重なりで近づける（中心の濃さ≒幅/(σ√2π)）
		var s := blur * 0.5
		var a := minf(1.0, 0.4 * width / s) / 6.0
		for k in 6:
			RenderingServer.canvas_item_add_polyline(_item, line, PackedColorArray([Color(glow, glow.a * a)]), width + s * (k + 1) * 0.8, true)
	RenderingServer.canvas_item_add_polyline(_item, line, PackedColorArray([c]), width, true)

func _texture(mode: int, tex: Texture2D, dst: Rect2, src: Rect2, c := WHITE) -> void:
	if tex == null: return
	_use(mode)
	RenderingServer.canvas_item_add_texture_rect_region(_item, dst, tex.get_rid(), src, c)

## textBaseline = middle・textAlign = center の文字。
func _text(mode: int, text: String, at: Vector2, size: int, c: Color, bold := false, glow := 0.0, glow_color := Color(0, 0, 0, 0)) -> void:
	var f: Font = bold_font if bold and bold_font != null else font
	if f == null: return
	_use(mode)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(at.x - w * 0.5, at.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5)
	if glow > 0.0:
		for k in [2, 1]:
			f.draw_string_outline(_item, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(glow * 0.5 * k), Color(glow_color, 0.22))
	f.draw_string(_item, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

## createRadialGradient を扇形の頂点色で描く。stops は [位置, 色] の並び。
func _radial(mode: int, center: Vector2, radius: float, stops: Array) -> void:
	_use(mode)
	var seg := 40
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	pts.append(center)
	cols.append(stops[0][1])
	var prev_ring := -1
	for s in stops:
		if s[0] <= 0.0: continue
		var ring := pts.size()
		for i in seg:
			var a := TAU * i / seg
			pts.append(center + Vector2(cos(a), sin(a)) * radius * s[0])
			cols.append(s[1])
		for i in seg:
			var j := (i + 1) % seg
			if prev_ring < 0:
				idx.append_array([0, ring + i, ring + j])
			else:
				idx.append_array([prev_ring + i, ring + i, ring + j, prev_ring + i, ring + j, prev_ring + j])
		prev_ring = ring
	RenderingServer.canvas_item_add_triangle_array(_item, idx, pts, cols)

## 中心から縁までの濃さ（alpha）を持つ白い放射グラデーション。
func _radial_texture(stops: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	gradient.colors = PackedColorArray(stops.map(func(s): return Color(WHITE, s[1])))
	if stops[-1][0] < 1.0:
		gradient.add_point(1.0, Color(WHITE, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex

func _redraw(dt: float) -> void:
	_begin_draw()
	var off := Vector2.ZERO
	for s in _shakes:
		s.t += dt
		var k := maxf(0.0, 1.0 - s.t / s.dur)
		off += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s.amp * k * k
	for i in range(_shakes.size() - 1, -1, -1):
		if _shakes[i].t >= _shakes[i].dur: _shakes.remove_at(i)
	off = off.round()
	# 揺れでずれた分の縁は試作と同じく黒
	if off != Vector2.ZERO:
		for r in [Rect2(0, 0, W, maxf(0, off.y)), Rect2(0, H + minf(0, off.y), W, -minf(0, off.y)), Rect2(0, 0, maxf(0, off.x), H), Rect2(W + minf(0, off.x), 0, -minf(0, off.x), H)]:
			if r.size.x > 0 and r.size.y > 0: _rect(Mode.NORMAL, r, Color.BLACK)
	_set_xf(Transform2D(0, off))
	_draw_screen()
	if not _chain.is_empty() and _chain.phase == &"play" and _chain.step == 3: _draw_shatter(_chain.t)
	if not _chain.is_empty() and _chain.phase == &"play" and _chain.step in [1, 2]: _draw_aperture(_chain.step, _chain.t)
	_draw_fx(dt)
	_draw_pixels(dt)
	if _crt > 0.0:
		var u := _crt / 0.12
		var h := maxf(1.0, 10.0 * u * u)
		_use(Mode.ADD)
		for k in [3.0, 1.8]:
			_rect(Mode.ADD, Rect2(-20 - k * 4, CY - h / 2 - k * 4, W + 40 + k * 8, h + k * 8), Color(NEON, 0.06 * u))
		_rect(Mode.ADD, Rect2(-20, CY - h / 2, W + 40, h), Color(WHITE, u))
		_rect(Mode.ADD, Rect2(CX - 200 * u, CY - h * 2, 400 * u, h * 4), Color(NEON, 0.6 * u))
		_crt -= dt
	if _flash > 0.0:
		_rect(Mode.NORMAL, Rect2(-20, -20, W + 40, H + 40), Color(_flash_col, minf(1.0, _flash)))
		_flash = maxf(0.0, _flash - dt * 4.5)

# ---- 画面 ----

func _draw_screen() -> void:
	if _screen.kind == &"select":
		# カード3択の写し。選んだカードは0.12秒だけ山型に弾み、明るく光る
		_texture(Mode.NORMAL, select_snapshot, Rect2(0, 0, W, H), Rect2(0, 0, W, H))
		if picked_rect.size.x > 0.0:
			var u := minf(1.0, _pick_t / 0.12)
			var punch := sin(PI * u) if _pick_t < 0.12 else 0.0
			var c := picked_rect.get_center()
			var sz := picked_rect.size * Vector2((1 + 0.2 * punch) * (1 + 0.12 * punch), (1 + 0.2 * punch) * (1 - 0.08 * punch))
			var dst := Rect2(c - sz * 0.5, sz)
			_texture(Mode.NORMAL, select_snapshot, dst, picked_rect)
			_texture(Mode.TINT, select_snapshot, dst, picked_rect, Color(WHITE, 0.35))
		return
	_rect(Mode.NORMAL, Rect2(0, 0, W, H), Color(4 / 255.0, 7 / 255.0, 14 / 255.0, 0.62))
	_text(Mode.NORMAL, heading, Vector2(320, 26), 10, SUB)
	for r in [Rect2(250, 25, 14, 1), Rect2(376, 25, 14, 1), Rect2(248, 23, 2, 5), Rect2(390, 23, 2, 5)]: _rect(Mode.NORMAL, r, CYAN)
	var step: int = _screen.step
	var pose := _card_pose(step, _screen.card_t)
	var tier: Color = TIER[step]
	if pose.landed:
		var grow := minf(1.0, pose.k / 0.25)
		if step >= 2: _draw_rays(step, grow)
		_draw_orbit(step, grow)
		_draw_wiggle(pose, tier)
	if _screen.card_t >= 0.0 and _screen.card_t < APPROACH[step] + 0.06:
		for i in range(4, 0, -1):
			var gp := _card_pose(step, _screen.card_t - i * 0.024)
			if gp.scale > 0.001: _draw_card(step, gp.scale, gp.rot, 0.32 * (1 - i / 5.0), 1, 1, 0, 0, NEON if i % 2 else MAG)
	var glitch: float = 1.0 - pose.k / 0.14 if pose.landed and pose.k < 0.14 else 0.0
	var bright: float = maxf(0.0, 0.8 - pose.k * 5) if pose.landed else 0.0
	_draw_card(step, pose.scale, pose.rot, pose.alpha, 1 + pose.sq, 1 - pose.sq, glitch, bright)
	if pose.landed:
		_draw_label(step, pose.k, tier)
		if is_holding() and int(floor(_hold_t * 2)) % 2 == 0:
			_text(Mode.NORMAL, hint, Vector2(320, 330), 10, CYAN)

func _draw_card(step: int, scale: float, rot: float, alpha: float, sx := 1.0, sy := 1.0, glitch := 0.0, bright := 0.0, ghost := Color(0, 0, 0, 0)) -> void:
	var tex: Texture2D = _cards.get(step)
	if tex == null or scale <= 0.001 or alpha <= 0.0: return
	var base := _xf
	_set_xf(base * Transform2D(rot, Vector2(scale * sx, scale * sy), 0, Vector2(CX, CY)))
	var full := Rect2(0, 0, 145, 193)
	var at := Rect2(-72.5, -96.5, 145, 193)
	if ghost.a > 0.0:
		_texture(Mode.TINT, tex, at, full, Color(ghost, alpha))
		_set_xf(base)
		return
	if glitch > 0.0:
		var d := glitch * 7.0
		_texture(Mode.TINT, tex, Rect2(at.position - Vector2(d, 0), at.size), full, Color(MAG, alpha * 0.55 * glitch))
		_texture(Mode.TINT, tex, Rect2(at.position + Vector2(d, 0), at.size), full, Color(NEON, alpha * 0.55 * glitch))
		for i in 9:
			var y0 := floorf(193.0 / 9 * i)
			var h := ceilf(193.0 / 9) + 1
			var off: float = (randf() - 0.5) * glitch * 26 if randf() < 0.5 else 0.0
			_texture(Mode.NORMAL, tex, Rect2(-72.5 + off, -96.5 + y0, 145, h), Rect2(0, y0, 145, h), Color(WHITE, alpha))
	else:
		_texture(Mode.NORMAL, tex, at, full, Color(WHITE, alpha))
	if bright > 0.0: _texture(Mode.TINT, tex, at, full, Color(WHITE, alpha * bright))
	_set_xf(base)

func _draw_label(step: int, k: float, tier: Color) -> void:
	var u := minf(1.0, k / 0.12)
	var off: float = 60 * (1 - u) * (1 - u)
	var pop: float = 1 + 0.4 * sin(PI * minf(1.0, k / 0.24)) if k < 0.24 else 1.0
	var sep: float = 8 * maxf(0.0, 1 - k / 0.3) + (3.0 if randf() < 0.04 else 0.0)
	var text := count_format.format({n = step + 1})
	var size := 16 + step * 2
	var base := _xf
	_set_xf(base * Transform2D(0, Vector2(pop, pop), 0, Vector2(320 + off, 293)))
	_text(Mode.ADD, text, Vector2(-sep, 0), size, Color(MAG, 0.7 * u), true)
	_text(Mode.ADD, text, Vector2(sep, 0), size, Color(NEON, 0.7 * u), true)
	_text(Mode.NORMAL, text, Vector2.ZERO, size, Color(tier, u), true, 10 + step * 4, tier)
	_set_xf(base)

func _spring(k: float) -> float:
	var w := FREQ * TAU
	var wd := w * sqrt(1 - DAMPING * DAMPING)
	return exp(-DAMPING * w * k) * sin(wd * k)

func _card_pose(step: int, t: float) -> Dictionary:
	if t < 0.0: return {scale = 0.0, rot = 0.0, alpha = 0.0, landed = false, sq = 0.0, k = 0.0}
	var l: float = APPROACH[step]
	if t < l:
		var u := t / l
		var scale := START_SCALE + (1 - START_SCALE) * pow(u, 2.4)
		var rot: float = SPIN_TURNS * TAU * (1 - u) * (1 - u * 0.3) if step == 2 else 0.35 * (1 - u) if step == 3 else 0.0
		return {scale = scale, rot = rot, alpha = minf(1.0, t / 0.03), landed = false, sq = 0.0, k = 0.0}
	var k := t - l
	return {scale = maxf(0.0, 1 + BOUNCE * _spring(k)), rot = -0.18 * _spring(k) if step == 2 else 0.0, alpha = 1.0, landed = true,
		sq = SQUASH * exp(-14 * k) * cos(TAU * 7 * k), k = k}

func _draw_orbit(step: int, grow: float) -> void:
	var cols := [NEON, GOLD, MAG]
	for i in step:
		var breath := 3 * sin(_time * 4 - i * 0.9)
		var fly := (1 - grow) * (60 + i * 30)
		var hw := 104 + i * 14 + breath + fly
		var hh := 126 + i * 14 + breath + fly
		var l := 14.0 + i * 4
		var c: Color = cols[i]
		var a := (0.9 - i * 0.15) * grow
		for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var pts := PackedVector2Array([Vector2(CX + s.x * hw, CY + s.y * (hh - l)), Vector2(CX + s.x * hw, CY + s.y * hh), Vector2(CX + s.x * (hw - l), CY + s.y * hh)])
			_stroke(Mode.ADD, pts, Color(c, a), 2, false, 8)
		for r in [Rect2(CX - 4, CY - hh - 1, 8, 2), Rect2(CX - 4, CY + hh - 1, 8, 2), Rect2(CX - hw - 1, CY - 4, 2, 8), Rect2(CX + hw - 1, CY - 4, 2, 8)]:
			_rect(Mode.ADD, r, Color(c, a))

func _draw_rays(step: int, grow: float) -> void:
	var n: int = 18 if step == 3 else 12
	var cols: Array = [NEON, GOLD, MAG] if step == 3 else [GOLD, Color("#fff6c4")]
	for i in n:
		var a := float(i) / n * TAU + _time * 0.35 * (-1.0 if step == 3 else 1.0)
		var w := 0.07 + 0.03 * sin(_time * 3 + i)
		var length := 520 * grow
		var c: Color = cols[i % cols.size()]
		_tri(Mode.ADD, PackedVector2Array([Vector2(CX, CY), Vector2(CX, CY) + Vector2(cos(a - w), sin(a - w)) * length, Vector2(CX, CY) + Vector2(cos(a + w), sin(a + w)) * length]),
			PackedColorArray([Color(c, 0.35 * grow), Color(c, 0.0), Color(c, 0.0)]))

func _wig_offsets() -> Array:
	var out := []
	for i in WIG_BASE.size(): out.append(Vector2(_wig_rng.randf_range(-1, 1), _wig_rng.randf_range(-1, 1)))
	return out

func _draw_wiggle(pose: Dictionary, c: Color) -> void:
	var period := 0.09
	if not _screen.has("wig"): _screen.wig = {from = _wig_offsets(), to = _wig_offsets(), t = 0.0, last = _time}
	var w: Dictionary = _screen.wig
	w.t += _time - w.last
	w.last = _time
	while w.t >= period:
		w.t -= period
		w.from = w.to
		w.to = _wig_offsets()
	var u: float = w.t / period
	var k: float = pose.k
	var grow: float = 0.6 + 0.4 * (k / 0.16) + 0.3 * sin(PI * k / 0.16) if k < 0.16 else 1.0
	var pts := PackedVector2Array()
	for i in WIG_BASE.size():
		pts.append(WIG_BASE[i] + (w.from[i] + (w.to[i] - w.from[i]) * u) * WIGGLE)
	var base := _xf
	var s: float = pose.scale * grow
	var xf := base * Transform2D(-0.06 + pose.rot, Vector2(s, s), 0, Vector2(CX, CY))
	_set_xf(xf)
	_poly(Mode.NORMAL, pts, Color(6 / 255.0, 20 / 255.0, 38 / 255.0, 0.85))
	_set_xf(xf * Transform2D(0, Vector2(5, 5)))
	_stroke(Mode.NORMAL, pts, Color(MAG, 0.7), 2, true)
	_set_xf(xf)
	_stroke(Mode.NORMAL, pts, c, 2.5, true, 12)
	_set_xf(base)

# ---- Iris・Star Iris ----

func _aperture_r(step: int, t: float) -> float:
	var tr: Dictionary = TR[step]
	if t < tr.close: return tr.full * (1 - pow(t / tr.close, 1.7))
	if t < tr.open0: return 0.0
	var u := minf(1.0, (t - tr.open0) / (tr.open1 - tr.open0))
	return tr.full * (1 - pow(1 - u, 4))

func _shape(step: int, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if step == 1:
		for i in 64: pts.append(Vector2(CX, CY) + Vector2(cos(TAU * i / 64), sin(TAU * i / 64)) * r)
		return pts
	for i in 10:
		var a := rot - PI / 2 + float(i) / 10 * TAU
		var rr: float = r * 0.44 if i % 2 else r
		pts.append(Vector2(CX + cos(a) * rr, CY + sin(a) * rr))
	return pts

func _draw_aperture(step: int, t: float) -> void:
	var tr: Dictionary = TR[step]
	if t > tr.open1: return
	var r := _aperture_r(step, t)
	var rot: float = (t * 3 if t < tr.open0 else tr.open0 * 3 - (t - tr.open0) * 2.5) if step == 2 else 0.0
	_ink.set_shader_parameter("radius", r)
	_ink.set_shader_parameter("rotation", rot)
	_ink.set_shader_parameter("star", step == 2)
	_ink.set_shader_parameter("center", Vector2(CX, CY))
	_ink.set_shader_parameter("origin", Vector2(-40, -40))
	_ink.set_shader_parameter("canvas_size", Vector2(W + 80, H + 80))
	_use(Mode.INK)
	RenderingServer.canvas_item_add_rect(_item, Rect2(-40, -40, W + 80, H + 80), WHITE)
	if r < 1: return
	var c := NEON if step == 1 else GOLD
	var sub := MAG if step == 1 else NEON
	_stroke(Mode.ADD, _shape(step, r, rot), c, 3, true, 14)
	_stroke(Mode.ADD, _shape(step, r + 9, -rot * 1.3 if step == 2 else 0.0), Color(sub, 0.8), 1.2, true)
	var ticks := 24
	for i in ticks:
		var a := float(i) / ticks * TAU + t * 2
		var r1 := r + 18
		var r2: float = r1 + (5 if i % 3 else 11)
		_stroke(Mode.ADD, PackedVector2Array([Vector2(CX + cos(a) * r1, CY + sin(a) * r1), Vector2(CX + cos(a) * r2, CY + sin(a) * r2)]), Color(c, 0.9), 2)

# ---- Shatter ----

func _make_shards(ix: float, iy: float) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = 21
	var nr := 15
	var ring := [0, 18, 44, 82, 132, 200, 290, 420, 620]
	var v := []
	for i in nr:
		var a := (i + r.randf_range(-0.32, 0.32)) / nr * TAU
		var row := []
		for j in ring.size():
			if j == 0:
				row.append(Vector2(ix, iy))
				continue
			var rr: float = ring[j] * r.randf_range(0.85, 1.15)
			var aa := a + r.randf_range(-0.08, 0.08)
			row.append(Vector2(ix + cos(aa) * rr, iy + sin(aa) * rr))
		v.append(row)
	var shards := []
	var cracks := []
	for i in nr:
		var i2 := (i + 1) % nr
		var j := 0
		while j < ring.size() - 1:
			var jb: int = j + (2 if j >= 2 and r.randf() < 0.45 else 1)
			jb = mini(jb, ring.size() - 1)
			var pts := PackedVector2Array([v[i][0], v[i][jb], v[i2][jb]]) if j == 0 else PackedVector2Array([v[i][j], v[i][jb], v[i2][jb], v[i2][j]])
			var c := Vector2.ZERO
			for p in pts: c += p
			c /= pts.size()
			if c.x > -80 and c.y > -80 and c.x < W + 80 and c.y < H + 80:
				var d := maxf(c.distance_to(Vector2(ix, iy)), 1.0)
				var dir := (c - Vector2(ix, iy)) / d
				var sp := r.randf_range(300, 700) * (1.25 - minf(1.0, d / 520) * 0.6)
				var col: Color = MAG if r.randf() < 0.3 else GOLD if r.randf() < 0.3 else NEON
				shards.append({pts = pts, c = c, v = Vector2(dir.x * sp, dir.y * sp - r.randf_range(40, 160)), va = r.randf_range(-8, 8), vz = r.randf_range(0.3, 1.1), delay = d / 2600, col = col})
			j = jb
		cracks.append(v[i])
	return {shards = shards, cracks = cracks, i = Vector2(ix, iy)}

func _build_hex_grid() -> void:
	var s := 18.0
	var hw := s * sqrt(3.0)
	for row in range(-1, int(H / (s * 1.5)) + 2):
		for col in range(-1, int(W / hw) + 2):
			var x: float = col * hw + (hw / 2 if row % 2 else 0.0)
			var y := row * s * 1.5
			for i in 6:
				var a0 := PI / 6 + i * PI / 3
				var a1 := PI / 6 + (i + 1) * PI / 3
				_hex_lines.append(Vector2(x + cos(a0) * s, y + sin(a0) * s))
				_hex_lines.append(Vector2(x + cos(a1) * s, y + sin(a1) * s))

func _draw_shatter(t: float) -> void:
	var sh: Dictionary = _chain.shards
	var snap := _shard_snap
	var at: Vector2 = sh.i
	if t < CRACK:
		var u := t / CRACK
		var y := 0
		while y < H:
			var h := 6 + randi() % 22
			var off: float = (randf() - 0.5) * 22 * u if randf() < 0.35 else 0.0
			_texture(Mode.NORMAL, snap, Rect2(off, y, W, h), Rect2(0, y, W, h))
			y += h
		for line in sh.cracks:
			var reach := u * 700
			var pts := PackedVector2Array([line[0]])
			for k in range(1, line.size()):
				var a: Vector2 = line[k - 1]
				var b: Vector2 = line[k]
				var da := a.distance_to(at)
				var db := b.distance_to(at)
				if db <= reach: pts.append(b)
				else:
					pts.append(a + (b - a) * maxf(0.0, (reach - da) / (db - da)))
					break
			_stroke(Mode.ADD, pts, NEON, 1.6, false, 8)
		_radial(Mode.NORMAL, at, 40 + u * 70, [[0.0, Color(WHITE, 0.85 * u)], [1.0, Color(NEON, 0.0)]])
		return
	var k := t - CRACK
	var glow := maxf(0.0, 1 - k / 0.55)
	if glow > 0.0:
		_radial(Mode.NORMAL, at, 440, [[0.0, Color(WHITE, 0.9 * glow)], [0.3, Color(NEON, 0.4 * glow)], [0.7, Color(MAG, 0.18 * glow)], [1.0, Color(MAG, 0.0)]])
		_use(Mode.ADD)
		RenderingServer.canvas_item_add_multiline(_item, _hex_lines, PackedColorArray([Color(NEON, 0.35 * glow)]), 1.0)
	var base := _xf
	for s in sh.shards:
		var a := maxf(0.0, k - s.delay)
		var mv: Vector2 = s.v * a + Vector2(0, 0.5 * 1300 * a * a)
		var rot: float = s.va * a
		var z: float = 1 + s.vz * a
		var alpha := 1 - maxf(0.0, (a - 0.7) / 0.45)
		if alpha <= 0.0: continue
		var c: Vector2 = s.c
		_set_xf(base * Transform2D(rot, Vector2(z, z), 0, c + mv) * Transform2D(0, -c))
		var uvs := PackedVector2Array()
		for p in s.pts: uvs.append(p / Vector2(W, H))
		_use(Mode.NORMAL)
		if snap != null: RenderingServer.canvas_item_add_polygon(_item, s.pts, PackedColorArray([Color(WHITE, alpha)]), uvs, snap.get_rid())
		_poly(Mode.NORMAL, s.pts, Color(s.col, (0.1 + 0.12 * (0.5 + 0.5 * sin(rot * 2 + c.x))) * alpha))
		_stroke(Mode.ADD, s.pts, Color(s.col, 0.35 * alpha), 4, true)
		_stroke(Mode.ADD, s.pts, Color(s.col, alpha), 1.3, true)
	_set_xf(base)

# ---- 演出の部品 ----

func _shake(amp: float, dur := 0.28) -> void:
	_shakes.append({t = 0.0, amp = amp, dur = dur})

func _do_flash(a: float, c := WHITE) -> void:
	if a >= _flash:
		_flash = a
		_flash_col = c

func _ring(kind: StringName, c: Color, delay := 0.0, life := 0.42, reach := 1.0, width := 5.0) -> void:
	_later(delay, func(): _rings.append({kind = kind, col = c, t = 0.0, life = life, reach = reach, w = width}))

func _spawn_bits(n: int, cols: Array, speed := 1.0) -> void:
	for i in n:
		var a := _rng.randf_range(0, TAU)
		var v := _rng.randf_range(250, 760) * speed
		var life := _rng.randf_range(0.25, 0.6)
		var w := _rng.randf_range(1, 2.5)
		_bits.append({p = Vector2(CX + cos(a) * 70, CY + sin(a) * 90), v = Vector2(cos(a), sin(a)) * v, t = 0.0, life = life, col = cols[i % cols.size()], w = w})

func _flare(at: Vector2, size: float, c: Color, delay := 0.0, life := 0.5) -> void:
	_later(delay, func(): _flares.append({p = at, size = size, col = c, t = 0.0, life = life, rot = _rng.randf()}))

func _burst_stars(n: int, cols: Array) -> void:
	if _pixels == null: return
	for i in n:
		var a := _rng.randf_range(0, TAU)
		var ex := cos(a) * 80
		var ey := sin(a) * 104
		var v := _rng.randf_range(90, 460)
		var at := Vector2(CX + ex * _rng.randf_range(0.6, 1), CY + ey * _rng.randf_range(0.6, 1))
		var life := _rng.randf_range(0.5, 1.4)
		var size := _rng.randf_range(1, 3.4)
		_pixels.spawn(P_STAR, at, Vector2(cos(a) * v, sin(a) * v - 30), life, Color(cols[i % cols.size()]), size)
	for i in n / 3:
		var a := _rng.randf_range(0, TAU)
		var v := _rng.randf_range(200, 560)
		var life := _rng.randf_range(0.2, 0.45)
		_pixels.spawn(P_SPARK, Vector2(CX + cos(a) * 60, CY + sin(a) * 80), Vector2(cos(a), sin(a)) * v, life, WHITE, 1.0)

func _on_land(step: int) -> void:
	var center := Vector2(CX, CY)
	if step == 1:
		_shake(SHAKE[1], 0.24)
		_do_flash(0.35, Color(127 / 255.0, 243 / 255.0, 1))
		_ring(&"rect", NEON)
		_ring(&"rect", WHITE, 0.06, 0.42, 0.7, 3)
		_ring(&"circle", MAG, 0.03, 0.42, 1.3)
		_spawn_bits(80, [WHITE, NEON, CYAN])
		_burst_stars(60, ["#ffffff", "#9bdcff", "#7ff3ff"])
		for o in [Vector2(-78, -100), Vector2(78, 100)]: _flare(center + o, 26, NEON, 0.04)
	if step == 2:
		_shake(SHAKE[2], 0.3)
		_do_flash(0.55, Color(1, 236 / 255.0, 170 / 255.0))
		_ring(&"rect", GOLD)
		_ring(&"star", WHITE, 0.04, 0.55, 1.6)
		_ring(&"rect", NEON, 0.1, 0.42, 0.8, 3)
		_ring(&"circle", GOLD, 0.16, 0.6, 1.8)
		_spawn_bits(120, [WHITE, GOLD, Color("#fff6c4"), NEON], 1.15)
		_burst_stars(roundi(STARS * 0.5), STAR_COLS)
		_later(0.1, func(): _burst_stars(roundi(STARS * 0.3), STAR_COLS))
		_later(0.22, func(): _burst_stars(roundi(STARS * 0.2), STAR_COLS))
		var spots := [Vector2(-92, -112), Vector2(96, -96), Vector2(104, 70), Vector2(-100, 92), Vector2(0, -130), Vector2(0, 124)]
		for i in spots.size(): _flare(center + spots[i], 48 if i < 4 else 34, Color("#fff6c4") if i % 2 else GOLD, 0.03 + i * 0.05, 0.6)
		_flare(center, 120, WHITE, 0.0, 0.35)
	if step == 3:
		_shake(SHAKE[3] * 0.6, 0.25)
		_do_flash(0.4)
		_ring(&"rect", WHITE)
		_ring(&"rect", NEON, 0.05, 0.42, 1.0, 4)
		_ring(&"rect", GOLD, 0.1, 0.42, 1.0, 4)
		_ring(&"rect", MAG, 0.15, 0.42, 1.0, 4)
		_ring(&"star", GOLD, 0.06, 0.6, 1.8)
		_ring(&"circle", NEON, 0.12, 0.7, 2.2)
		_spawn_bits(180, [WHITE, NEON, GOLD, MAG], 1.3)
		_burst_stars(roundi(STARS * 0.6), NEON_COLS)
		_later(0.15, func(): _burst_stars(roundi(STARS * 0.4), STAR_COLS))
		var spots := [Vector2(-96, -110), Vector2(96, -110), Vector2(110, 0), Vector2(96, 110), Vector2(-96, 110), Vector2(-110, 0), Vector2(0, -134), Vector2(0, 130)]
		var cols := [NEON, GOLD, MAG, WHITE]
		for i in spots.size(): _flare(center + spots[i], 50, cols[i % 4], 0.03 + i * 0.04, 0.65)
		_flare(center, 150, WHITE, 0.0, 0.4)
		_celebrating = true
		_fw_acc = FIRE_EVERY
		_cf_acc = CONFETTI_EVERY

func _palette(list: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for c in list: out.append(Color(c))
	return out

## 4連続は花火と紙吹雪をクリックまで出し続ける。
func _celebrate_tick(dt: float) -> void:
	if _pixels == null: return
	_fw_acc += dt
	_cf_acc += dt
	while _fw_acc >= FIRE_EVERY:
		_fw_acc -= FIRE_EVERY
		_fw_seed += 1
		var x := _rng.randf_range(70, 570)
		var y := _rng.randf_range(40, 170)
		if absf(x - CX) < 90 and y > 70: continue
		_pixels.add_firework(Vector2(x, y), _fw_seed, _palette(FW_PALS[_fw_seed % 4]), _palette(FW_PALS[(_fw_seed + 2) % 4]))
	while _cf_acc >= CONFETTI_EVERY:
		_cf_acc -= CONFETTI_EVERY
		_cf_side ^= 1
		_fw_seed += 1
		_confetti.add_confetti(Vector2(280 if _cf_side else 40, 192), 11 + _fw_seed, _cf_side == 1, _palette(CONF_PAL))

func _hold_tick(dt: float, step: int) -> void:
	_tw_acc += dt
	var rate: float = 6.0 if step == 1 else 16.0 if step == 2 else 26.0
	while _tw_acc >= 1.0 / rate:
		_tw_acc -= 1.0 / rate
		var a := _rng.randf_range(0, TAU)
		var rx := _rng.randf_range(95, 200)
		var ry := _rng.randf_range(110, 160)
		var cols: Array = [NEON, WHITE] if step == 1 else [GOLD, Color("#fff6c4"), WHITE] if step == 2 else [NEON, GOLD, MAG, WHITE]
		var size: float = _rng.randf_range(8, 14.0 if step == 1 else 22.0)
		var c: Color = cols[int(floor(_rng.randf() * cols.size()))]
		var life := _rng.randf_range(0.4, 0.9)
		_flares.append({p = Vector2(CX + cos(a) * rx, CY + sin(a) * ry), size = size, col = c, t = 0.0, life = life, rot = _rng.randf()})

func _draw_fx(dt: float) -> void:
	var s: int = _screen.get("step", 0) if _screen.kind == &"reward" else 0
	if s > 0 and _screen.card_t >= 0.0 and _screen.card_t < APPROACH[s] + 0.12 and not _chain.is_empty() and _chain.phase == &"play":
		for i in 3 + s * 2:
			_streaks.append({a = _rng.randf_range(0, TAU), r = _rng.randf_range(40, 160), v = _rng.randf_range(1100, 2000), len = _rng.randf_range(40, 140), t = 0.0, life = 0.22, col = TIER[s] if _rng.randf() < 0.3 else WHITE})
	for k in _streaks:
		k.t += dt
		k.r += k.v * dt
		var a: float = 1 - k.t / k.life
		if a <= 0.0: continue
		var d := Vector2(cos(k.a), sin(k.a))
		_stroke(Mode.ADD, PackedVector2Array([Vector2(CX, CY) + d * k.r, Vector2(CX, CY) + d * (k.r + k.len)]), Color(k.col, 0.7 * a), 1.5)
	for r in _rings:
		r.t += dt
		var u: float = r.t / r.life
		if u >= 1.0: continue
		var e := 1 - pow(1 - u, 3)
		var sc: float = 1 + e * r.reach
		var a := 1 - u
		var pts: PackedVector2Array
		if r.kind == &"rect": pts = PackedVector2Array([Vector2(CX - 73 * sc, CY - 97 * sc), Vector2(CX + 73 * sc, CY - 97 * sc), Vector2(CX + 73 * sc, CY + 97 * sc), Vector2(CX - 73 * sc, CY + 97 * sc)])
		elif r.kind == &"circle": pts = _shape(1, 110 * sc, 0.0)
		else: pts = _shape(2, 120 * sc, u * 1.5)
		_stroke(Mode.ADD, pts, Color(r.col, a), r.w * a + 0.5, true, 10, r.col)
	for b in _bits:
		b.t += dt
		var drag := exp(-3.2 * dt)
		b.v = Vector2(b.v.x * drag, b.v.y * drag + 220 * dt)
		b.p += b.v * dt
		var a: float = 1 - b.t / b.life
		if a <= 0.0: continue
		_stroke(Mode.ADD, PackedVector2Array([b.p, b.p - b.v * 0.035]), Color(b.col, a), b.w)
	for f in _flares:
		f.t += dt
		var u: float = f.t / f.life
		if u >= 1.0: continue
		var k: float = u / 0.2 if u < 0.2 else 1 - (u - 0.2) / 0.8
		_draw_flare(f.p, f.size * (0.4 + 0.8 * k), f.col, k, f.rot + u * 1.2)
	for list in [_streaks, _rings, _bits, _flares]:
		for i in range(list.size() - 1, -1, -1):
			if list[i].t >= list[i].life: list.remove_at(i)

func _draw_flare(at: Vector2, size: float, c: Color, a: float, rot: float) -> void:
	if a <= 0.0 or size <= 0.0: return
	# 白0.9→色0.5（0.25）→0 の放射グラデーションを、白の山と色の山の2枚の和で描く
	var reach := size * 0.7
	var dst := Rect2(at - Vector2(reach, reach), Vector2(reach, reach) * 2)
	_texture(Mode.ADD, _glow_core, dst, Rect2(Vector2.ZERO, _glow_core.get_size()), Color(WHITE, a))
	_texture(Mode.ADD, _glow_rim, dst, Rect2(Vector2.ZERO, _glow_rim.get_size()), Color(c, a))
	var base := _xf
	_set_xf(base * Transform2D(rot * 0.3, at))
	for spec in [[size, size * 0.07, 0.0], [size * 0.5, size * 0.05, PI / 4]]:
		for q in 2:
			var r: float = spec[2] + q * PI / 2
			var l: float = spec[0]
			var w: float = spec[1]
			var x := Vector2(cos(r), sin(r))
			var y := Vector2(-sin(r), cos(r))
			_poly(Mode.ADD, PackedVector2Array([-x * l, -y * w, x * l, y * w]), Color(WHITE, a))
	_set_xf(base)

func _draw_pixels(dt: float) -> void:
	if _pixels == null: return
	_pixels.update(dt)
	if not _pixels.is_empty():
		_pixel_tex = _upload(_pixel_tex, _pixels.render(), int(W), int(H))
		_texture(Mode.NORMAL, _pixel_tex, Rect2(0, 0, W, H), Rect2(0, 0, W, H))
	_confetti.update(dt)
	if not _confetti.is_empty():
		_confetti_tex = _upload(_confetti_tex, _confetti.render(), 320, 180)
		_texture(Mode.NORMAL, _confetti_tex, Rect2(0, 0, W, H), Rect2(0, 0, 320, 180))

func _upload(tex: ImageTexture, bytes: PackedByteArray, w: int, h: int) -> ImageTexture:
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	if tex == null: return ImageTexture.create_from_image(image)
	tex.update(image)
	return tex
