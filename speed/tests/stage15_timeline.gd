extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1;push_error(label)
func _ready() -> void:
	var s1: StageDef=load("res://data/stages/stage_1.tres")
	check(s1.boss_time==495.0 and s1.boss_id==&"monoceros","ステージ1の六山と8分15秒のボス接続を保つ")
	var s5: StageDef=load("res://data/stages/stage_5.tres")
	check(s5.boss_time==495.0,"ステージ5のボスは8分15秒に登場する")
	var starts: Array = s5.phases.map(func(p): return p.start)
	check(starts==[0.0,45.0,90.0,115.0,170.0,195.0,265.0,290.0,370.0,395.0,480.0,600.0],"道中とボス戦中の区間境界を保存する")
	check(s5.zako_curves.size()==3,"噛みつき・分裂・自爆の三曲線を持つ")
	for curve: SpawnCurve in s5.zako_curves:
		check(curve.type in [&"biter",&"splitter",&"bomber"],"硬めの敵を混ぜない")
	for phase in [s5.phases[0],s5.phases[2],s5.phases[4],s5.phases[6],s5.phases[8]]:
		check(phase.xp_bonus>1.0,"育成に経験値倍率を配分する")
	check(not s5.clips.is_empty(),"育成の少数強敵を配置する")
	var crow := s5.clips.filter(func(c): return &"crow" in c.types)
	check(crow.size()==1 and crow[0].time==115.0 and crow[0].end_time()==480.0,"カラスは山2から育成を含め最後まで継続する")
	check(s5.clips.any(func(c): return c.time==45.0 and &"cross" in c.types),"山1に線の攻撃を配置する")
	check(s5.clips.any(func(c): return c.time==115.0 and &"auriga" in c.types),"山2に移動する残留攻撃を配置する")
	check(s5.clips.any(func(c): return c.time==195.0 and &"cepheus" in c.types),"山3に王と軍勢を置く")
	check(s5.clips.any(func(c): return c.time==290.0 and &"aquila" in c.types),"山4に雷の大物を置く")
	# 種類別のクリップを合わせた編成を確認し、同じクリップへの同居は要求しない。
	for stage: StageDef in [s5, ContentManager.runtime_stage(5)]:
		var before := PackedStringArray(["cepheus", "crab", "cross", "crow", "dolphin"])
		var after := PackedStringArray(["aquila", "auriga", "cepheus", "crow", "pump"])
		check(active_clip_types(stage, 395.0) == before, "山5前半は軍勢・波・近距離・線と継続するカラスを配置する")
		check(active_clip_types(stage, 437.49) == before, "切り替え直前まで前半の編成を維持する")
		check(active_clip_types(stage, 437.5) == after, "山5後半に軍勢から雷と炎へ入れ替える")
		check(active_clip_types(stage, 479.99) == after, "山5後半の編成は道中の終端まで続く")
		check(active_clip_types(stage, 480.0).is_empty(), "ボス登場時刻に道中の強敵の補充を終える")
	print("[stage15_timeline] failures=",failures)
	get_tree().quit(1 if failures else 0)

func active_clip_types(stage: StageDef, time: float) -> PackedStringArray:
	var types := PackedStringArray()
	for clip: SpawnClip in stage.clips:
		if time < clip.time or time >= clip.end_time(): continue
		for type: StringName in clip.types:
			if not types.has(String(type)): types.append(String(type))
	types.sort()
	return types
