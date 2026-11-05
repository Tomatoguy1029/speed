## 鳳凰の予兆に降る火の粉と地面の小さな光。
## 座標は着地点からの論理画素。影と光だまりは別の層で描く。
extends RefCounted

func draw(back, front, radius: float, elapsed: float, time: float, charge: float, intensity: float, fire: Array[Color], sparks: Array[Color]) -> void:
	for i in ceili(70 * charge):
		var angle := _hash(i * 4.1) * TAU
		var d := radius * sqrt(_hash(i * 1.9)) * 0.95
		var twinkle := sin(time * (6 + _hash(i) * 8) + i)
		if twinkle > 0.2:
			back.px(cos(angle) * d, sin(angle) * d * 0.9, fire[3] if twinkle > 0.8 else fire[5])
	var count := floori(90 * intensity + 0.5)
	for i in count:
		var born := _hash(i * 1.37) * 1.3
		var age := elapsed - born
		var fall := 0.45 + _hash(i * 3.1) * 0.25
		if age < 0:
			continue
		var angle := _hash(i * 7.7) * TAU
		var distribution := absf((_hash(i * 2.3) + _hash(i * 5.9) + _hash(i * 9.1) - 1.5) / 1.5)
		var distance := radius * minf(1, distribution) * 1.05
		var x := cos(angle) * distance
		var ground_y := sin(angle) * distance * 0.9
		if age < fall:
			var progress := age / fall
			var y := ground_y - (1 - progress * progress) * 38
			var length := 2 + 3 * progress
			front.line(x, y - length, x, y, func(u: float): return sparks[0] if u > 0.6 else sparks[1])
			front.glow(x, y, 3, sparks[1], 0.35 * intensity)
		elif age < fall + 0.35:
			var progress := (age - fall) / 0.35
			back.px(x, ground_y, sparks[0] if progress < 0.3 else (sparks[1] if progress < 0.6 else sparks[2]))
			if progress < 0.5:
				back.px(x - 1, ground_y, sparks[2])
				back.px(x + 1, ground_y, sparks[2])
			back.glow(x, ground_y, 5, sparks[1], 0.4 * (1 - progress) * intensity)

func _hash(n: float) -> float:
	var value := sin(n * 127.1 + 311.7) * 43758.5453
	return value - floorf(value)
