## 技に共通する予告・照準・終了処理。技のRunnerが継承する。
extends BossTechnique.Runner

func _begin_windup(host: CentaurusBoss, r: Dictionary, length: float) -> void:
	host.mode = &"windup"
	host.alerting = false
	host.warn_aim = host.run_state.ship_pos if host.technique == &"power_shot" else host.run_state.enemy_aim
	host.table.vel[host.body] = Vector2.ZERO
	var anim := host.timeline.get_animation(&"attack")
	while anim.track_get_key_count(0) > 0: anim.track_remove_key(0, 0)
	if host.technique == &"rain":
		# 予告のあとはトレースの進行で終わるので、タイムラインは開始の鍵だけを持つ。
		anim.length = float(r.warn) + 0.01
		anim.track_insert_key(0, float(r.warn), {"method": &"begin_rain", "args": []})
	else:
		anim.length = length
		if host.technique == &"rear_attack":
			anim.track_insert_key(0, float(r.warn), {"method": &"strike_on", "args": []})
		elif host.technique == &"power_shot":
			anim.track_insert_key(0, maxf(0.01, float(r.warn) - float(r.alert)), {"method": &"alert", "args": []})
			anim.track_insert_key(0, float(r.warn), {"method": &"release", "args": []})
		else:
			for k in int(r.count): anim.track_insert_key(0, float(r.warn) + float(r.interval) * k, {"method": &"release", "args": []})
		anim.track_insert_key(0, length, {"method": &"end_attack", "args": []})
	host.timeline.play(&"attack")
	host.timeline.advance(0.0)
	host._cue(&"telegraph")

## 強弓の発射直前の警告。向きは発射まで機体を追い続ける。

func release(host: CentaurusBoss) -> void:
	if host.mode not in [&"windup", &"shooting"]: return
	var r := host.rule()
	var mouth := host.bow_mouth()
	var power := host.technique == &"power_shot"
	var target := (host.run_state.ship_pos if power else host.run_state.enemy_aim) if host._tracks_during_warn() else host.warn_aim
	var angle := (target - mouth).angle()
	for offset in host.power_offsets() if power else [0.0]:
		host.ctx.projectiles.emit_attack(&"light_arrow", [mouth, angle + offset, float(r.speed), float(r.radius), float(r.travel),
			float(r.damage) * host.ctx.cfg.atk_scale, power])
	host.mode = &"shooting"
	host._cue(&"released")

## 強弓の矢ごとの、機体への向きからの角度。

func end_attack(host: CentaurusBoss) -> void:
	if host.mode not in [&"windup", &"shooting", &"strike"]: return
	host.timeline.stop()
	host.alerting = false
	host.mode = &"recovery"
	host.recovery = float(host.rule().recover)
	host._cue(&"recovery_started")

# ── 背後攻撃 ──────────────────────────────────────────────

## 背後攻撃の当たりを有効にする。有効な間に範囲の円へ触れた機体へ1回だけ当たる。
