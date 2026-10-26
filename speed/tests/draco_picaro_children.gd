extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func _ready() -> void:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true);stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":505},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var a=sim.bosses.actor
	var row: int=a.picaro.spawn_picaro(&"triangle",Vector2(700,0))
	var parts: PackedInt32Array=a.table.parts[row].duplicate()
	sim.enemies.mark_dead(row);sim.enemies.cleanup();a.picaro.tick()
	for j in range(0,parts.size(),2):check(not sim.enemies.is_same(parts[j],parts[j+1]) or a.table.dead[parts[j]]!=0,"親の行が解放されても、保持した部位を残さない")
	a.picaro.clear()
	a.picaro.spawn_picaro(&"cepheus",Vector2(700,0))
	for frame in 300:
		sim.enemies.tick(1.0/60.0,1.0/60.0)
		a.sim_tick(1.0/60.0,1.0/60.0)
	var soldiers: Array=[]
	for i in a.table.alive.size():
		if a.table.alive[i]!=0 and a.table.dead[i]==0 and a.table.type[i]==&"cepheus_soldier":soldiers.append(i)
	check(not soldiers.is_empty(),"元の王の行動で兵を召喚する")
	for soldier: int in soldiers:check(a.table.def[soldier].params.get("picaro",false),"召喚した兵も同じコズミック版になる")
	a.picaro.pause(true)
	for soldier: int in soldiers:check(a.table.held[soldier]!=0,"攻撃担当の停止は増援にも適用する")
	a.picaro.clear();a.cancel_attack();a.cycle.cancel()
	a.start_attack(&"clones")
	var driver=a._driver
	var copy: int=driver.units[1].row
	var part: int=driver.units[1].parts[0].row
	a.table.pos[driver.units[1].parts[-1].row]=a.table.pos[copy]+Vector2(-500,0)
	check(sim.bosses.contains_target(copy,a.table.pos[driver.units[1].parts[-1].row],0.0),"複製も尾まで同じ対象の内部として扱う")
	sim.enemies.mark_dead(copy);sim.enemies.cleanup()
	var fresh:=sim.enemies.spawn(sim.enemies.def_of(&"biter"),Vector2(3000,0))
	var hp: float=a.table.hp[fresh]
	sim.combat.damage_enemy(part,10.0,{"cause":&"shot"})
	check(a.table.hp[fresh]==hp,"行が再利用されても複製の古い部位から別の敵へ命中しない")
	a.cancel_attack();a.picaro.clear()
	session.free()
	print("[draco_picaro_children] failures=",failures)
	get_tree().quit(1 if failures else 0)
