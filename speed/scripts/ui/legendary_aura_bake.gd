## 制作画面から明示的に呼ぶオーラのベイク。ゲーム中はfingerprint/validによる確認だけを使う。
extends RefCounted

const FRAMES := 32
const COLUMNS := 8
const FPS := 8.0
const FRAME_SIZE := Vector2i(256, 186)
const VERSION := 1
## 出力の鮮度確認と制作時の生成用。ゲーム側ではこれらのMaterialを作成・描画しない。
const GENERATOR_SHADERS := [
	preload("res://shaders/legendary_radiance.gdshader"),
	preload("res://shaders/legendary_mantle.gdshader"),
	preload("res://shaders/legendary_radiance_luminance.gdshader"),
	preload("res://shaders/legendary_mantle_luminance.gdshader"),
]

static func fingerprint(definition: LegendaryModuleDef, recipe: Dictionary) -> String:
	if definition.reveal_aura_mask == null:
		return ""
	var image := definition.reveal_aura_mask.get_image()
	if image == null or image.is_empty():
		return ""
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	hash.update(var_to_bytes([image.get_size(), definition.reveal_aura_mask_channel, recipe, VERSION, FRAME_SIZE, FRAMES, FPS]))
	for shader in GENERATOR_SHADERS:
		hash.update(shader.code.to_utf8_buffer())
	return hash.finish().hex_encode()

static func valid(definition: LegendaryModuleDef, recipe: Dictionary) -> bool:
	return definition.reveal_aura_baked_back != null and definition.reveal_aura_baked_front != null \
		and definition.reveal_aura_bake_frames == FRAMES and definition.reveal_aura_bake_columns == COLUMNS \
		and definition.reveal_aura_bake_fps == FPS \
		and definition.reveal_aura_baked_back.get_size() == Vector2(FRAME_SIZE * Vector2i(COLUMNS, ceili(float(FRAMES) / COLUMNS))) \
		and definition.reveal_aura_baked_front.get_size() == definition.reveal_aura_baked_back.get_size() \
		and not definition.reveal_aura_bake_signature.is_empty() \
		and definition.reveal_aura_bake_signature == fingerprint(definition, recipe)

static func bake(owner: Node, source: Control, progress: Callable) -> Dictionary:
	# sourceは制作画面がsetup(definition, true)した生成プレビュー。画像アートは写さない。
	if source._definition.reveal_aura_mask == null:
		return {"error": "先に、絵とは別の輪郭マスクを選んでください。"}
	var viewport := SubViewport.new()
	viewport.size = FRAME_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	owner.add_child(viewport)
	source.reparent(viewport)
	source.set_anchors_preset(Control.PRESET_TOP_LEFT)
	source.size = Vector2(640, 360)
	source.set_timing(1.0, 20.0, 1.0)
	source.set_endpoints(source.size / 2.0, source.size / 2.0)
	source.background_dim = 0.0
	source.set_progress(2.4 / 22.0)
	source.scale = Vector2(FRAME_SIZE) / source._image.size
	source.position = -source._image.position * source.scale
	for node in [source._image, source._occlusion, source._light, source._name]:
		node.hide()
	var rect := TextureRect.new()
	rect.size = Vector2(FRAME_SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewport.add_child(rect)
	var mix_shader := Shader.new()
	mix_shader.code = "shader_type canvas_item; render_mode unshaded, blend_disabled; uniform sampler2D first; uniform sampler2D second; uniform float weight; void fragment(){ COLOR=mix(texture(first,UV),texture(second,UV),weight); }"
	var mix_material := ShaderMaterial.new()
	mix_material.shader = mix_shader
	var images: Array[Image] = []
	var duration := FRAMES / FPS
	for pass_index in 2:
		var atlas := Image.create(FRAME_SIZE.x * COLUMNS, FRAME_SIZE.y * ceili(float(FRAMES) / COLUMNS), false, Image.FORMAT_RGBA8)
		for frame in FRAMES:
			var phase := float(frame) / FRAMES
			var samples: Array[Image] = []
			for time in [phase * duration, (phase - 1.0) * duration]:
				rect.hide()
				source.show()
				source._aura.visible = pass_index == 0
				source._mantle.visible = pass_index == 1
				# 微粒子は元と同じく本体の後ろに含める。
				source.set_meta("bake_hide_dust", pass_index == 1)
				source.queue_redraw()
				for layer in [source._aura, source._mantle]:
					(layer.material as ShaderMaterial).set_shader_parameter("motion_time", time)
				await owner.get_tree().process_frame
				await RenderingServer.frame_post_draw
				samples.append(viewport.get_texture().get_image())
			# 時間の前後を滑らかに混ぜ、終端から始端まで連続するループにする。
			source.hide()
			rect.show()
			rect.texture = ImageTexture.create_from_image(samples[0])
			rect.material = mix_material
			mix_material.set_shader_parameter("first", rect.texture)
			mix_material.set_shader_parameter("second", ImageTexture.create_from_image(samples[1]))
			mix_material.set_shader_parameter("weight", smoothstep(0.0, 1.0, phase))
			await owner.get_tree().process_frame
			await RenderingServer.frame_post_draw
			var mixed := viewport.get_texture().get_image()
			mixed.convert(Image.FORMAT_RGBA8)
			atlas.blit_rect(mixed, Rect2i(Vector2i.ZERO, FRAME_SIZE), Vector2i(frame % COLUMNS, frame / COLUMNS) * FRAME_SIZE)
			progress.call((images.size() * FRAMES + frame + 1.0) / (FRAMES * 2.0))
		images.append(atlas)
	viewport.queue_free()
	return {"back": images[0], "front": images[1], "frames": FRAMES, "columns": COLUMNS, "fps": FPS,
		"signature": fingerprint(source._definition, source.aura_recipe())}
