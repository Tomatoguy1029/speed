## 猟犬の胴体を選択色で塗り、発光部・既存塗装・再塗装を独立に保つ。
extends SceneTree
const PAINT := preload("res://tools/content/visual_transforms.gd")
const BODY := Vector2i(10, 15)
const CORE := Vector2i(9, 25)
var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _initialize() -> void:
	var source := load("res://assets/pixel/hound/armor.png") as Texture2D
	var data := PAINT.layout(source)
	var body := str(data.labels[BODY.y * int(data.width) + BODY.x])
	var core := str(data.labels[CORE.y * int(data.width) + CORE.x])
	check(body != core, "猟犬の胴体と発光部を別々に選択できる")
	var palette := {data.key: {}}
	for color in ["3c7293", "d99c48", "71c999"]:
		palette[data.key][body] = color
		var image := PAINT.painted_image(source, palette)
		check(image.get_pixelv(BODY).to_html(false) == color, "胴体を選択色で上書きする: " + color)
		check(image.get_pixelv(CORE) == data.image.get_pixelv(CORE), "胴体の塗装は発光部を保つ")
	palette[data.key][core] = "8040c0"
	var painted := PAINT.painted_image(source, palette)
	check(painted.get_pixelv(BODY).to_html(false) == "71c999", "発光部の塗装は胴体を保つ")
	palette[data.key].erase(body)
	var restored := PAINT.painted_image(source, palette)
	check(restored.get_pixelv(BODY) == data.image.get_pixelv(BODY), "胴体の指定解除で元画像へ戻す")
	check(restored.get_pixelv(CORE) == painted.get_pixelv(CORE), "胴体の指定解除は発光部の塗装を保つ")
	var legacy := {data.key: {"68": "3c7293"}}
	var colors := PAINT.region_colors(data, legacy)
	check(colors.get(body) == "3c7293" and colors.get(core) == "3c7293", "保存済みの中央領域の塗装を引き継ぐ")
	colors[body] = "d99c48"
	legacy[data.key] = colors
	check(PAINT.painted_image(source, legacy).get_pixelv(BODY).to_html(false) == "d99c48", "保存済み塗装を引き継いだ後も上書きできる")
	for y in data.height:
		for x in data.width:
			check(painted.get_pixel(x, y).a == data.image.get_pixel(x, y).a, "塗装で透過マスクを保つ")
	var view = load("res://gyms/enemy_lab/lab_armor_paint.gd").new()
	view.show_armor(source, {data.key: {body: "3c7293"}})
	view.show_armor(source, {data.key: {body: "d99c48"}})
	check(view._texture.get_image().get_pixelv(BODY).to_html(false) == "d99c48", "実験場の塗装表示も連続した変更へ追従する")
	view.free()
	print("[hound_armor_paint] failed=%d" % failed)
	quit(1 if failed else 0)
