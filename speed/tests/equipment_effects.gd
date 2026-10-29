## 全装備を編集画面と同じ手順で本番描画へ接続し、実行時エラーを失敗として扱う。
extends Node
const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const SCENARIO := preload("res://gyms/equipment_effect_scenario.gd")
const MemorySave := preload("res://tests/thrill_acceptance.gd").MemorySave
class ErrorCapture extends Logger:
	var errors: Array[String] = []
	var mutex := Mutex.new()
	func _log_message(_message: String, _error: bool) -> void: pass
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _notify: bool, type: int, _traces: Array[ScriptBacktrace]) -> void:
		if type == ERROR_TYPE_WARNING: return
		mutex.lock()
		errors.append("%s:%d %s %s" % [file,line,code,rationale])
		mutex.unlock()
	func count() -> int:
		mutex.lock()
		var result := errors.size()
		mutex.unlock()
		return result
	func messages() -> Array[String]:
		mutex.lock()
		var result: Array[String] = errors.duplicate()
		mutex.unlock()
		return result
var capture := ErrorCapture.new()
var failures := 0
var cases := 0
var only := PackedStringArray()
var gpu := false
var sonic_white_square := 0
const EVENTS := {
	"weapon/forward":&"weapon_fire", "weapon/scatter":&"weapon_fire", "weapon/rear":&"weapon_fire",
	"weapon/knockback":&"hull_scatter", "weapon/contactWave":&"space_quake", "weapon/contactArc":&"bolt",
	"weapon/barrier":&"barrier_hit", "weapon/mines":&"explode", "weapon/massTow":&"anchor_fire", "weapon/sonic":&"sonic_push",
	"weapon/bipolar":&"beam", "weapon/dashRangeDrone":&"escort_deploy", "weapon/flashSlash":&"flash_slash", "weapon/endBlast":&"explode",
	"trait/vortex":&"hole_recover", "trait/killSonic":&"chain_shock", "trait/critBeam":&"critical_lance",
	"trait/runUp":&"run_up_hit", "trait/fullBurst":&"full_burst_ready", "trait/duplicator":&"duplicate"
}
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

## 装備キー（weapon/〜・trait/〜）の表示。
func _visual(presentation, key: String) -> WeaponVisual:
	for visual in presentation._equipment_visuals.values():
		if visual._effect_key() == key: return visual
	return null

## 大きな白い面が出る再発を、実際の描画画素から検出する。
func measure_white_square(viewport: SubViewport) -> int:
	var image := viewport.get_texture().get_image()
	var columns := image.get_width()/4
	var previous := PackedInt32Array()
	previous.resize(columns+1)
	var largest := 0
	for y in range(0,image.get_height(),4):
		var current := PackedInt32Array()
		current.resize(columns+1)
		for x in columns:
			var color := image.get_pixel(x*4,y)
			if color.a>0.9 and minf(color.r,minf(color.g,color.b))>0.95:
				current[x+1]=1+mini(current[x],mini(previous[x],previous[x+1]))
				largest=maxi(largest,current[x+1])
		previous=current
	return largest*4

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--gpu": gpu = true
		if arg == "--combinations-only": only = PackedStringArray(["__combinations__"])
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	OS.add_logger(capture)
	# 高速な描画処理の検査では音を再生せず、音声再生の終了待ちを含めない。
	AudioManager._sounds = {}
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.data = SaveManager.default_data()
	SaveManager.settings = settings
	var editor_script = load("res://gyms/effect_settings_preview.gd")
	var preview = load("res://gyms/boss_effect_preview.gd").new()
	preview.size = Vector2(1280,720)
	add_child(preview)
	var session = preview.session
	session.set_physics_process(false)
	for category in [&"weapons",&"traits"]:
		for entry in ContentManager.catalog.table(category).values():
			var key := ("weapon/" if category == &"weapons" else "trait/")+String(entry.code_id)
			if not only.is_empty() and key not in only: continue
			check(key in editor_script.DIRECT_EFFECTS,"全装備が再生一覧にある: "+key)
			for level in range(1,6):
				var before_reset := capture.count()
				preview._equipment_key = ""
				preview._weapon_key = ""
				preview._trait_key = ""
				preview._trait_level.select(level-1)
				preview._equipment_level.select(level-1)
				await preview.set_effect(key)
				session.playing = false
				var presentation = session.scene.view.get_node("RunPresentation")
				presentation.set_process(false)
				var error_count := before_reset
				check(presentation._layers.enemies.visible,"実験場で敵を表示する: "+key)
				if level==1:
					var before_spawn: int = session.run.enemies.table.alive.count(1)
					preview._add_preview_enemies()
					check(session.run.enemies.table.alive.count(1)==before_spawn+3,"敵を追加ボタンで3体を出す: "+key)
				var observed := false
				for frame in 600:
					session.step()
					if frame%4 == 0:
						presentation._present(4.0*session.DT)
						if key == "weapon/interceptor": observed = observed or session.run.loadout.weapon_behaviors[entry.id].drones.any(func(d):return d.flash>0.0)
						if key == "weapon/sonic": observed = observed or _visual(presentation, key).impacts.size() + _visual(presentation, key).pushes.size() > 0
						if key == "weapon/afterimage":
							var mirage = session.run.loadout.weapon_behaviors[entry.id]
							observed = observed or not mirage.echoes.is_empty()
							for echo in mirage.echoes: check(echo.copies.size()==level,"ミラージュの本体はLvごとの1〜5機")
							var visual = presentation._equipment_visuals.get(mirage.get_instance_id())
							if visual != null: check(visual.node._body._count<=level,"ミラージュの描画で本体を重複させない")
						if key == "trait/fullCharge": observed = observed or not _visual(presentation, key).flames.is_empty()
						if key == "trait/rampage": observed = observed or (not session.run.state.tracing and session.run.loadout.trait_behaviors[entry.id].strength>0.9)
					if gpu and frame%4 == 0:
						await RenderingServer.frame_post_draw
						if key=="weapon/sonic": sonic_white_square=maxi(sonic_white_square,measure_white_square(preview._viewport))
					elif frame%60 == 0: await get_tree().process_frame
				if EVENTS.has(key): check(session.events.any(func(ev):return ev.type == EVENTS[key]),"対象の演出が実際に発動する: %s Lv%d" % [key,level])
				if key in ["weapon/interceptor","weapon/sonic","weapon/afterimage","trait/fullCharge","trait/rampage"]: check(observed,"連続する演出が実際に動く: %s Lv%d" % [key,level])
				if key == "weapon/barrier": check(session.events.any(func(ev):return ev.type == &"barrier_restore"),"バリアが復活する演出まで再生する")
				if key == "weapon/sonic": check(session.events.any(func(ev):return ev.type == &"sonic_impact"),"ソニックは輪だけでなく押し出し後の破裂まで再生する")
				check(capture.count() == error_count,"装備再生でエラー: %s Lv%d" % [key,level])
				if key == "weapon/knockback":
					check(not session.events.any(func(ev):return ev.type == &"debris_trail"),"星砕きの消滅後に古い航跡を残さない")
				cases += 1
				print("[equipment_effects] %d %s Lv%d errors=%d" % [cases,key,level,capture.count()-error_count])
				if capture.count() > error_count: break
	for combination in [
		{"key":"trait/critBeam","weapons":{},"traits":{&"T06":5,&"T37":5}},
		{"key":"weapon/knockback","weapons":{&"W03":5},"traits":{&"T37":5}},
		{"key":"weapon/interceptor","weapons":{&"W25":5},"traits":{&"T35":5,&"T36":5,&"T37":5}},
		{"key":"weapon/endBlast","weapons":{&"W05":5,&"W07":5,&"W29":5},"traits":{&"T03":5,&"T34":5}},
		{"key":"trait/vortex","weapons":{&"W07":5},"traits":{&"T03":5}},
		{"key":"trait/rampage","weapons":{&"W07":5},"traits":{&"T33":5}}
	]:
		if not only.is_empty() and "__combinations__" not in only: continue
		var error_count := capture.count()
		await session.reset({"empty":true,"invincible":true,"director":{"enabled":false},"weapons":combination.weapons,"traits":combination.traits})
		var duplicator = session.run.loadout.trait_behaviors.get(&"T37")
		if duplicator != null:
			duplicator.def = duplicator.def.duplicate(true)
			duplicator.def.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
		var presentation = session.scene.view.get_node("RunPresentation")
		presentation.set_process(false)
		SCENARIO.play(session,combination.key)
		for frame in 420:
			session.step()
			if frame%4 == 0: presentation._present(4.0*session.DT)
			if gpu and frame%4 == 0: await RenderingServer.frame_post_draw
			elif frame%60 == 0: await get_tree().process_frame
		if combination.key in ["trait/vortex","trait/rampage"]:
			check(session.run.loadout.weapon_behaviors[&"W07"]._serial==24,"特性の試遊でも機雷は終点で1回だけ出す: "+combination.key)
		check(capture.count() == error_count,"装備の組み合わせ再生でエラー: "+combination.key)
		cases += 1
		print("[equipment_effects] combination ",combination.key," errors=",capture.count()-error_count)
	if is_instance_valid(session.scene): session.scene.free()
	for checkpoint in session.checkpoints:
		if is_instance_valid(checkpoint.scene): checkpoint.scene.free()
	session.free()
	preview.free()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.remove_logger(capture)
	for error in capture.messages(): printerr("[equipment_effects] "+error)
	if gpu and sonic_white_square>0:
		check(sonic_white_square<64,"ソニックに64px以上の白い面が出ない")
		print("[equipment_effects] ソニックの白い連続面の最大辺=%dpx" % sonic_white_square)
	print("[equipment_effects] cases=%d failures=%d errors=%d" % [cases,failures,capture.count()])
	get_tree().quit(1 if failures or capture.count()>0 else 0)
