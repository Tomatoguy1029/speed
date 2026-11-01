// Electrified: baked jagged contact paths, rasterized on the original sprite pixel grid.
shader_type canvas_item;
render_mode unshaded;
uniform vec4 mark_color : source_color = vec4(0.7411765, 0.1098039, 0.1607843, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.2588235, 0.2901961, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.03137255, 0.01568628, 0.02745098, 1.0);
uniform float intensity = 1.0;
uniform bool shadow_pass = false;
varying vec4 source_line;
varying vec4 stroke_data;
void vertex() {
 // Geometry stays in custom data: instance color contains only normalized visual values.
 vec2 segment = INSTANCE_CUSTOM.zw;
 float len = max(length(segment), 0.05);
 source_line = vec4(INSTANCE_CUSTOM.xy, segment / len);
 stroke_data = vec4(len, COLOR.r, COLOR.g, COLOR.b); // length, opacity, power, spark
}
void fragment() {
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
  if (!spark && distance < 1.8) col = vec4(shadow_color.rgb, alpha);
  else if (distance < 3.0) col = vec4(mark_color.rgb, (1.0 - distance / 3.0) * 0.12 * alpha);
 } else {
  // Hard, one-pixel hot core with an offset red body, as in pixelfx crackle.
  float body = length(delta - vec2(1.0, 0.0) - dir * clamp(dot(delta - vec2(1.0, 0.0), dir), 0.0, len));
  if (distance < 0.62) col = vec4(mix(mark_color.rgb, highlight_color.rgb, stroke_data.z), alpha);
  else if (!spark && body < 0.62) col = vec4(mark_color.rgb, alpha);
 }
 COLOR = col;
}
