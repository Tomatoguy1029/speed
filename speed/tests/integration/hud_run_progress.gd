## 実ランの時計・審査版のボス移動・登場スキップからHUDの表示を確認する。
extends Node
const BRIDGE := preload("res://scripts/runtime/run_bridge.gd")
var failed := 0
var progress_script: Script
func check(ok: bool, label: String) -> void:
	if not ok:
		failed+=1
		push_error(label)
func make_run(stage: int, mode: int=2) -> RefCounted:
	var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.content/run/stage_%d.json" % stage))
	var bridge=BRIDGE.new()
	if not bridge.configure(FileAccess.get_file_as_bytes(index.binary),{"api_version":1,"run_id":760,"mode":mode,"stage_id":str(stage),"profile":{},"settings":{}}).ok:return null
	if not bridge.start(932).ok:return null
	return bridge
func _ready() -> void:
	var bridge:=make_run(2)
	check(bridge!=null,"ステージ時計のランを開始する")
	if bridge==null:get_tree().quit(1);return
	var ui: Dictionary=bridge.read_frame().value.ui
	check(ui.has("stage_clock"),"HUDへ実際の制限時間とボス出現予定を配信する")
	if not ui.has("stage_clock"):bridge.dispose();get_tree().quit(1);return
	progress_script=load("res://scripts/ui/run_progress.gd")
	check(progress_script!=null,"進行表示を読み込める")
	if progress_script==null:bridge.dispose();get_tree().quit(1);return
	check(ui.stage_clock.time_limit==900.0 and ui.stage_clock.boss_at>=495.0,"ステージ2の実効時計を表示へ渡す")
	var state: Dictionary=progress_script.project(ui)
	check(state.progress_alpha==1.0 and state.hp_alpha==0.0 and state.countdown=="","開始時は進行バーだけを表示する")
	var preview: Control=load("res://gyms/game_context_hud.gd").new()
	preview.bridge=bridge
	preview.config=ContentManager.cfg
	add_child(preview)
	bridge.collect_frame()
	preview._process(0.0)
	check(preview._stage_progress.visible and preview._stage_progress._view.progress_alpha==1.0,"実験場のプレビューHUDも進行表示を更新する")
	preview.show_status=false
	preview._process(0.0)
	check(not preview._stage_progress.visible,"プレビューの状態表示オフも反映する")
	preview.free()
	for remaining in [301.0,300.0,299.0,0.0]:
		var sample: Dictionary=ui.duplicate(true)
		sample.run_time=float(ui.stage_clock.time_limit)-remaining
		var expected: String="" if remaining>300.0 else "%d:%02d" % [int(remaining)/60,int(remaining)%60]
		check(progress_script.project(sample).countdown==expected,"制限時間の残り%.0f秒の表示境界" % remaining)
	var unlimited: Dictionary=ui.duplicate(true)
	unlimited.stage_clock.time_limit=-1.0
	check(progress_script.project(unlimited).countdown=="","時間制限なしではカウントダウンしない")
	check(bridge.command("pause",{"paused":true}).ok and bridge.command("review_boss").ok,"審査版の移動で本物のボスを登場させる")
	ui=bridge.read_frame().value.ui
	check(ui.run_time==ui.stage_clock.boss_at and not ui.boss_bodies.is_empty(),"予定時刻への移動と登場を同じフレームで読む")
	if ui.boss_bodies.is_empty():bridge.dispose();get_tree().quit(1);return
	for seconds in [0.0,0.8,1.6,2.1,2.6,90.0]:
		var sample: Dictionary=ui.duplicate(true)
		sample.boss_bodies[0].clock=seconds
		state=progress_script.project(sample)
		if seconds<1.6:check(state.progress_alpha>0.0 and state.hp_alpha==0.0,"進行表示を先に消す: %.1f秒" % seconds)
		elif seconds==1.6:check(state.progress_alpha==0.0 and state.hp_alpha==0.0,"消去後にHP表示を始める")
		else:check(state.progress_alpha==0.0 and state.hp_alpha>0.0,"同じ場所のボスHPへ移る: %.1f秒" % seconds)
	check(is_equal_approx(state.hp_ratio,float(ui.boss_bodies[0].hp)/float(ui.boss_bodies[0].max_hp)),"実際のボスHPを表示する")
	var after_boss: Dictionary=ui.duplicate(true)
	after_boss.boss_bodies[0].mode=4
	state=progress_script.project(after_boss)
	check(state.progress_alpha==0.0 and state.hp_alpha==0.0,"ボス撃破後に進行バーを戻さない")
	var rewind: Dictionary=bridge.read_frame().value.ui.duplicate(true)
	rewind.boss_bodies=[];rewind.stage_clock.boss_spawned=false;rewind.run_time=30.0
	check(progress_script.project(rewind).progress_alpha==1.0,"ボス前への巻き戻しで進行表示を戻す")
	bridge.dispose()
	var draco:=make_run(5)
	check(draco!=null,"登場スキップのランを開始する")
	if draco!=null:
		check(draco.command("pause",{"paused":true}).ok and draco.command("review_boss").ok,"りゅう座の通常登場へ移る")
		check(draco.command("skip_boss_entrance").ok,"実際の登場スキップを通す")
		var resumed: Dictionary=draco.read_frame().value.ui
		check(not resumed.boss_bodies.is_empty() and not resumed.boss_bodies[0].get("intro",{}).get("active",false),"登場スキップ後のボス状態を読む")
		if not resumed.boss_bodies.is_empty():
			state=progress_script.project(resumed)
			check(state.progress<=1.0 and state.progress_alpha<=1.0,"スキップ後も実際のボス状態から投影する")
		draco.dispose()
	print("[hud_run_progress] failed=",failed)
	get_tree().quit(1 if failed else 0)
