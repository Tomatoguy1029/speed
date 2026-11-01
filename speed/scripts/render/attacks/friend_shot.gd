## C++の表示用の値から、通常の味方弾を同じドット描画へ渡す。
extends RefCounted

static func create_batch(pixel: float) -> PixelPainter:
	var painter := PixelPainter.new()
	painter.setup_painter(pixel)
	return painter

static func apply_frame(painter: PixelPainter, transforms: PackedFloat32Array) -> void:
	for n in range(0,transforms.size(),6):
		painter.bolt(Vector2(transforms[n+4],transforms[n+5]),atan2(transforms[n+1],transforms[n]),17,2)
