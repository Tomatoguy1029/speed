## うみへび座の首の骨組み。点列だけを更新し、絵と当たり判定は役者が扱う。
extends RefCounted

## FABRIK で節長を補正する。両端を固定し、世界秒で進む波を曲がりの目標へ加える。
## rest_length は引いた首に残る全長。頭がそれより遠くなると、全体を伸ばす。
static func update(points: PackedVector2Array, base: Vector2, head: Vector2,
		rest_length: float, phase: float, time: float, dt: float, params: Dictionary) -> void:
	var count := clampi(int(params.get("neck_segments", 16)), 4, 32)
	var iterations := clampi(int(params.get("neck_iterations", 4)), 1, 12)
	var delta := head - base
	var distance := delta.length()
	var direction := delta / distance if distance > 0.001 else Vector2.RIGHT
	var side := direction.orthogonal()
	var length := maxf(distance, rest_length * maxf(1.0, float(params.get("neck_slack", 1.12))))
	var segment_length := length / count
	var initialize := points.size() != count + 1
	var shift := Vector2.ZERO if initialize else base - points[0]
	if initialize:
		points.resize(count + 1)
	# 伸びきった首は直線で確定できる。余長がない状態での反復も省く。
	if length - distance < 0.001:
		for i in count + 1:
			points[i] = base.lerp(head, float(i) / count)
		return
	var bend := sqrt(maxf(0.0, length * length - distance * distance)) * 0.45
	var bend_sign := 1.0 if sin(phase) >= 0.0 else -1.0
	var amplitude := minf(maxf(0.0, float(params.get("neck_wave_amplitude", 18.0))), bend * 0.6)
	var frequency := maxf(0.0, float(params.get("neck_wave_frequency", 1.5)))
	var speed := maxf(0.0, float(params.get("neck_wave_speed", 2.5)))
	var response := maxf(0.0, float(params.get("neck_response", 10.0)))
	var weight := 1.0 if initialize else 1.0 - exp(-response * dt)
	var wave_phase := time * speed + phase
	var wave_span := frequency * TAU
	var inverse_count := 1.0 / count
	points[0] = base
	points[count] = head
	for i in range(1, count):
		var f := float(i) * inverse_count
		var wave := sin(wave_phase + f * wave_span) * amplitude
		var guide := base.lerp(head, f) + side * sin(f * PI) * (bend * bend_sign + wave)
		points[i] = guide if initialize else (points[i] + shift).lerp(guide, weight)
	for _pass_index in iterations:
		points[count] = head
		var previous := head
		for i in range(count - 1, -1, -1):
			var offset := points[i] - previous
			var squared := offset.length_squared()
			previous += offset * (segment_length / sqrt(squared)) if squared > 0.000001 else -direction * segment_length
			points[i] = previous
		points[0] = base
		previous = base
		for i in range(1, count + 1):
			var offset := points[i] - previous
			var squared := offset.length_squared()
			previous += offset * (segment_length / sqrt(squared)) if squared > 0.000001 else direction * segment_length
			points[i] = previous
		if points[count].distance_squared_to(head) < 0.0001:
			break
	# 有限回の補正で残る誤差は首の先へ引き受け、頭の攻撃位置を厳密に保つ。
	points[count] = head
