extends WeaponVisual
## リアブラスター：背中の砲台。撃つたびに砲口の光と、横へ飛ぶ薬莢。当たり方はブラスターと同じ。
const BASE_PATH := "res://assets/pixel/airship_turret_base.png"
const TURRET_PATH := "res://assets/pixel/airship_turret.png"
var base: Texture2D
var turret: Texture2D
func setup(render: RunPresentation, owner_behavior) -> void:
	super(render,owner_behavior)
	base = load(BASE_PATH)
	turret = load(TURRET_PATH)
func draw_extra(c: CanvasItem, ship_pos: Vector2, color: Color) -> void:
	frame_extra(c,base,turret,ship_pos,state.ship_pos,state.ship_heading,behavior.mount_position(),behavior.aim_direction(),behavior.recoil,cfg.character_scale,visual_color(color))

static func frame_extra(c: CanvasItem, base_texture: Texture2D, turret_texture: Texture2D, ship_pos: Vector2, source_pos: Vector2, heading: Vector2, mount_pos: Vector2, aim: Vector2, recoil: float, scale: float, color: Color) -> void:
	if base_texture==null or turret_texture==null: return
	c.draw_set_transform(ship_pos,heading.angle()+PI/2.0)
	c.draw_texture_rect(base_texture,Rect2(Vector2(-base_texture.get_width()/2.0,-20.0)*scale,base_texture.get_size()*scale),false,color)
	var mount := mount_pos+(ship_pos-source_pos)
	if recoil>0.0: mount += heading*(2.0 if recoil>0.06 else 1.0)*1.82*scale
	c.draw_set_transform(mount,aim.angle()-PI/2.0)
	c.draw_texture_rect(turret_texture,Rect2(-Vector2(15.5,39.5)*scale,Vector2(31.0,70.0)*scale),false,color)
	c.draw_set_transform(Vector2.ZERO)

var flashes := ShotFlashes.new()
var shells: Array[Dictionary] = []

func on_event(ev: Dictionary) -> void:
	frame_event(flashes,shells,ev,state.ship_heading,behavior.mount_position())

static func frame_event(current: ShotFlashes, current_shells: Array[Dictionary], ev: Dictionary, heading: Vector2, mount: Vector2) -> void:
	if String(ev.get("visual_key", "")) != "weapon/rear": return
	if ev.type == &"weapon_fire":
		current.fire(float(ev.angle))
		var side := Vector2(-heading.y,heading.x)*(30.0+randf()*20.0)+Vector2(randf()-0.5,0.0)*10.0
		current_shells.append({"pos":mount,"vel":side,"age":0.0})
	elif ev.type == &"shot_hit": current.hit(ev.pos,ev.dir,2)

func tick(_dt: float) -> void:
	var p := painter()
	p.begin()
	frame_draw(flashes,shells,p,world_dt(),behavior.mount_position(),behavior.aim_direction(),active)
	p.end()

static func frame_draw(current: ShotFlashes, current_shells: Array[Dictionary], p: PixelPainter, dt: float, mount: Vector2, aim: Vector2, enabled: bool) -> void:
	if not enabled: return
	current.draw(p,dt,mount+aim*9.0*p.px)
	_shells(current_shells,p,dt)

## 薬莢：横へ飛び、毎秒0.05倍に減速しながら0.35秒で消える。明るい2ドットと暗い1ドットを交互に見せて回って見せる。
static func _shells(current_shells: Array[Dictionary], p: PixelPainter, dt: float) -> void:
	var damping := pow(0.05, dt)
	for s in current_shells:
		s.age += dt
		s.pos += s.vel * p.px * dt
		s.vel *= damping
		var frame := int(s.age * 30.0) % 2
		var c := Color("#ffd27a") if frame == 1 else Color("#b07a14")
		c.a = 1.0 - s.age / 0.35
		var cell := p.cell(s.pos)
		p.fill(cell.x, cell.y, c, 2 if frame == 1 else 1, 1)
	current_shells.assign(current_shells.filter(func(s): return s.age < 0.35))
