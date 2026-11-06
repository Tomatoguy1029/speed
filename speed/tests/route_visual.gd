## 攻撃半径、丸い端、交差と折り返しを含む航路の表示契約。
extends Node
const ROUTE := preload("res://scripts/render/route_visual.gd")
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	var route := ROUTE.new()
	add_child(route)
	var straight := PackedVector2Array([Vector2.ZERO, Vector2(200,0)])
	route.set_route(straight, 30.0, Color.CYAN, 1.0)
	check(route._radius == 30.0 and route._path == straight, "C++が渡した中心線と攻撃半径を保つ")
	check(not route._boundary.is_empty() and route._boundary.size() % 2 == 0, "点線を線分の組として用意する")
	for point: Vector2 in route._boundary:
		var nearest := Vector2(clampf(point.x,0.0,200.0),0.0)
		check(absf(point.distance_to(nearest)-30.0) < 1.0, "直線の両側と丸い端が実効半径に一致する")
	check(route._sample(100.0).is_equal_approx(Vector2(100,0)), "矢羽根をルート上の距離で配置する")
	for points in [PackedVector2Array([Vector2.ZERO,Vector2(100,0),Vector2(100,100)]), PackedVector2Array([Vector2.ZERO,Vector2(100,100),Vector2(0,100),Vector2(100,0)]), PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2(100,0),Vector2.ZERO])]:
		route.set_route(points, 30.0, Color.GOLD, 2.0)
		check(route.visible and not route._boundary.is_empty(), "曲がり角・交差・折り返しも囲める")
		for point: Vector2 in route._boundary:
			check(point.is_finite(), "境界に無効な座標を含めない")
	var band := {"owner_id":0,"layer":3,"order":0,"kind":ROUTE.SHAPES.Polyline,"rounded":true,"points":straight,"widths":PackedFloat32Array([90.0]),"colors":PackedColorArray([Color.CYAN])}
	route.sync_shapes([band],1.0)
	check(route.visible and route._radius == 45.0, "RenderFrameの幅の変化を範囲へ反映する")
	var twin := band.duplicate()
	twin.order = 2
	check(not ROUTE.is_route_shape(twin), "双子の航路は専用表示へ置き換えない")
	twin.order = 0
	twin.owner_id = 10
	check(not ROUTE.is_route_shape(twin), "敵の線は専用表示へ置き換えない")
	route.sync_shapes([],1.0)
	check(not route.visible, "ルート終了時に境界と矢羽根が消える")
	route.set_route(straight,45.0,Color.CYAN,1.0)
	check(route.visible, "同じルートを再表示できる")
	route.queue_free()
	print("[route_visual] failures=", failed)
	get_tree().quit(1 if failed else 0)
