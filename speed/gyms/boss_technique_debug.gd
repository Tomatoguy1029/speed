## 編集用コピーから、単独ボスの本番C++経路へ試行を依頼する。
extends RefCounted

const PROGRAM := preload("res://tools/content/build_boss_program.gd")
const BOSSES: Array[StringName] = [&"monoceros", &"centaurus", &"canis_major", &"hydra", &"draco"]
var session
var boss := ""
var entity_id := -1
var program: Resource
var action_rules: Resource
var _moves := {}
var active := false
var message := ""
var requested := ""
var _saved := {}
var _origin := Vector2.ZERO
var _pending_start := false

func bind(value, id: String, source: Resource = null) -> bool:
	if not OS.is_debug_build() or StringName(id) not in BOSSES: return false
	if value == null or value.bridge == null: return false
	if source == null:
		var path: String = value._output.path_join("boss_%s.tres" % id)
		var built: Dictionary = PROGRAM.build_boss(id,path)
		if built.get("error",ERR_INVALID_DATA)!=OK: return false
		source = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if source == null or source.get("data") is not Dictionary or source.data.get("rules")==null: return false
	session = value
	boss = id
	entity_id = session._selected_id
	program = source
	action_rules = source.data.rules
	for move in action_rules.techniques: _moves[StringName(move.technique)] = move
	var body := state()
	if body.is_empty(): return false
	_origin = body.position
	return true

func state() -> Dictionary:
	if session == null or session.bridge == null: return {}
	var result: Dictionary = session.bridge.boss_trial(entity_id,"state")
	return result.value if result.ok else {}

## 読取値は決着中も表示に使う。制御命令の可否はC++側で判定する。
func body_snapshot() -> Dictionary:
	if session == null or session.bridge == null: return {}
	var result: Dictionary = session.bridge.command("dev_boss_body_state",{})
	if result.ok:
		for body: Dictionary in result.value:
			if body.actor == entity_id: return body
	return {}

func action(id: String, fields: Dictionary = {}) -> bool:
	if session == null or session.bridge == null: return false
	var result: Dictionary = session.bridge.boss_trial(entity_id,id,fields)
	if not result.ok: message = result.message
	session._refresh_projection()
	return result.ok

func advance() -> void:
	if not _pending_start: return
	var body := state()
	if body.is_empty() or float(body.get("separation_left",0.0))>0: return
	_pending_start = not action("start",{"technique":requested})

func repeat() -> bool:
	if requested.is_empty() or attack_playing(): return false
	if _pending_start: return false
	return action("restart") if action_rules.combos.has(requested) else action("start",{"technique":requested})

func moves() -> Array:
	return action_rules.techniques if action_rules != null else []

func has_body() -> bool:
	return not state().is_empty()

func attack_playing() -> bool:
	return state().get("busy",false)

func unavailable(id: String, phase: int) -> String:
	if not has_body(): return "ボスが不在または決着中です。ボスを選び直してください。"
	if phase < 1 or phase > (4 if boss=="hydra" else 3 if boss=="draco" else 2): return "存在しない形態です。"
	if boss=="canis_major" and id=="hunt_pounce" and phase!=1: return "この技は第1形態で再生してください。"
	if not _moves.has(StringName(id)) and not action_rules.combos.has(id): return "未登録の技: " + id
	if boss=="hydra":
		if id in ["swarm","grid"] and phase!=4:return "この技は分離後に再生してください。"
		if id in ["north","sequence","curve"] and phase not in [2,3]:return "この技は5本か8本の首で再生してください。"
		if id=="beam_pincer" and phase<3:return "この技には8本の首が必要です。"
		if id in ["beam_fixed","beam_bolt","thunder_drop","thunder_headbutt","debris_shatter"] and phase<2:return "この技には5本以上の首が必要です。"

	return ""

func _first_action(node: Dictionary) -> String:
	if node.get("type","") == "action": return String(node.get("id",""))
	for child in node.get("children",[]):
		var id := _first_action(child)
		if not id.is_empty(): return id
	return ""

func prepare(phase: int, point: Vector2, selection: bool, guard: float, steering: bool) -> bool:
	var fields := {"phase":phase,"origin":_origin,"target":point,"selection":selection,"guard":guard,"steering_locked":steering}
	if boss in ["hydra","draco"]: fields.logical_size=session.scene.view.get_viewport().get_visible_rect().size
	var result: Dictionary = session.bridge.boss_trial(entity_id,"prepare",fields)
	if not result.ok: message = result.message
	session._refresh_projection()
	return result.ok

func execute(id: String, phase: int, animate_split := false) -> bool:
	message = unavailable(id,phase)
	if not message.is_empty(): return false
	if not active: _saved = state()
	var source: Dictionary = PROGRAM.snapshot(program.data)
	var rules: Resource = source.rules
	var combo: bool = rules.combos.has(id)
	var first := _first_action(rules.combos[id]) if combo else id
	var gate: Dictionary = rules.conditions.get(first,{})
	var outer: Dictionary = rules.conditions.get(id,{})
	var minimum := maxf(float(gate.get("min",0.0)),float(outer.get("min",0.0)))
	var maximum := minf(float(gate.get("max",1400.0)),float(outer.get("max",1400.0)))
	if maximum < minimum:
		message = "コンボの開始距離が重なっていません。"
		return false
	phase = clampi(phase,maxi(int(gate.get("min_phase",1)),int(outer.get("min_phase",1))),4 if boss=="hydra" else 3 if boss=="draco" else 2)
	var point := _origin + Vector2.from_angle(deg_to_rad(float(gate.get("angle",0.0)))) * (minimum + maxf(minimum,minf(1400.0,maximum))) * 0.5
	var prepared_phase := 3 if animate_split and boss=="hydra" and phase==4 else phase
	if not prepare(prepared_phase,point,false,0.0,_saved.steering_locked): return false
	active = true
	if combo:
		for node in rules.node_ids():
			var binding: Dictionary = rules.graph_nodes.get(node,{}).duplicate()
			binding.source = rules.source_for(node)
			binding.connected = binding.source == id
			rules.graph_nodes[node] = binding
		var flow: Resource = source.flow
		flow.maximum_stamina = maxf(20.0,float(rules.costs.get(id,1.0)))
		flow.sections = [{"request":"any","cap":flow.maximum_stamina,"next":1,"weights":{"single":100.0,"combo":100.0,"major":100.0}}, {"request":"any","cap":flow.maximum_stamina,"next":1,"weights":{}}]
	var replaced: Dictionary = session.set_boss_program(boss,source)
	if not replaced.get("ok",false):
		message = replaced.get("message","試行の定義を生成できません。")
		return false
	if not prepare(prepared_phase,point,combo,0.0,_saved.steering_locked): return false
	if animate_split and boss=="hydra" and phase==4 and not action("separate"): return false
	requested = id
	session._apply("pin",{"value":combo,"pos":point})
	_pending_start = animate_split and boss=="hydra" and phase==4 and not combo
	if not combo and not _pending_start:
		var result: Dictionary = session.bridge.boss_trial(entity_id,"start",{"technique":id})
		if not result.ok:
			message = "開始できませんでした: " + id
			return false
	message = "実行: " + id
	return true

func finish() -> void:
	if not active: return
	if session.bridge==null:
		active = false
		_pending_start = false
		_saved.clear()
		requested = ""
		return
	if has_body():
		var point: Vector2 = session.run.state.ship_pos
		if prepare(_saved.phase,point,false,_saved.guard,_saved.steering_locked):
			var restored: Dictionary = session.set_boss_program(boss,program.data)
			if restored.ok: prepare(_saved.phase,point,_saved.selection,_saved.guard,_saved.steering_locked)
	session._apply("pin",{"value":_saved.get("pinned",false),"pos":_saved.get("pin",Vector2.ZERO)})
	active = false
	_pending_start = false
	_saved.clear()
	requested = ""
	message = "手動実行終了・通常AI"

func status() -> String:
	var body := state()
	if body.is_empty(): return "ボスなし"
	return "%s / 形態%d / %s" % ["手動" if active else "AI",body.phase,body.technique if body.busy else "待機"]
