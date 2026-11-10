## 本番のC++読取HUDへ、表示専用の編集値と所有装備だけを重ねる。
extends "res://scripts/ui/hud.gd"

var config: GameConfig
var preview_values: Dictionary = {}
var preview_owned: Dictionary = {}
var preview_mode := 0
var preview_clock := 0.0
var preview_cursor := Vector2.ZERO
var follow_cursor := false
var preview_paused := false
var reward_preview := false

func _ready() -> void:
	super._ready()
	# 報酬編集面の接続・取消は、表示用ランへの報酬コマンドも起こさない。
	for connection: Dictionary in _rewards.active_changed.get_connections():
		_rewards.active_changed.disconnect(connection.callable)

func _input(_event: InputEvent) -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _exit_tree() -> void:
	if bridge != null: bridge.unsubscribe("hud")

func _receive_cpp_frame(frame: Dictionary) -> bool:
	apply_snapshot(frame.ui)
	return true

func apply_snapshot(ui: Dictionary) -> void:
	# 保持するのはHUDの表示コピー。所有装備をC++のloadoutへgrantしない。
	_cpp_ui = ui.duplicate(true)
	if reward_preview:
		_cpp_ui.hp = _cpp_ui.max_hp
		_cpp_ui.xp = float(_cpp_ui.get("next_xp",1.0))*0.5
		_cpp_ui.capacity = 1.0
		var capacity_level := int(preview_owned.get("traits",{}).get(&"T08",0))
		if capacity_level>0:
			var definition: TraitDef = ContentManager.definition(&"traits",&"T08")
			_cpp_ui.capacity += definition.stack_bonus(capacity_level)
		_cpp_ui.draw.gauge = 1.0
		_cpp_ui.fuel_max = config.fuel_capacity*float(_cpp_ui.capacity)
		_cpp_ui.fuel = _cpp_ui.fuel_max
		_cpp_ui.draw.fuel = _cpp_ui.fuel
		_cpp_ui.draw.fuel_preview = _cpp_ui.fuel

func _process(delta: float) -> void:
	_layout_cpp_art()
	if not preview_paused:
		_update_fuel_meter()
		_fuel_meter.normal_color = preview_values.get("normal_color",BOOST_STYLE.normal_color)
		if preview_mode==1: _fuel_meter.fuel = 0.0
	queue_redraw()

func _draw_cpp() -> void:
	super._draw_cpp()
	if _cpp_ui.is_empty() or config == null: return
	var owned := preview_owned
	if not reward_preview:
		owned = {"weapons":{},"traits":{}}
		for kind in ["weapon","trait"]:
			for item: Dictionary in _cpp_ui.get(kind+"_levels",[]): owned[kind+"s"][StringName(item.id)] = int(item.level)
	var factor := minf(size.x/ART_SIZE.x,size.y/ART_SIZE.y)
	draw_set_transform((size-ART_SIZE*factor)*0.5,0.0,Vector2.ONE*factor)
	draw_texture_rect_region(SLOTS,LOADOUT_REGION,LOADOUT_REGION)
	_draw_slot_row(LOADOUT_WEAPON,true,config.weapon_slots,config.weapon_max_level,owned.get("weapons",{}),ContentManager.catalog.table(&"weapons"))
	_draw_slot_row(LOADOUT_TRAIT,false,config.trait_slots,config.trait_max_stacks,owned.get("traits",{}),ContentManager.catalog.table(&"traits"))
	draw_set_transform(Vector2.ZERO)

func _draw_cpp_gauge_ring() -> void:
	if _cpp_ui.is_empty(): return
	var state: Dictionary = _cpp_ui.draw
	var drawing: bool = state.drawing if preview_mode==3 or reward_preview else preview_mode==2
	if not drawing: return
	var cursor := get_viewport().get_mouse_position() if follow_cursor else preview_cursor
	var remaining := float(state.draw_limit)-float(state.draw_connection)-float(state.draw_length)
	var ratio := clampf(remaining/maxf(0.001,float(state.draw_limit)),0.0,1.0) if preview_mode==3 else 0.6
	BOOST_GAUGE.draw(self,cursor+Vector2(26,26),ratio,BOOST_GAUGE.style_for(preview_values))
