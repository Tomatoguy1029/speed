// Specialized by tools/art/bake_elite_crackle.py; edit elite_mark.tres, then rebake.
// Electrified: baked jagged contact paths, rasterized on the original sprite pixel grid.
shader_type canvas_item;
render_mode unshaded;
const vec4 mark_color = vec4(0.5088813304901123, 0.0116122392937541, 0.02217387966811657, 1.0);
const vec4 highlight_color = vec4(1.0, 0.05448026955127716, 0.06847816705703735, 1.0);
const vec4 shadow_color = vec4(0.002428215928375721, 0.001214108313433826, 0.002124688820913434, 1.0);
const float intensity = 1.0;
uniform bool shadow_pass = false;
varying vec4 source_line;
varying vec4 stroke_data;
uniform bool linear_colors = true;
const vec4 mark_color_srgb = vec4(0.7411764860153198, 0.10980390012264252, 0.1607843041419983, 1.0);
const vec4 highlight_color_srgb = vec4(1.0, 0.2588235139846802, 0.29019609093666077, 1.0);
const vec4 shadow_color_srgb = vec4(0.0313725508749485, 0.01568627916276455, 0.027450980618596077, 1.0);
void vertex() {
 // Geometry stays in custom data: instance color contains only normalized visual values.
 vec2 segment = INSTANCE_CUSTOM.zw;
 float len = max(length(segment), 0.05);
 source_line = vec4(INSTANCE_CUSTOM.xy, segment / len);
 stroke_data = vec4(len, COLOR.r, COLOR.g, COLOR.b); // length, opacity, power, spark
}
void fragment() {
 vec4 elite_mark_color = linear_colors ? mark_color : mark_color_srgb;
 vec4 elite_highlight_color = linear_colors ? highlight_color : highlight_color_srgb;
 vec4 elite_shadow_color = linear_colors ? shadow_color : shadow_color_srgb;
 float len = stroke_data.x;
 vec2 dir = source_line.zw;
 vec2 side = vec2(-dir.y, dir.x);
 vec2 at = source_line.xy + dir * (UV.x * (len + 6.0) - 3.0) + side * ((UV.y - 0.5) * 6.0);
 vec2 pixel = floor(at) + 0.5;
 vec2 delta = pixel - source_line.xy;
 float along = clamp(dot(delta, dir), 0.0, len);
 float distance = length(delta - dir * along);
 bool spark = stroke_data.w > 0.5;
 float alpha = stroke_data.y * intensity;
 vec4 col = vec4(0.0);
 if (shadow_pass) {
  if (!spark && distance < 1.8) col = vec4(elite_shadow_color.rgb, alpha);
  else if (distance < 3.0) col = vec4(elite_mark_color.rgb, (1.0 - distance / 3.0) * 0.12 * alpha);
 } else {
  // Hard, one-pixel hot core with an offset red body, as in pixelfx crackle.
  float body = length(delta - vec2(1.0, 0.0) - dir * clamp(dot(delta - vec2(1.0, 0.0), dir), 0.0, len));
  if (distance < 0.62) col = vec4(mix(elite_mark_color.rgb, elite_highlight_color.rgb, stroke_data.z), alpha);
  else if (!spark && body < 0.62) col = vec4(elite_mark_color.rgb, alpha);
 }
 COLOR = col;
}
