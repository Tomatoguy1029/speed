## 図鑑・獲得演出・最終武器欄が共有する、専用素材までの仮の部品図。
extends RefCounted
static func draw(canvas: CanvasItem,id: String,color: Color) -> void:
	match id:
		"legendary_compass":
			for radius in [66,53]:canvas.draw_arc(Vector2.ZERO,radius,0,TAU,48,color,3.0,true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-48),Vector2(14,0),Vector2(0,48),Vector2(-14,0)]),color)
		"legendary_sail":
			canvas.draw_line(Vector2(-35,60),Vector2(-35,-65),color,5.0,true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-26,-62),Vector2(65,38),Vector2(-26,38)]),color)
		"legendary_keel":
			canvas.draw_polyline(PackedVector2Array([Vector2(-85,-28),Vector2(-60,25),Vector2(0,50),Vector2(60,25),Vector2(85,-28)]),color,8.0,true)
			canvas.draw_line(Vector2.ZERO,Vector2(0,50),color,6.0,true)
		"legendary_stern":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-50,-50),Vector2(50,-50),Vector2(68,45),Vector2(-68,45)]),color)
			canvas.draw_line(Vector2(-35,65),Vector2(35,65),color,8.0,true)
