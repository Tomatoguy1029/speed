## 素材アトラスの16セルを切り出し、ゲーム用の小さな透過PNGへ整える。
## godot --headless --path speed --script res://tools/prepare_pixel_assets.gd
extends SceneTree

const NAMES := ["drifter", "swarm", "darter", "armored", "splitter", "splitling",
	"leech", "gunner", "missile", "battleship", "titan", "meteor_0",
	"meteor_1", "moon", "planet", "airship"]
const SIZES := [32, 24, 32, 48, 40, 20, 40, 32, 40, 96, 80, 48, 48, 96, 128, 40]
## 生成アトラスは3段目の大型2体がセル境界を越えるため、実際の余白で区切る。
const ROWS := [0, 314, 600, 958, 1254]

func _initialize() -> void:
	var source := Image.load_from_file("res://assets/pixel/source-atlas.png")
	assert(source != null and not source.is_empty(), "素材アトラスを読めません")
	print("Atlas: ", source.get_size(), " alpha=", source.detect_alpha())
	for i in NAMES.size():
		var x := i % 4
		var y := i / 4
		var start := Vector2i(x * source.get_width() / 4, ROWS[y])
		var end := Vector2i((x + 1) * source.get_width() / 4, ROWS[y + 1])
		if i == 11:
			end.y = 925 # 次段の飛行船の先端を混ぜない。
		if i == 15:
			start.y = 940
		var sprite := source.get_region(Rect2i(start, end - start))
		# 半透明の縁をドットの境界にする。背景除去は生成素材のalphaを使用する。
		for py in sprite.get_height():
			for px in sprite.get_width():
				var color := sprite.get_pixel(px, py)
				color.a = 1.0 if color.a >= 0.5 else 0.0
				sprite.set_pixel(px, py, color)
		var bounds := sprite.get_used_rect()
		assert(bounds.has_area(), "空のセル: " + NAMES[i])
		sprite = sprite.get_region(bounds)
		var scale := float(SIZES[i]) / maxf(sprite.get_width(), sprite.get_height())
		sprite.resize(maxi(1, roundi(sprite.get_width() * scale)), maxi(1, roundi(sprite.get_height() * scale)), Image.INTERPOLATE_NEAREST)
		var error := sprite.save_png("res://assets/pixel/" + NAMES[i] + ".png")
		assert(error == OK, "PNGを書けません: " + NAMES[i])
		print(NAMES[i], ": ", bounds, " -> ", sprite.get_size())
	quit()
