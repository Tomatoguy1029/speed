## 試作 canis.js の predatoryCurve / predatoryParts。時間は本番の飛行状態から受け取る。
extends RefCounted

const LEGS := ["RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg"]
const FRONT_TRAVEL := [[-0.7,0.0],[-0.18,-1.0],[-0.06,-3.0],[0.035,7.0],[0.17,3.0],[0.32,8.0],[0.4,4.0],[0.46,-5.0],[0.54,-3.0],[0.7,0.0]]
const REAR_TRAVEL := [[-0.7,0.0],[-0.18,2.0],[-0.06,4.0],[0.035,-7.0],[0.15,-5.0],[0.32,-2.0],[0.42,2.0],[0.49,5.0],[0.57,2.0],[0.7,0.0]]
const FRONT_ANGLE := [[-0.7,0.0],[-0.16,0.05],[-0.06,0.07],[0.04,0.01],[0.17,0.1],[0.32,0.0],[0.43,0.025],[0.53,0.06],[0.7,0.0]]
const REAR_ANGLE := [[-0.7,0.0],[-0.18,0.06],[-0.06,0.12],[0.04,0.02],[0.19,0.055],[0.4,0.06],[0.5,0.11],[0.7,0.0]]
const CHEST := [[-0.7,0.0],[-0.18,-1.0],[-0.06,-3.0],[0.035,3.0],[0.2,3.0],[0.4,1.0],[0.48,-3.0],[0.67,0.0]]
const NECK := [[-0.7,0.0],[-0.17,-1.0],[-0.055,-4.0],[0.035,5.0],[0.3,6.0],[0.43,7.0],[0.5,0.0],[0.66,0.0]]
const TAIL := [[-0.7,0.0],[-0.12,0.025],[0.09,-0.03],[0.38,-0.015],[0.53,0.03],[0.7,0.0]]

static func curve(time: float, keys: Array) -> float:
	if time<=float(keys[0][0]): return float(keys[0][1])
	for i in range(1,keys.size()):
		if time<=float(keys[i][0]):
			return lerpf(float(keys[i-1][1]),float(keys[i][1]),smoothstep(float(keys[i-1][0]),float(keys[i][0]),time))
	return float(keys.back()[1])

## load: 予兆開始からの時間と予兆長、strike: 飛行経過と飛行長、catch: 着地経過。
static func apply(parts: Node2D, origins: Dictionary, phase: String, age: float, span: float) -> void:
	var time := age-span if phase=="load" else age/maxf(span,0.001)*0.45 if phase=="strike" else 0.45+age
	for name: String in LEGS:
		var front := name.begins_with("Front")
		var side := -1.0 if name.contains("Left") else 1.0
		var sample := time-(0.018 if side>0.0 else 0.0)
		var node := parts.get_node(name) as Node2D
		node.position = origins[name]+Vector2(0,curve(sample,FRONT_TRAVEL if front else REAR_TRAVEL))
		node.rotation = side*curve(sample,FRONT_ANGLE if front else REAR_ANGLE)
		node.scale = Vector2.ONE
	var body := parts.get_node("Body") as Node2D
	body.position = Vector2(0,curve(time,CHEST))
	body.rotation = 0.0
	body.scale = Vector2.ONE
	var head := parts.get_node("Head") as Node2D
	head.position = origins.Head+Vector2(0,curve(time,NECK))
	head.rotation = 0.0
	head.scale = Vector2.ONE
	var tail := parts.get_node("Tail") as Node2D
	tail.rotation = curve(time,TAIL)
	tail.scale = Vector2.ONE

## 試作 pounceFeet。後ろ足は着地姿勢を0.045秒先に進めて接地点を求める。
static func landing_feet(parts: Node2D, origins: Dictionary, position: Vector2, facing: float, scale: float) -> Array:
	var result := []
	for name: String in ["FrontLeftLeg","FrontRightLeg","RearLeftLeg","RearRightLeg"]:
		var rear := name.begins_with("Rear")
		var right := name.contains("Right")
		var time := 0.45+(0.045 if rear else 0.0)-(0.018 if right else 0.0)
		var side := 1.0 if right else -1.0
		var travel := curve(time,REAR_TRAVEL if rear else FRONT_TRAVEL)
		var angle := side*curve(time,REAR_ANGLE if rear else FRONT_ANGLE)
		var sprite := parts.get_node(name+"/Sprite") as Sprite2D
		var foot := Vector2((-1.0 if right else 1.0)*(2.871 if rear else 2.558),31.952 if rear else 28.45)
		var local: Vector2 = origins[name]+Vector2(0,travel)+(sprite.position+foot).rotated(angle)
		result.append(position+(local*scale).rotated(facing-PI/2.0))
	return result
