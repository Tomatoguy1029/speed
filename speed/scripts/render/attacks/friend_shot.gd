## C++の表示用の値から、通常の味方弾を同じドット描画へ渡す。
extends RefCounted

static func create_batch(pixel: float) -> PixelPainter:
	var painter := PixelPainter.new()
	painter.setup_painter(pixel)
	return painter

static func apply_frame(painter: PixelPainter, transforms: PackedFloat32Array, flags: PackedInt32Array) -> void:
	for n in range(0,transforms.size(),6):
		var style: int = flags[n/6]
		var position := Vector2(transforms[n+4],transforms[n+5])
		var angle := atan2(transforms[n+1],transforms[n])
		if style==3:
			var mint := Color("#8fffe2")
			for k in range(1,4):
				painter.along(position,angle,k,1.0,Color(mint,0.4))
				painter.along(position,angle,k,-1.0,Color(mint,0.4))
			for k in range(1,5): painter.along(position,angle,k,0.0,mint)
			painter.along(position,angle,0,0.0,Color.WHITE)
		else:
			painter.bolt(position,angle,3 if style==2 else (6 if style==1 else 17),0 if style==2 else (1 if style==1 else 2))
