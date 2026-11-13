## 竜の決着演出後に再生する4場面。文章はゲーム内文言の正本から読む。
extends RefCounted
const IS_ENDING := true
const SCENES := [
	{"name":"Ending1", "layers":[preload("res://assets/ui/ending/ending_scene1.png")], "text":["ending.scene1.1", "ending.scene1.2"]},
	{"name":"Ending2", "layers":[preload("res://assets/ui/ending/ending_scene2.png")], "text":["ending.scene2.1", "ending.scene2.2"]},
	{"name":"Ending3", "layers":[preload("res://assets/ui/ending/ending_scene3.png")], "text":["ending.scene3.1", "ending.scene3.2"]},
	{"name":"Ending4", "layers":[preload("res://assets/ui/ending/ending_scene4.png")], "text":["ending.scene4.1", "ending.scene4.2"]},
]
