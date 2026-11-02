## じょうぎ座の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## じょうぎ座：照射の予告は、発射元から照射の向きへ伸びる点線。予告が進むほど濃く、先端の光が強まる。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var r := t.r[i]
	var u := Vector2.from_angle(t.facing[i])
	var tip: Vector2 = behavior.call(&"beam_origin", i)
	var col := t.color[i].lightened(0.2)
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		var k := t.charge[i]
		var length := float(t.def[i].params.beam_len)
		var dash := 36.0
		var s := 0.0
		while s < length:
			c.draw_line(tip + u * s, tip + u * minf(s + dash * 0.55, length), Color(col, 0.25 + 0.6 * k), maxf(_px(2.0), 3.0 + 4.0 * k))
			s += dash
		c.draw_circle(tip, r * (0.2 + 0.4 * k), Color(1, 1, 1, 0.4 + 0.5 * k))
	elif t.mode[i] == EnemyTable.Mode.DASH and t.buds[i] != 0:
		c.draw_circle(tip, r * 0.18, Color(col, 0.6))

## 元画像の共通キャンバスを重ね、分離後は buds の側だけを描く。
func draw_body(_c: CanvasItem, t: EnemyTable, i: int, pos: Vector2) -> bool:
	var type := t.type[i]
	var look := rm.look_of(type)
	if look == null or look.split_other == null:
		return false
	rm._ensure_enemy_batch(type)
	var lower_key := StringName(String(type) + "/lower")
	rm._ensure_enemy_batch(lower_key, look.split_other, type)
	var radius := sprite_radius(t, i)
	var color := Color(1.0 if t.flash[i] > 0.0 else 0.0, 0, 0, 1)
	for side in [-1, 1]:
		if t.buds[i] != 0 and t.buds[i] != side:
			continue
		var key: StringName = type if side == -1 else lower_key
		var part: EnemyLook = look if side == -1 else look.split_other
		var angle := t.facing[i] + part.angle
		rm._batches[key].add(pos, angle, radius, color)
		rm._armor_batches[key].add(pos, angle, radius, color)
	return true

static func draw_frame(c: CanvasItem, values: PackedFloat64Array, pixel: float) -> void:
	for i in range(0,values.size(),12):
		var radius:=values[i+2]
		var direction:=Vector2.from_angle(values[i+3])
		var tip:=Vector2(values[i],values[i+1])+direction*(radius+values[i+7]*0.5+values[i+8])
		var color:=Color(values[i+9],values[i+10],values[i+11])
		if int(values[i+4])==EnemyTable.Mode.WINDUP:
			var charge:=values[i+5]
			var length:=values[i+6]
			var along:=0.0
			while along<length:
				c.draw_line(tip+direction*along,tip+direction*minf(along+36.0*0.55,length),Color(color,0.25+0.6*charge),maxf(pixel*2.0,3.0+4.0*charge))
				along+=36.0
			c.draw_circle(tip,radius*(0.2+0.4*charge),Color(1,1,1,0.4+0.5*charge))
		elif int(values[i+4])==EnemyTable.Mode.DASH:
			c.draw_circle(tip,radius*0.18,Color(color,0.6))
