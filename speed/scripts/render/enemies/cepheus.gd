## ケフェウス座の見た目と、兵の召喚の予告。
extends EnemyVisual

var summon_marks: Array = []

static func draw_frame(c: CanvasItem, data: Dictionary, pixel: float) -> void:
	var values: PackedFloat64Array = data.values
	for i in range(0,values.size(),5):
		var p := Vector2(values[i],values[i+1])
		var r := values[i+2]
		var k := values[i+4]
		c.draw_arc(p,r*(1.15+0.3*k),0,TAU,40,Color(1.0,0.85,0.4,0.35+0.5*k),pixel*3.0)
		c.draw_circle(p-Vector2.from_angle(values[i+3])*r*0.55,r*(0.15+0.2*k),Color(1.0,0.92,0.6,0.5+0.4*k))
	var marks: PackedFloat64Array = data.marks
	for i in range(0,marks.size(),10):
		var at := Vector2(marks[i],marks[i+1])
		var king := Vector2(marks[i+2],marks[i+3])
		var col := Color(marks[i+4],marks[i+5],marks[i+6],marks[i+7]).lightened(0.35)
		var k := marks[i+8]
		c.draw_line(king,at,Color(1.0,0.85,0.45,0.25+0.35*k),pixel*2.0)
		c.draw_arc(at,30.0*(1.6-0.6*k),0,TAU,32,Color(col,0.4+0.5*k),pixel*2.5)
		for q in 5:
			var a := marks[i+9]*2.0+q*TAU/5.0
			c.draw_line(at+Vector2.from_angle(a)*18.0,at+Vector2.from_angle(a)*(26.0+10.0*(1.0-k)),Color(1.0,0.85,0.45,0.6*k),pixel*2.0)
		c.draw_circle(at,6.0+8.0*k,Color(1.0,0.95,0.75,0.3+0.5*k))
