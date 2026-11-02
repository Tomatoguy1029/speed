## ビームの見た目。予告の間は砲口に光が集まり、照射の間は光の線を描く。広がるビーム（水流）は水流の見た目が描く。
extends AttackVisual

static func frame_group(circles: Array) -> DrawLayer:
	var node := DrawLayer.new()
	node.z_index = -1
	node.draw_fn = func(canvas: CanvasItem):
		for circle: Dictionary in circles: canvas.draw_circle(circle.position,circle.radius,circle.color)
	return node
