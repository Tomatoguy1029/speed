## 固定試作 fxlib.js の論理画素用の共通描画。
## pixelFX の作例に基づく。帰属・ライセンス: assets/ui/rewards/pixelfx_NOTICE.txt・pixelfx_LICENSE.txt。
extends RefCounted

static func hash_value(n: float) -> float:
	var value := sin(n * 127.1 + 311.7) * 43758.5453
	return value - floorf(value)

static func ramp(color: Color) -> Array[Color]:
	var result: Array[Color] = []
	for pair: Vector2 in [Vector2(0.35, 0), Vector2(0.6, 0), Vector2(1, 0), Vector2(1, 0.45)]:
		result.append(Color(
			roundf(lerpf(color.r * pair.x, 1, pair.y) * 255) / 255,
			roundf(lerpf(color.g * pair.x, 1, pair.y) * 255) / 255,
			roundf(lerpf(color.b * pair.x, 1, pair.y) * 255) / 255))
	result.append(Color.WHITE)
	return result

## 位置・速さは試作の論理画素、時間は秒。direction=null は全方位。
static func sparks(painter, origin: Vector2, time: float, seed: float, count: int, color: Color, speed := 40.0, life := 0.35, direction = null, spread := PI) -> void:
	var palette := ramp(color)
	for i in count:
		var lifetime := life * lerpf(0.6, 1.2, hash_value(seed + i * 1.7))
		if time > lifetime or time < 0:
			continue
		var angle: float = hash_value(seed * 5 + i) * TAU if direction == null else float(direction) + (hash_value(seed * 5 + i) - 0.5) * 2 * spread
		var velocity := speed * lerpf(0.5, 1.3, hash_value(seed * 9 + i))
		var progress := time / lifetime
		var distance := velocity * time * (1 - progress * 0.4)
		var x := origin.x + cos(angle) * distance
		var y := origin.y + sin(angle) * distance + 20 * time * time
		var tail := minf(4, 1 + velocity * 0.03 * (1 - progress))
		painter.line(x - cos(angle) * tail, y - sin(angle) * tail, x, y, func(u: float): return (palette[4] if progress < 0.4 else palette[3]) if u > 0.5 else palette[2], 1 - progress * 0.6)
		painter.light(x, y, palette[2], 0.3 * (1 - progress))
