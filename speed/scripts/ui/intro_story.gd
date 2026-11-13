## 制作時に書き出した絵と、シナリオの翻訳キーを再生順に保持する。
extends RefCounted

const IS_ENDING := false
const SCENES := [
	{"name": "Scene1", "layers": [preload("res://assets/ui/intro/scene1.png")], "text": ["intro.scene1.1", "intro.scene1.2", "intro.scene1.3"]},
	{"name": "Scene1-2", "overlay": true, "layers": [preload("res://assets/ui/intro/scene1.png"), preload("res://assets/ui/intro/scene1-2alt.png")], "text": ["intro.scene1-2.1", "intro.scene1-2.2", "intro.scene1-2.3"]},
	{"name": "Scene2", "layers": [preload("res://assets/ui/intro/scene2.png")], "text": ["intro.scene2.1", "intro.scene2.2"]},
	{"name": "Scene3", "layers": [preload("res://assets/ui/intro/scene3.png")], "text": ["intro.scene3.1"]},
	{"name": "Scene4", "layers": [preload("res://assets/ui/intro/scene4.png"), preload("res://assets/ui/intro/scene4_effects.png")], "text": ["intro.scene4.1", "intro.scene4.2"]},
	{"name": "Scene5", "layers": [preload("res://assets/ui/intro/scene5.png")], "text": ["intro.scene5.1", "intro.scene5.2"], "stars": [preload("res://assets/ui/intro/scene5_stars1.png"), preload("res://assets/ui/intro/scene5_stars2.png"), preload("res://assets/ui/intro/scene5_stars3.png")]},
	{"name": "Scene6", "layers": [preload("res://assets/ui/intro/scene6.png")], "text": ["intro.scene6.1", "intro.scene6.2"]},
	{"name": "Scene7", "layers": [preload("res://assets/ui/intro/scene7.png")], "text": ["intro.scene7.1", "intro.scene7.2"]},
]
