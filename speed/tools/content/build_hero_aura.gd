## 回転・倍率によらない光雲の関数を、小さな一次元表へ分けて保存する。
@tool
extends RefCounted
const SAMPLES := 4096
static func build(output: String) -> Error:
	var image := Image.create(SAMPLES,4,false,Image.FORMAT_RGBAF)
	for i in SAMPLES:
		var x := float(i)/(SAMPLES-1)*2.0-1.0
		var falloff := exp(-x*x*2.8)
		image.set_pixel(i,0,Color(falloff,sin(x*4.0),cos(x*4.0),cos(x)))
		image.set_pixel(i,1,Color(sin(x),0,0,0))
		image.set_pixel(i,2,Color(falloff,cos(x*2.0),sin(x*2.0),cos(x*5.0)))
		image.set_pixel(i,3,Color(sin(x*5.0),0,0,0))
	var result := HeroAuraAssets.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var corners := PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	arrays[Mesh.ARRAY_VERTEX] = corners
	arrays[Mesh.ARRAY_TEX_UV] = corners
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	var quad := ArrayMesh.new()
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.mesh = quad
	result.material = ShaderMaterial.new()
	result.material.shader = load("res://shaders/hero_aura.gdshader")
	result.material.set_shader_parameter("tint",Color("#ffe8a0"))
	result.material.set_shader_parameter("curves",ImageTexture.create_from_image(image))
	return ResourceSaver.save(result,output.path_join("hero_aura.res"))
