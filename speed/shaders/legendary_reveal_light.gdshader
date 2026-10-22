// 後光は放射方向を保ち、光条の濃淡だけを時間で展開する。本体・オーラとは別レイヤー。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 center = vec2(0.5, 0.47);
uniform vec4 light_color : source_color = vec4(1.0, 0.765, 0.16, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.8;
uniform float arrival = 1.0;
uniform float exposure = 0.0;
uniform float core_strength = 2.6;
uniform float core_radius = 0.14;
uniform float broad_ray_strength = 1.2;
uniform float fine_ray_strength = 0.9;
uniform float ray_reach = 1.0;
uniform float ray_width = 1.1;
uniform float broad_ray_count = 18.0;
uniform float fine_ray_count = 96.0;
uniform float ray_breath_strength = 0.85;
uniform float surge_strength = 0.12;
uniform float motion_time = 0.0;
uniform float core_distortion = 0.2;
uniform float ray_turbulence = 0.3;
uniform float ray_breakup = 0.25;
float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float noise(float p) {
 float c = floor(p);
 return mix(hash(c), hash(c + 1.0), smoothstep(0.0, 1.0, fract(p)));
}
vec3 evolution(float seed) {
 // 繰り返しの同位相呼吸ではなく、光条ごとに異なる連続ノイズを展開する。
 float t = motion_time * mix(0.42, 0.7, hash(seed + 47.0));
 return vec3(noise(seed * 31.0 + t), noise(seed * 57.0 + t * 0.73), noise(seed * 83.0 + t * 0.91));
}
float angle_distance(float a, float b) { return abs(mod(a - b + 3.14159265, 6.2831853) - 3.14159265); }
void fragment() {
 vec2 pixel = floor(UV * vec2(640.0, 360.0)) + 0.5;
 vec2 p = (pixel / vec2(640.0, 360.0) - center) * vec2(1.77778, 1.0);
 float radius = length(p);
 float angle = mod(atan(p.y, p.x) + 6.2831853, 6.2831853);
 float broad = 0.0;
 float fine = 0.0;
 float broad_count = max(4.0, broad_ray_count);
 float fine_count = max(8.0, fine_ray_count);
 float broad_sector = floor(angle * broad_count / 6.2831853);
 float fine_sector = floor(angle * fine_count / 6.2831853);
 for (int i = -1; i <= 1; i++) {
  float sector = mod(broad_sector + float(i) + broad_count, broad_count);
  float seed = sector + 1.0;
  vec3 wave = evolution(seed);
  float a = (sector + hash(seed) * 0.94) * 6.2831853 / broad_count;
  float reach = ray_reach * mix(0.32, 0.69, hash(seed + 89.0));
  reach *= mix(1.0, mix(0.7, 1.2, wave.x + (wave.y - 0.5) * ray_turbulence * 0.2), ray_breath_strength);
  float width = mix(0.045, 0.11, hash(seed + 20.0)) * ray_width;
  width *= mix(1.0, mix(0.65, 1.3, wave.y), ray_breath_strength);
  // 外側ほど幅と光量を落とし、鋭いくさびの先を柔らかく消す。
  width *= mix(1.0, 0.45, smoothstep(reach * 0.28, reach, radius));
  float d = angle_distance(angle, a);
  float beam = exp(-pow(d / width, 2.0));
  float bloom = exp(-pow(d / (width * 2.7), 2.0)) * 0.28;
  float end = 1.0 - smoothstep(reach * 0.45, reach, radius);
  float density = mix(1.0, mix(0.12, 1.55, wave.z), ray_breath_strength);
  float strand = noise(radius * 11.0 + seed * 19.0 - motion_time * 0.55);
  density *= mix(1.0, 0.6 + strand * 0.7, ray_breakup);
  broad += (beam + bloom) * end * density * exp(-radius * 2.0 / ray_reach);
  sector = mod(fine_sector + float(i) + fine_count, fine_count);
  seed = sector + 101.0;
  wave = evolution(seed);
  a = (sector + hash(seed) * 0.98) * 6.2831853 / fine_count;
  reach = ray_reach * mix(0.22, 0.67, hash(seed + 89.0));
  reach *= mix(1.0, mix(0.65, 1.25, wave.x), ray_breath_strength);
  width = mix(0.003, 0.016, hash(seed + 20.0)) * ray_width;
  width *= mix(0.8, 1.2, wave.y) * mix(1.0, 0.15, smoothstep(reach * 0.2, reach, radius));
  d = angle_distance(angle, a);
  float pixel_width = 1.0 / (360.0 * max(radius, 0.03));
  beam = exp(-pow(d / max(width, pixel_width * 0.7), 2.0));
  beam += exp(-pow(d / max(width * 3.0, pixel_width), 2.0)) * 0.15;
  end = 1.0 - smoothstep(reach * 0.35, reach, radius);
  density = mix(1.0, mix(0.15, 1.45, wave.z), ray_breath_strength);
  fine += beam * end * density * exp(-radius * 2.6 / ray_reach);
 }
 float core_noise = noise(angle * 2.0 + motion_time * 0.3);
 float core_edge = core_radius * mix(1.0, 0.86 + core_noise * 0.28, core_distortion);
 float core = exp(-pow(radius / core_edge, 2.0)) * core_strength;
 float rays = (broad * broad_ray_strength + fine * fine_ray_strength) * smoothstep(0.025, 0.08, radius);
 float halo = exp(-radius * radius * 11.0) * 0.32;
 float surge = 1.0 + sin(exposure * 3.14159265) * surge_strength;
 float energy = (rays + halo) * intensity * mix(0.25, 1.0, exposure) * surge;
 float level = 1.0 - exp(-energy * 1.8);
 vec3 amber = light_color.rgb * vec3(1.0, 0.75, 0.22);
 vec3 gold = mix(light_color.rgb, amber, smoothstep(0.12, 0.65, radius));
 vec3 emission = gold * level;
 // 白は光源の芯だけ。外側の金は輝度圧縮しても彩度を保つ。
 float core_level = 1.0 - exp(-core * intensity);
 float white_center = exp(-pow(radius / (core_edge * 0.62), 2.0));
 emission = mix(emission, mix(light_color.rgb, vec3(1.0, 0.97, 0.86), white_center), core_level);
 // 場所ごとに寿命をずらす十字光。消えている間に次の位置へ移る。
 vec2 cell = floor(pixel / vec2(70.0, 65.0));
 float id = cell.x + cell.y * 19.0;
 float life = motion_time / mix(3.1, 5.0, hash(id + 8.0)) + hash(id + 67.0);
 float cycle = floor(life);
 float fade = pow(sin(fract(life) * 3.14159265), 5.0);
 vec2 spot = (cell + vec2(0.18) + vec2(hash(id + cycle * 13.0), hash(id + cycle * 29.0 + 17.0)) * 0.64) * vec2(70.0, 65.0);
 vec2 q = abs(pixel - spot);
 float arm = mix(2.0, 5.5, hash(id + cycle * 7.0));
 float cross_light = exp(-q.x * 1.7 - q.y / arm) + exp(-q.y * 1.7 - q.x / arm);
 float spot_radius = length((spot / vec2(640.0, 360.0) - center) * vec2(1.77778, 1.0));
 float spark_mask = smoothstep(0.14, 0.22, spot_radius) * (1.0 - smoothstep(0.42, 0.58, spot_radius));
 emission += mix(light_color.rgb, vec3(1.0), 0.72) * cross_light * fade * spark_mask * intensity * 0.7;
 COLOR = vec4(emission, 1.0);
}
