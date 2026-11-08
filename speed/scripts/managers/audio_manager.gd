## 音。Autoload（設計書 4.3・13）。
##
## 鳴らす音と鳴らし方（音量・ピッチ・同時に鳴らす数・ループ）は音の表の欄ごとに決まる（仕様書 18）。
## 呼び出し側は欄ID（例: weapon.blaster.fire）だけを渡す。音のない欄は何も鳴らさない。
## ダッシュは専用バスでスロー減衰を除外し、音量と消音は設定（SaveManager）に従う。
## 通常効果音は再生口を使い回し、ダッシュ・ループ・BGMは専用の再生口を持つ。
extends Node

const MAX_VOICES := 12
## 同じ効果音を同時に鳴らす数の標準。欄の max_voices が0のときに使う。超えたら一番古い音を止めて入れ替える。
const MAX_SAME_SOUND := 2
## 同じ効果音がこの時間（ミリ秒）より近く続けて来たら、1つの音にまとめる。
const SAME_SOUND_MERGE_MS := 50
const MENU_RESUME_TRACKS := [&"music.menu", &"music.stage_select"]
const MENU_RESUME_WINDOW_MS := 10000
const DASH_VOICE = preload("res://scripts/managers/dash_audio_voice.gd")
const DASH_SOUNDS := [&"ship.boost.dash", &"ship.boost.dash_loop", &"ship.boost.dash_end"]
const HEARTBEAT := &"ship.combat.low_hp"
## 心音の素材で、最初の拍が鳴る位置と拍の間隔（秒）。心音の素材を替えたら合わせる。
const HEARTBEAT_FIRST_BEAT := 0.24
const HEARTBEAT_PERIOD := 1.125
## C++ のイベント → 鳴らす欄。中身で鳴らす欄が変わるイベントは _event_sound で選ぶ。
const EVENT_SOUNDS := {
	&"levelup": &"growth.level.levelup_notice",
	&"hurt": &"ship.combat.hurt",
	&"block_impact": &"ship.combat.bounce",
	&"critical_hit": &"ship.combat.critical",
	&"draw_start": &"ship.boost.draw_start",
	&"gauge_full": &"ship.boost.gauge_full",
	&"xp_gold_roll": &"growth.level.gold_roll",
	&"gem_burst": &"growth.level.gem_burst",
	&"strong_spawn": &"elite.common.spawn",
	&"boss_spawn": &"boss.common.warning",
	&"boss_phase": &"boss.common.phase",
	&"boss_explode": &"boss.common.explode",
	&"time_limit_reached": &"field.stage.time_limit",
	&"wave": &"field.stage.wave",
	&"rock_break": &"field.rock.break",
	&"clear_banner": &"scene.boss_finish.clear",
	&"ship_explode": &"scene.defeat.explode",
	&"space_quake": &"weapon.space_quake.spawn",
	&"sonic_impact": &"weapon.sonic_boom.impact",
	&"bolt": &"weapon.arc_field.discharge",
	&"slash_mark": &"weapon.flash_slash.mark",
	&"slash_release": &"weapon.flash_slash.start",
	&"flash_slash": &"weapon.flash_slash.slash",
	&"escort_deploy": &"weapon.escort_wing.deploy",
	&"escort_slash": &"weapon.escort_wing.slash",
	&"anchor_capture": &"weapon.anchor.capture",
	&"anchor_fire": &"weapon.anchor.fire",
	&"bipolar_charge": &"weapon.bipolar.charge",
	&"barrier_hit": &"weapon.barrier.block",
	&"barrier_restore": &"weapon.barrier.restore",
	&"chain_shock": &"trait.chain_shock.wave",
	&"critical_lance": &"trait.critical_lance.launch",
	&"critical_lance_hit": &"trait.critical_lance.hit",
	&"run_up_hit": &"trait.run_up.hit",
	&"end_hole": &"trait.end_hole.spawn",
	&"hole_recover": &"trait.end_hole.heal",
	&"duplicate": &"trait.duplicator.copy",
	&"full_burst_ready": &"trait.full_burst.ready",
	&"bomber_explode": &"enemy.bomber.explode",
	&"shield_block": &"elite.shield.block",
	&"shield_reflect": &"elite.shield.reflect",
	&"shield_stolen": &"elite.shield.stolen",
	&"telescope_charge": &"elite.telescope.charge",
	&"telescope_fire": &"elite.telescope.fire",
	&"cepheus_summon": &"elite.cepheus.summon",
	&"ruler_split": &"elite.ruler.split",
	&"landmark": &"hero.find.landmark_take",
	&"hero_discovered": &"hero.find.discover",
	&"hero_link": &"hero.find.link",
	&"hero_freed": &"hero.find.free",
	&"hero_power_end": &"hero.ult.end",
	&"meteor_impact": &"hero.hercules.impact",
	&"wave_release": &"boss.monoceros.horn_wave",
	&"monoceros_slash_release": &"boss.monoceros.sword",
	&"lance_launch": &"boss.monoceros.lance",
}
## 中身で鳴らす欄を選ぶイベント。EVENT_SOUNDS と合わせて購読する。
const EVENT_SPECIAL := [&"kill", &"weapon_fire", &"launch", &"trace_end", &"game_over", &"pickup", &"xp_collect", &"explode", &"shoot", &"hero_power",
	&"audio_cue", &"hit", &"shot_hit", &"beam", &"bonus", &"hero_power_end", &"end_hole", &"hydra_cue", &"centaurus_cue", &"canis_cue", &"draco_cue",
	&"run_finished", &"choice", &"level_bonus", &"reroll", &"offer", &"enemy_retire"]
## 同じイベントで EVENT_SOUNDS などの欄に重ねて鳴らす欄。
const EVENT_EXTRA := {
	&"boss_phase": [&"boss.common.roar"],
	&"boss_spawn": [&"boss.common.spawn", &"boss.common.roar"],
	&"barrier_hit": [&"weapon.barrier.wave"],
	&"hole_recover": [&"ship.combat.heal"],
	&"crash": [&"field.planet.bump"],
	&"sonic_push": [&"weapon.sonic_boom.push"],
	&"hull_scatter": [&"enemy.debris.fly"],
	&"summon_mark": [&"elite.cepheus.reinforce"],
	&"aquarius_aim": [&"elite.aquarius.charge"],
	&"final_strike": [&"scene.time_up.charge"],
	&"boss_defeated": [&"boss.common.final_strike"],
	&"boss_finish": [&"scene.boss_finish.replay", &"scene.boss_finish.victory"],
	&"boss_explode": [&"scene.boss_finish.vanish", &"scene.boss_finish.clear_field"],
	&"ship_death": [&"scene.defeat.last_hit"],
	&"game_over": [&"scene.defeat.text"],
}
## 命中（hit）の原因 → 欄。
const HIT_SOUNDS := {"ram": &"ship.combat.hit", "afterimage": &"weapon.mirage.hit", "hullDebris": &"enemy.debris.hit", "saw": &"field.saw.hit", "corona_throw": &"elite.corona.crash"}
## loop_for で鳴らし終えたときに続けて鳴らす欄。
const LOOP_ENDS := {&"field.saw.fly": &"field.saw.stop"}
## 弾の命中（shot_hit）の見た目 → 欄。
const SHOT_HIT_SOUNDS := {"weapon/forward": &"weapon.blaster.hit", "weapon/rear": &"weapon.blaster.hit", "weapon/scatter": &"weapon.spread.hit",
	"weapon/interceptor": &"weapon.strike_wing.hit", "weapon/massTow": &"weapon.anchor.hit"}
const BEAM_SOUNDS := {"weapon/bipolar": &"weapon.bipolar.beam", "enemy/reticle": &"elite.reticle.beam"}
const KILL_SOUNDS := {&"splitter": &"enemy.splitter.split", &"iron": &"field.iron.break", &"meteor": &"field.meteor.break", &"triangle_star": &"elite.triangle.break"}
## うみへび座の技 → [予兆, 発動] の欄。hydra_cue の warning_started・target_locked で予兆、attack_started で発動を鳴らす。
const HYDRA_SOUNDS := {
	"bite_thrust": [&"boss.hydra.bite_tell", &"boss.hydra.bite"],
	"bite_sweep": [&"boss.hydra.sweep_tell", &"boss.hydra.sweep"],
	"wind_band": [&"", &"boss.hydra.wind_band"],
	"wind_blades": [&"", &"boss.hydra.wind_blade"],
	"rubble_lump": [&"", &"boss.hydra.rock_throw"],
	"rubble_fan": [&"", &"boss.hydra.scatter"],
	"beam_fixed": [&"boss.hydra.fixed_charge", &"boss.hydra.fixed_beam"],
	"beam_bolt": [&"", &"boss.hydra.orb"],
	"thunder_headbutt": [&"boss.hydra.charge_up", &"boss.hydra.headbutt"],
	"thunder_drop": [&"boss.hydra.bolt_tell", &"boss.hydra.bolt"],
	"north": [&"boss.hydra.triple_tell", &"boss.hydra.triple"],
	"sequence": [&"", &"boss.hydra.chain_bite"],
	"curve": [&"boss.hydra.spin_charge", &"boss.hydra.spin_beam"],
	"grid": [&"boss.hydra.grid_tell", &"boss.hydra.grid_beam"],
	"swarm": [&"boss.hydra.pounce_tell", &"boss.hydra.pounce"],
}
const HYDRA_CUES := {"gather_started": &"boss.hydra.debris_tornado", "rubble_shattered": &"boss.hydra.debris_shatter",
	"separation_started": &"boss.hydra.separate", "head_destroyed": &"boss.hydra.neck_kill"}
## ケンタウルス座・おおいぬ座の合図 → 欄。名前が技をまたいで重なる合図（telegraph など）は C++ が audio_cue で鳴らす。
const CENTAURUS_CUES := {"shower_mark": &"boss.centaurus.fall_tell", "shower_landed": &"boss.centaurus.fall", "rain_started": &"boss.centaurus.rain_up", "rain_trace": &"boss.centaurus.rain",
	"stomp": &"boss.centaurus.stomp", "strike": &"boss.centaurus.back", "fan_windup": &"boss.centaurus.fan_draw", "fan_released": &"boss.centaurus.fan",
	"sail_windup": &"boss.centaurus.sail", "sail_run": &"boss.centaurus.sail_run", "sail_shot": &"boss.centaurus.sail_shot", "leap": &"boss.centaurus.leap"}
const CANIS_CUES := {"pounce": &"boss.canis_major.pounce", "command": &"boss.canis_major.command", "stream_windup": &"boss.canis_major.command",
	"bay_bark": &"boss.canis_major.bark", "howl": &"boss.canis_major.howl", "sirius": &"boss.canis_major.scorch", "flame_start": &"boss.canis_major.sirius_light",
	"nova_windup": &"boss.canis_major.flash_charge", "nova_flash": &"boss.canis_major.flash", "blaze_ignite": &"boss.canis_major.burn_ignite",
	"blaze_explode": &"boss.canis_major.burn", "relay_fire": &"boss.canis_major.relay"}
const DRACO_CUES := {"core_released": &"scene.finale.polaris", "bear_roar": &"scene.finale.ursa_roar"}
const CHOICE_SOUNDS := {"weapon": &"growth.cards.new_weapon", "trait": &"growth.cards.new_trait", "post_max": &"growth.cards.post_max"}
## 戦闘の phase のうち、ループする欄を鳴らし続ける段階（Play・Finishing）。
const LOOP_PHASES := [0, 4]
const PICKUP_SOUNDS := {&"heal": &"field.repair.pick", &"magnet": &"field.beacon.pick", &"comet_weapon": &"weapon.get.capsule_pick", &"coin": &"field.parts.pick"}
## エンドブラストの爆発は外周の小爆発と分けるため C++ が audio_cue で鳴らす。
const EXPLODE_SOUNDS := {"mine": &"weapon.mine.blast", "runUp": &"trait.run_up.area", "pump_burst": &"elite.pump.release"}
const HERO_SOUNDS := {"leo": &"hero.leo.transform", "perseus": &"hero.perseus.cast", "gemini": &"hero.gemini.split", "hercules": &"hero.hercules.cast"}
const XP_RANK := {"low": 0, "mid": 1, "high": 2}

var _dash_voice: Node
var _heartbeat_player: AudioStreamPlayer
var _heartbeat_fade: Tween
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _sounds: Dictionary = {}
var _music: Dictionary = {}
var _params: Dictionary = {}
var _unknown: Dictionary = {}
## start_loop のキー → 鳴らしている再生口。
var _loops: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_track: StringName = &""
## フェード待ちの要求と、再生口が実際に鳴らしている曲を区別する。
var _playing_music_track: StringName = &""
var _music_request := 0
var _music_departed_at := -1
var _menu_music_positions: Dictionary = {}
var _music_owner: Node
var _music_fade: Tween
var _slow_motion := false
var _slow_gain := 1.0
var _slow_fade: Tween

func _ready() -> void:
	_ensure_bus(&"SFX")
	_ensure_bus(&"Engine")
	_ensure_bus(&"Music")
	_ensure_bus(&"Dash")
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)
	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.bus = &"SFX"
	add_child(_heartbeat_player)
	for i in MAX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_reload_bank()
	get_tree().node_added.connect(watch_button)
	SaveManager.settings_changed.connect(_apply_volumes)
	_apply_volumes()

## 再生口を捨てる前に、音声サーバーへ停止とストリーム解放を渡す。
func _exit_tree() -> void:
	_music_request += 1
	if _music_fade!=null: _music_fade.kill()
	if _slow_fade!=null: _slow_fade.kill()
	for player: AudioStreamPlayer in find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	_menu_music_positions.clear()
	_loops.clear()
	_sounds.clear()
	_music.clear()
	# stop()は次の音声ミックスで再生参照を解放する。終了処理が先に
	# 音声スレッドを止めないよう、停止要求より後のミックス完了を待つ。
	# 出力デバイスが止まっていても、終了自体は待ち続けない。
	var stopped_at := Time.get_ticks_usec()
	while Time.get_ticks_usec() - stopped_at < 250000:
		var sampled_at := Time.get_ticks_usec()
		var since_mix := roundi(AudioServer.get_time_since_last_mix() * 1000000.0)
		if sampled_at - since_mix > stopped_at: break
		OS.delay_usec(1000)

## 曲の終わりを決めた欄は、そこでループの戻り先へ戻すか止める。
func _process(_delta: float) -> void:
	if _playing_music_track == &"" or not _music_player.playing: return
	var p := settings(_playing_music_track)
	var end: float = p.get("trim_end", 0.0)
	if end <= 0.0 or _music_player.get_playback_position() < end: return
	if p.get("loop", false): _music_player.seek(float(p.get("loop_start", 0.0)))
	else: _music_player.stop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		toggle_mute()

func toggle_mute() -> void:
	SaveManager.set_setting("muted", not bool(SaveManager.settings.muted))
	play(&"ui.settings.mute")

## 欄の音。音のない欄は null。
func sound(id: StringName) -> AudioStream:
	return _sounds.get(id)

## 欄に曲があるか。曲のない欄へ切り替えずに前の曲を続けるかを、呼び出し側が決めるときに使う。
func has_music(id: StringName) -> bool:
	return _music.get(id) != null

## ボタンにカーソルを合わせた音と、使えないボタンを押した音をつなぐ。画面のボタンが増えるたびに呼ばれる。
## 画面が自分の欄で鳴らすボタンは、メタデータ own_hover（true）・denied_sound（欄ID）で共通の音を差し替える。
func watch_button(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta(&"audio_watched"): return
	button.set_meta(&"audio_watched", true)
	button.mouse_entered.connect(func():
		if not button.disabled and not button.get_meta(&"own_hover", false): play(&"ui.common.hover"))
	button.gui_input.connect(func(event: InputEvent):
		if button.disabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			play(button.get_meta(&"denied_sound", &"ui.common.denied")))

## 欄の鳴らし方。音の表にない欄は空。
func settings(id: StringName) -> Dictionary:
	if not _params.has(id): _reload_bank()
	if not _params.has(id) and not _unknown.has(id):
		_unknown[id] = true
		push_error("音の表にない欄です: %s" % id)
	return _params.get(id, {})

## 欄のピッチを最小〜最大から選び、呼び出し側の倍率を掛ける。
func pitch(id: StringName, scale := 1.0) -> float:
	var p := settings(id)
	return randf_range(float(p.get("pitch_min", 1.0)), float(p.get("pitch_max", 1.0))) * scale

## 効果音を1回鳴らす。pitch_scale は欄のピッチに掛ける倍率（段階で音を上げる演出など）。
func play(id: StringName, pitch_scale := 1.0) -> void:
	if id == DASH_SOUNDS[0]:
		start_dash()
		return
	var p := settings(id)
	var stream: AudioStream = _sounds.get(id)
	if stream == null: return
	# 同じ瞬間の音は1つにまとめ、ずれて来た音は必ず鳴らす。重なりは上限までにして、古い音から入れ替える。
	var now := Time.get_ticks_msec()
	var same: Array[AudioStreamPlayer] = []
	for player in _players:
		if player.playing and player.get_meta(&"sound_name", &"") == id:
			if now - int(player.get_meta(&"started_at", 0)) < SAME_SOUND_MERGE_MS: return
			same.append(player)
	var limit: int = p.get("max_voices", 0)
	if limit <= 0: limit = MAX_SAME_SOUND
	var player: AudioStreamPlayer
	if same.size() >= limit:
		same.sort_custom(func(a: AudioStreamPlayer, b: AudioStreamPlayer): return int(a.get_meta(&"started_at", 0)) < int(b.get_meta(&"started_at", 0)))
		player = same[0]
		player.stop()
	else:
		player = _players[_next]
		_next = (_next + 1) % MAX_VOICES
	player.set_meta(&"sound_name", id)
	player.set_meta(&"started_at", now)
	player.stream = stream
	player.volume_db = float(p.get("volume_db", 0.0))
	player.pitch_scale = pitch(id, pitch_scale)
	player.play()

## ループする欄を key ごとに鳴らし続ける。同じ key で呼び直しても鳴らし直さない。
func start_loop(id: StringName, key: Variant = null) -> void:
	var k: Variant = id if key == null else key
	if _loops.has(k) and is_instance_valid(_loops[k]): return
	var stream: AudioStream = _sounds.get(id)
	var p := settings(id)
	if stream == null: return
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.stream = stream
	player.volume_db = float(p.get("volume_db", 0.0))
	player.pitch_scale = pitch(id)
	add_child(player)
	player.play()
	_loops[k] = player

## start_loop で鳴らした音を短くフェードして止める。
func stop_loop(id: StringName, key: Variant = null, fade_seconds := 0.15) -> void:
	var k: Variant = id if key == null else key
	var player: AudioStreamPlayer = _loops.get(k)
	_loops.erase(k)
	if not is_instance_valid(player): return
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(player, "volume_db", -60.0, fade_seconds)
	tween.tween_callback(player.queue_free)

## start_loop で鳴らしている音をすべて止める。戦闘画面の退出で使う。
func stop_loops() -> void:
	for key: Variant in _loops.keys(): stop_loop(&"", key, 0.05)

## 敵ごとに鳴らしているループ（欄が enemy.・elite. で始まり、key が敵ID）を止める。
func _stop_enemy_loops(id: int) -> void:
	var suffix := "#%d" % id
	for key: Variant in _loops.keys():
		if key is String and key.ends_with(suffix) and (key.begins_with("enemy.") or key.begins_with("elite.")): stop_loop(&"", key)

## ポーズ・カード選択の間はループする欄を一時停止する。
func pause_loops(paused: bool) -> void:
	for player: AudioStreamPlayer in _loops.values():
		if is_instance_valid(player): player.stream_paused = paused

## ループする欄を seconds 秒だけ鳴らす。同じ key で呼び直すと止める時刻を延ばす。
func loop_for(id: StringName, key: Variant, seconds: float) -> void:
	start_loop(id, key)
	var player: AudioStreamPlayer = _loops.get(key)
	if not is_instance_valid(player): return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	player.set_meta(&"until", until)
	get_tree().create_timer(seconds, false).timeout.connect(func():
		if _loops.get(key) != player or int(player.get_meta(&"until", 0)) > Time.get_ticks_msec(): return
		stop_loop(id, key)
		if LOOP_ENDS.has(id): play(LOOP_ENDS[id]))

func _reload_bank() -> void:
	var bank := ResourceLoader.load("res://.content/audio.res", "", ResourceLoader.CACHE_MODE_IGNORE) as AudioBank
	if bank != null:
		_sounds = bank.sounds.duplicate()
		_music = bank.music.duplicate()
		_params = bank.params.duplicate()

## 単一のBGM再生口。切り替え中の再要求や画面退出は古いTweenを取り消す。曲のない欄では今の曲を続ける。
func play_music(id: StringName, fade_seconds := 1.0, owner: Node = null) -> void:
	if id == _music_track:
		_music_owner = owner
		return
	var p := settings(id)
	var song := _music.get(id) as AudioStream
	if song == null: return
	var requested_at := Time.get_ticks_msec()
	var gain := db_to_linear(float(p.get("volume_db", 0.0)))
	_music_request += 1
	var request := _music_request
	_music_track = id
	_music_owner = owner
	if _music_fade != null: _music_fade.kill()
	_music_fade = create_tween()
	# まだ元のメニュー曲のフェードアウト中なら、止めずに音量だけ戻す。
	if id in MENU_RESUME_TRACKS and id == _playing_music_track and _music_player.playing and _music_player.stream == song:
		_music_departed_at = -1
		_music_fade.tween_property(_music_player, "volume_linear", gain, minf(fade_seconds, 0.6))
		return
	if _music_player.playing and _music_departed_at < 0:
		_music_departed_at = requested_at
	var start := _music_start_position(id, song, requested_at)
	if _music_player.playing and fade_seconds > 0.0:
		_music_fade.tween_property(_music_player, "volume_linear", 0.0, fade_seconds)
	_music_fade.tween_callback(func():
		if request != _music_request: return
		_remember_menu_music()
		_music_player.stop()
		_music_player.stream = song
		_playing_music_track = id
		_music_departed_at = -1
		_music_player.volume_linear = 0.0 if fade_seconds > 0.0 else gain
		_music_player.play(start)
		_menu_music_positions.erase(id))
	_music_fade.tween_property(_music_player, "volume_linear", gain, minf(fade_seconds, 0.6))

## 離脱要求の実時刻と、フェード後に実際に止めた位置を曲ごとに保持する。
func _remember_menu_music() -> void:
	if _playing_music_track not in MENU_RESUME_TRACKS or not _music_player.playing: return
	_menu_music_positions[_playing_music_track] = {"stream": _music_player.stream,
		"position": _music_player.get_playback_position(),
		"left_at": _music_departed_at if _music_departed_at >= 0 else Time.get_ticks_msec()}

## 曲の始め（欄の trim_start）から鳴らす。メニュー曲は離れてすぐ戻ったら止めた位置から続ける。
func _music_start_position(id: StringName, song: AudioStream, requested_at: int) -> float:
	var p := settings(id)
	var first := float(p.get("trim_start", 0.0))
	if id not in MENU_RESUME_TRACKS: return first
	var saved: Dictionary = _menu_music_positions.get(id, {})
	if saved.is_empty() or saved.stream != song or requested_at - int(saved.left_at) > MENU_RESUME_WINDOW_MS:
		return first
	var position := float(saved.position)
	var end := song.get_length()
	var trim_end := float(p.get("trim_end", 0.0))
	if trim_end > 0.0 and trim_end < end: end = trim_end
	var loop_from := float(p.get("loop_start", first)) if p.get("loop", false) else first
	if not is_finite(position) or position < first or end <= loop_from: return first
	if position < end: return position
	return loop_from + fmod(position - loop_from, end - loop_from) if p.get("loop", false) else first

func stop_music(owner: Node = null) -> void:
	if owner != null and _music_owner != owner: return
	_music_request += 1
	_music_owner = null
	if _music_fade != null:
		_music_fade.kill()
		_music_fade = null
	_remember_menu_music()
	_music_track = &""
	_playing_music_track = &""
	_music_departed_at = -1
	_music_player.stop()
	_music_player.stream = null

## 開始・移動中・終了音を専用の再生口へ渡す。ループと終了の音がなければ開始音だけ鳴らす。
func start_dash() -> void:
	var start: AudioStream = _sounds.get(DASH_SOUNDS[0])
	if _sounds.get(DASH_SOUNDS[1]) == null or _sounds.get(DASH_SOUNDS[2]) == null:
		if start != null:
			end_dash()
			_play_stream_once(DASH_SOUNDS[0])
		return
	end_dash()
	_dash_voice = DASH_VOICE.new()
	add_child(_dash_voice)
	var voices: Array[Dictionary] = []
	for id: StringName in DASH_SOUNDS:
		voices.append({"stream": _sounds.get(id), "volume_db": float(settings(id).get("volume_db", 0.0)), "pitch": pitch(id)})
	_dash_voice.start(voices)
func end_dash() -> void:
	if is_instance_valid(_dash_voice): _dash_voice.finish()
	_dash_voice = null

func _play_stream_once(id: StringName) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = &"Dash"
	player.stream = _sounds.get(id)
	player.volume_db = float(settings(id).get("volume_db", 0.0))
	player.pitch_scale = pitch(id)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

## HPが少ない間だけ心音をループで鳴らす。止めるときは短くフェードする。
func set_heartbeat(active: bool) -> void:
	if active == (_heartbeat_player.playing and _heartbeat_player.has_meta(&"active")): return
	if _heartbeat_fade != null: _heartbeat_fade.kill()
	if active:
		var stream: AudioStream = _sounds.get(HEARTBEAT)
		if stream == null:
			_reload_bank()
			stream = _sounds.get(HEARTBEAT)
		if stream == null: return
		_heartbeat_player.set_meta(&"active", true)
		_heartbeat_player.stream = stream
		_heartbeat_player.volume_db = float(settings(HEARTBEAT).get("volume_db", 0.0))
		_heartbeat_player.play()
		return
	_heartbeat_player.remove_meta(&"active")
	if not _heartbeat_player.playing: return
	_heartbeat_fade = create_tween().set_ignore_time_scale(true)
	_heartbeat_fade.tween_property(_heartbeat_player, "volume_db", -60.0, 0.3)
	_heartbeat_fade.tween_callback(_heartbeat_player.stop)

## 心音の拍の進み具合（0で拍が鳴った瞬間、1で次の拍）。鳴っていなければ負の値。
func heartbeat_phase() -> float:
	if not _heartbeat_player.playing or not _heartbeat_player.has_meta(&"active"): return -1.0
	var position := _heartbeat_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return fposmod(position - HEARTBEAT_FIRST_BEAT, HEARTBEAT_PERIOD) / HEARTBEAT_PERIOD

## ユーザー設定を保ったまま、BGM・効果音をまとめて減衰する。
func set_slow_motion(enabled: bool) -> void:
	if _slow_motion == enabled: return
	_slow_motion = enabled
	play(&"scene.run.slow_in" if enabled else &"scene.run.slow_out")
	if _slow_fade != null: _slow_fade.kill()
	_slow_fade = create_tween().set_ignore_time_scale(true)
	_slow_fade.tween_method(_set_slow_gain, _slow_gain, 0.35 if enabled else 1.0, 0.15 if enabled else 0.25)

func _set_slow_gain(gain: float) -> void:
	_slow_gain = gain
	_apply_volumes()

func _apply_volumes() -> void:
	var s := SaveManager.settings
	var slow_gain := _slow_gain
	_set_bus(&"Master", float(s.master_volume), bool(s.muted))
	_set_bus(&"SFX", float(s.sfx_volume) * slow_gain, false)
	_set_bus(&"Engine", float(s.engine_volume) * slow_gain, false)
	_set_bus(&"Music", float(s.get("music_volume", 0.5)) * slow_gain, false)
	_set_bus(&"Dash", float(s.sfx_volume), false)

func _set_bus(bus: StringName, linear: float, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, muted or linear <= 0.0)

func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, &"Master")

## 戦闘の音を鳴らすために購読するイベント。
func event_types() -> Array:
	var types: Array = EVENT_SOUNDS.keys() + EVENT_SPECIAL
	for type: StringName in EVENT_EXTRA:
		if type not in types: types.append(type)
	return types

## 中身で欄を変えるイベント。ほかは EVENT_SOUNDS の欄。
func _event_sound(type: StringName, data: Dictionary) -> StringName:
	match type:
		&"block_impact":
			if data.get("armor_bounce", false): return &"ship.combat.armor_block"
		&"barrier_hit":
			if data.get("broken", false): return &"weapon.barrier.break"
		&"chain_shock":
			if int(data.get("generation", 0)) > 0: return &"trait.chain_shock.chain"
		&"boss_phase":
			match String(data.get("boss", "")):
				"draco": return &"boss.draco.stage_shift"
				"canis_major": return &"boss.canis_major.sirius_wake"
	return EVENT_SOUNDS[type]

## C++側の通知を読むだけで、戦闘の更新や乱数には触れない。
func consume_cpp_frame(frame: Dictionary) -> bool:
	var ui: Dictionary = frame.get("ui", {})
	if ui.has("phase"): pause_loops(int(ui.phase) not in LOOP_PHASES)
	for event: Dictionary in frame.events:
		var data: Dictionary = event.payload
		var type := StringName(event.type)
		for extra: StringName in EVENT_EXTRA.get(type, []): play(extra)
		if EVENT_SOUNDS.has(type):
			play(_event_sound(type, data))
			continue
		match type:
			&"audio_cue":
				var cue := StringName(data.get("cue", &""))
				if data.has("life"): loop_for(cue, "%s#%d" % [cue, int(data.get("key", 0))], float(data.life))
				elif not data.has("loop"): play(cue)
				elif data.loop: start_loop(cue, "%s#%d" % [cue, int(data.get("key", 0))])
				else: stop_loop(cue, "%s#%d" % [cue, int(data.get("key", 0))])
			&"hit":
				var id: StringName = HIT_SOUNDS.get(String(data.get("cause", "")), &"")
				if id != &"": play(id)
			&"shot_hit":
				var id: StringName = SHOT_HIT_SOUNDS.get(String(data.get("visual_key", "")), &"")
				if id != &"": play(id)
			&"beam":
				var id: StringName = BEAM_SOUNDS.get(String(data.get("visual_key", "")), &"")
				if id != &"": play(id)
			&"bonus": play(&"field.bonus.enter" if data.get("enter", false) else &"field.bonus.exit")
			&"hero_power_end":
				match String(data.get("id", "")):
					"leo":
						stop_loop(&"hero.leo.run", &"hero.leo.run")
						play(&"hero.leo.revert")
					"gemini": play(&"hero.gemini.merge")
			&"end_hole": loop_for(&"trait.end_hole.pull", &"trait.end_hole.pull", float(data.get("life", 0.0)))
			&"hydra_cue":
				var cue := String(data.get("cue", ""))
				var pair: Array = HYDRA_SOUNDS.get(String(data.get("technique", "")), [&"", &""])
				var id: StringName = HYDRA_CUES.get(cue, pair[0] if cue in ["warning_started", "target_locked"] else pair[1] if cue == "attack_started" else &"")
				if id != &"": play(id)
			&"centaurus_cue":
				var id: StringName = CENTAURUS_CUES.get(String(data.get("cue", "")), &"")
				if id != &"": play(id)
			&"canis_cue":
				var id: StringName = CANIS_CUES.get(String(data.get("cue", "")), &"")
				if id != &"": play(id)
			&"draco_cue":
				var id: StringName = DRACO_CUES.get(String(data.get("cue", "")), &"")
				if id != &"": play(id)
			&"run_finished":
				if String(data.get("kind", "")) == "Clear": play(&"field.stage.clear")
			&"offer":
				if data.get("initial", false): play(&"growth.cards.start_choice")
			&"choice":
				var kind := String(data.get("kind", ""))
				var id: StringName = CHOICE_SOUNDS.get(kind, &"")
				if kind in ["weapon", "trait"] and int(data.get("level", 1)) > 1: id = &"growth.cards.level_up_item"
				if id != &"": play(id)
				play(&"growth.cards.apply")
			&"level_bonus": play(&"growth.cards.combo", 1.0 + 0.06 * minf(float(data.get("count", 1)) - 1.0, 8.0))
			&"reroll": play(&"growth.cards.reroll")
			&"enemy_retire": _stop_enemy_loops(int(data.get("id", 0)))
			&"kill":
				_stop_enemy_loops(int(data.get("id", 0)))
				if data.get("silent", false): continue
				play(&"ship.combat.kill")
				if data.get("elite", false): play(&"ship.combat.elite_kill")
				var id: StringName = KILL_SOUNDS.get(StringName(data.get("enemy_type", &"")), &"")
				if id != &"": play(id)
			&"weapon_fire":
				if data.get("id") in [&"W01", &"W23"]: play(&"weapon.blaster.fire")
				elif data.get("id") == &"W02": play(&"weapon.spread.fire")
			&"launch": start_dash()
			&"trace_end": end_dash()
			&"game_over":
				end_dash()
				play_music(&"music.game_over", 1.0, self)
			&"pickup":
				var id: StringName = PICKUP_SOUNDS.get(StringName(data.get("kind", &"")), &"")
				if id != &"": play(id)
				if StringName(data.get("kind", &"")) == &"heal": play(&"ship.combat.heal")
				elif StringName(data.get("kind", &"")) == &"magnet": play(&"field.beacon.rush")
			&"xp_collect":
				var rank := -1
				for gem: Dictionary in data.get("gems", []): rank = maxi(rank, int(XP_RANK.get(String(gem.get("kind", "")), 0)))
				if rank >= 0: play([&"growth.level.xp_low", &"growth.level.xp_mid", &"growth.level.xp_high"][rank])
			&"explode":
				var id: StringName = EXPLODE_SOUNDS.get(String(data.get("cause", "")), &"")
				if id != &"": play(id)
			&"shoot":
				if String(data.get("kind", "")) in ["bullet", "missile", "shell"]: play(&"enemy.bullet.fire")
			&"hero_power":
				var id: StringName = HERO_SOUNDS.get(String(data.get("id", "")), &"")
				if id != &"": play(id)
				if String(data.get("id", "")) == "leo": start_loop(&"hero.leo.run", &"hero.leo.run")
	return true
