shader_type canvas_item;
render_mode unshaded;
uniform float elapsed = 0.0;
float box(vec2 uv, vec4 bounds) {
    return step(bounds.x, uv.x) * step(uv.x, bounds.z) * step(bounds.y, uv.y) * step(uv.y, bounds.w);
}
float text_mask(vec2 uv) {
    return max(box(uv, vec4(0.37, 0.315, 0.635, 0.415)), box(uv, vec4(0.205, 0.420, 0.793, 0.625)));
}
vec4 ink(sampler2D source, vec2 uv) {
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return vec4(0.0); }
    vec4 sample_color = texture(source, uv);
    float strength = max(sample_color.r, max(sample_color.g, sample_color.b));
    sample_color.a *= step(0.25, strength);
    return sample_color;
}
vec3 over(vec3 backdrop, vec4 art, float amount) {
    return mix(backdrop, art.rgb, art.a * amount);
}
void fragment() {
    float t = elapsed;
    vec2 uv = UV;
    vec2 dimensions = vec2(textureSize(TEXTURE, 0));
    vec3 color = vec3(0.012, 0.032, 0.052);
    float entry = 1.0 - pow(1.0 - clamp((t - 0.14) / 0.46, 0.0, 1.0), 4.0);
    float leave = 1.0 - smoothstep(2.65, 3.12, t);
    // Move the two halves by whole artwork pixels; contours never get resampled by scaling.
    float offset_x = floor((1.0 - entry) * 112.0 / 8.0) * 8.0 / dimensions.x;
    vec2 frame_uv = uv - vec2(sign(uv.x - 0.5) * offset_x, 0.0);
    vec4 frame = ink(TEXTURE, frame_uv);
    float opening = step(abs(uv.y - 0.5), entry * 0.47);
    float sparkle = 0.94 + 0.06 * sin(t * 4.0);
    color = over(color, frame, (1.0 - text_mask(frame_uv)) * opening * leave * sparkle);
    // STAGE drops into place, then the main word lands letter by letter.
    float stage_in = smoothstep(0.26, 0.50, t);
    vec2 stage_uv = uv + vec2(0.0, floor((1.0 - stage_in) * 24.0 / 4.0) * 4.0 / dimensions.y);
    color = over(color, ink(TEXTURE, stage_uv), box(stage_uv, vec4(0.37, 0.315, 0.635, 0.415)) * stage_in * leave);
    float letter = floor(clamp((uv.x - 0.205) / 0.588, 0.0, 0.999) * 8.0);
    float word_in = clamp((t - 0.35 - letter * 0.025) / 0.18, 0.0, 1.0);
    float rise = floor(pow(1.0 - word_in, 2.0) * 40.0 / 4.0) * 4.0;
    vec2 word_uv = uv - vec2(0.0, rise / dimensions.y);
    vec4 word = ink(TEXTURE, word_uv);
    float word_mask = box(word_uv, vec4(0.205, 0.420, 0.793, 0.625));
    float shine_pos = (t - 0.86) / 0.50;
    float shine = step(abs(uv.x - shine_pos), 0.020) * step(0.9, t) * step(t, 1.4);
    word.rgb = mix(word.rgb, vec3(0.92, 1.0, 1.0), shine * 0.65);
    color = over(color, word, word_mask * word_in * leave);
    // A short, square-cornered star marks the initial impact.
    vec2 p = abs(uv - vec2(0.5));
    float cross = max(step(p.x, 0.003) * step(p.y, 0.035), step(p.x, 0.02) * step(p.y, 0.005));
    color += vec3(0.7, 0.95, 1.0) * cross * (1.0 - smoothstep(0.16, 0.32, t)) * step(0.08, t);
    COLOR = vec4(color, 1.0);
}
