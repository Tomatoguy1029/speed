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
			var trait: TraitDef = ContentManager.definition(&"traits",&"T08")
			_cpp_ui.capacity += trait.stack_bonus(capacity_level)
		_cpp_ui.draw.gauge = 1.0

func _process(delta: float) -> void:
	_layout_cpp_art()
	if not preview_paused:
		_update_speed_indicator(delta)
		_ring_pulse_t = maxf(0.0,_ring_pulse_t-delta)
		_ring_flash_t = maxf(0.0,_ring_flash_t-delta)
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
	var cursor := get_viewport().get_mouse_position() if follow_cursor else preview_cursor
	var at := cursor+Vector2(26,26)
	var capacity := float(_cpp_ui.capacity) if preview_mode==5 or reward_preview else 1.5
	var amount := float(state.gauge)*capacity
	var drawing: bool = state.drawing
	if preview_mode!=5 and not reward_preview:
		amount = 0.1 if preview_mode==1 else 1.5 if preview_mode==4 else 1.1
		drawing = preview_mode==2
	var usable := amount >= float(_cpp_ui.min_charge)
	if preview_mode==5:
		var charging := not state.drawing and not state.tracing
		if usable and not _ring_usable and charging: _ring_pulse_t = RING_PULSE_TIME
		if charging and _lap_filled(_ring_amount,amount,capacity):
			_ring_flash_t = RING_FLASH_TIME
			_ring_flash_max = RING_FLASH_TIME
		_ring_usable = usable
		_ring_amount = amount
	if drawing:
		amount = float(state.draw_gauge)*(1.0-float(state.draw_length)/maxf(1.0,float(state.draw_limit))) if preview_mode==5 else 1.1*(1.0-120.0/300.0)
	var pulse := fmod(preview_clock,RING_PULSE_TIME)/RING_PULSE_TIME if preview_mode==3 else -1.0
	var flash := 1.0-fmod(preview_clock,RING_FLASH_TIME)/RING_FLASH_TIME if preview_mode==4 else 0.0
	if preview_mode==5:
		pulse = 1.0-_ring_pulse_t/RING_PULSE_TIME if _ring_pulse_t>0.0 else -1.0
		flash = _ring_flash_t/_ring_flash_max if _ring_flash_t>0.0 else 0.0
	BOOST_GAUGE.draw(self,at,amount,capacity,float(_cpp_ui.min_charge),drawing,usable,flash,pulse,BOOST_GAUGE.style_for(preview_values),RING_GAP)
