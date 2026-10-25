extends Node
func _ready() -> void:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true);stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":605},true)
	session.auto_step=false
	session.sim.state.final_modules=[&"legendary_stern",&"legendary_keel",&"legendary_sail",&"legendary_compass"]
	var hud=session.view.get_node("Hud/HudRoot")
	hud._refresh_loadout_icons()
	var count:=0
	for node in hud._loadout_icons.get_children():
		if node is ModulePreview:count+=1
	var passed: bool=count==4
	if not passed:push_error("合体後の武器欄に四つの伝説の部品図を表示する")
	session.free()
	print("[draco_finale_hud] modules=",count)
	get_tree().quit(0 if passed else 1)
