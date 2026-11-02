## 生成直後・グリッド更新後の移動・巨大な特殊外観でも、描画の候補を欠落させない。
extends Node
class LargeVisual:
	extends EnemyVisual
	func sprite_radius(table: EnemyTable,row: int) -> float: return table.r[row]*20.0
var passed := 0
var failed := 0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error(label)
func settle() -> void:
	for frame in 3:
		await get_tree().process_frame
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func _ready() -> void:
	var session:=RunManager.create_session(self,{"lab":true,"seed":401,"stage_index":4},true)
	session.auto_step=false
	var run:=session.sim
	var view:RunPresentation=session.view.get_node("RunPresentation")
	view.view_override={"center":Vector2.ZERO,"zoom":1.0}
	run.enemies.clear_all()
	run.combat.rebuild_grid()
	await settle()
	var at:=view.view_rect().get_center()
	var row:=run.enemies.spawn(run.enemies.def_of(&"biter"),at)
	var candidates:=PackedInt32Array()
	var bounds:=view.view_rect().grow(run.combat.enemy_query_padding)
	run.combat.grid.query(bounds.position,bounds.end,candidates)
	check(not candidates.has(row),"既存グリッドには更新後に生成した敵がまだ入らない")
	await settle()
	check(view._batches[&"biter"]._count==1,"描画は生成直後の敵を同じフレーム系列で表示する")
	run.enemies.table.pos[row]=at+Vector2(10000,0)
	run.combat.rebuild_grid()
	run.enemies.table.pos[row]=at
	run.combat.grid.query(bounds.position,bounds.end,candidates)
	check(not candidates.has(row),"グリッド更新後に画面内へ動いた行も古いセルには残る")
	await settle()
	check(view._batches[&"biter"]._count==1,"古いセルを候補の正本にせず現在位置の敵を表示する")
	run.enemies.clear_all()
	var visual:=LargeVisual.new()
	visual.setup(view,&"biter")
	view._type_visuals[&"biter"]=visual
	var radius:=26.0
	var extra:=maxf(0.0,radius*20.0*sqrt(2.0)-run.combat.enemy_query_padding)
	var expanded:=bounds.grow(extra)
	var points:=[Vector2(expanded.position.x,at.y),Vector2(expanded.position.x-0.25,at.y),Vector2(expanded.end.x-0.25,at.y),Vector2(expanded.end.x,at.y)]
	var expected: Array[Vector2]=[]
	for point:Vector2 in points:
		row=run.enemies.spawn(run.enemies.def_of(&"biter"),point)
		run.enemies.table.r[row]=radius
		if expanded.has_point(point): expected.append(point)
	await settle()
	var batch:InstanceBatch=view._batches[&"biter"]
	check(expected.size()==2 and batch._count==expected.size(),"巨大な特殊Visualの半径と左端包含・右端除外を維持")
	for i in expected.size():
		check(Vector2(batch._buf[i*12+3],batch._buf[i*12+7])==expected[i],"画面端の判定でも行順と変換位置を変えない")
	session.free()
	await get_tree().process_frame
	print("[render_visibility] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
