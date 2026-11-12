## 原画を保ち、フィールド用の中心・透明余白を制作時に確定する。
extends SceneTree
const SOURCE := "res://assets/pixel/background/"
const OUTPUT := SOURCE + "centered/"
const PLANETS := {
	"planet_c": Rect2i(61, 147, 583, 581),
	"planet_d": Rect2i(108, 134, 562, 558),
	"planet_e": Rect2i(116, 92, 572, 564),
	"planet_f": Rect2i(68, 90, 630, 634),
	"moon": Rect2i(3, 1, 94, 94),
}
func _initialize() -> void:
	var error := DirAccess.make_dir_recursive_absolute(OUTPUT)
	if error != OK:
		push_error("Cannot create planet output: " + error_string(error))
		quit(error)
		return
	for name: String in PLANETS:
		var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE + name + ".png"))
		if source == null:
			quit(ERR_FILE_NOT_FOUND)
			return
		var region: Rect2i = PLANETS[name]
		var image := source.get_region(region)
		image.convert(Image.FORMAT_RGBA8)
		if name == "planet_f":
			# 惑星外の下地・描き残しだけを落とし、元の球面内の画素は保つ。
			var center := Vector2(image.get_size()) * 0.5
			for y in image.get_height():
				for x in image.get_width():
					if ((Vector2(x, y) + Vector2(0.5, 0.5) - center) / center).length_squared() > 1.0:
						image.set_pixel(x, y, Color.TRANSPARENT)
		var side := maxi(region.size.x, region.size.y)
		var centered := Image.create(side, side, false, Image.FORMAT_RGBA8)
		centered.fill(Color.TRANSPARENT)
		centered.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), (Vector2i(side, side) - image.get_size()) / 2)
		var path := "res://assets/pixel/moon.png" if name == "moon" else OUTPUT + name + ".png"
		error = centered.save_png(path)
		if error != OK:
			push_error(path + ": " + error_string(error))
			quit(error)
			return
		print(name, " centered: ", side, "x", side)
	quit()
