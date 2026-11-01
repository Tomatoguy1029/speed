#!/usr/bin/env node
// Offline authoring export only. Node 18+, no npm install or Godot required.
// node speed/tools/art/bake_critical_hit.mjs --pixelfx /path/to/pixelfx --output /tmp/critical-hit
// Copy the resulting dedicated art assets into assets/effects/critical_hit after authoring.
// Upstream: patch-gg/pixelfx a84159688af3ca37a4be05a0d422b94451b2e24e (MIT).
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve, join, dirname } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { criticalHit } from "./critical_hit_source.mjs";

const expected = {
  "src/core/act.js": "b4fdeaf8af30c709748bb221c3b3854cc0438f2ce6c6d99f0324e3b3701b9f71",
  "src/core/actor.js": "5c867a24a88e93520d020b77190f12db265eb8fc357136ce3d92de05e19e63c2",
  "src/core/chain.js": "5014a0eae326f1855f5e320308ad370dbc342d2f1051df3665866401956bfef9",
  "src/core/color.js": "4e63f3074df7c1e138f721959858d12e4f6ccc2bf4f8e98c576efbae51241e54",
  "src/core/font.js": "c094f1d3a9f94478a255f1cc81aa7ccd2c2ba7a97fc1227a29d268acc1f2ec7c",
  "src/core/fx.js": "a959c5f7b1c15ba8e07cb26e5b1ccc0bce0aef54ca14cf01f9d6e794cf4e5a0b",
  "src/core/index.js": "ef5966a6365dbbe8a990867b6c7f3fc61922428e5f2e61262a3a430c119bf02d",
  "src/core/math.js": "da45e1ed43f7d119dd80fbe97c7de2b35b4ea95dea8781671c296ee5942ac0bc",
  "src/core/painter.js": "5b8ada6a25cdf1e63ae3684cc56276c61306558dc0a3a827a6a39ab038f74681",
  "src/core/particles.js": "867e58baf522278b4aad383c7224c599cff9ba93268b5eac9485a39a3809477b",
  "src/core/poses.js": "829f9b59ac883061afb9e952d6b608363ec7678bd00b026c538046685af88139",
  "src/core/rig.js": "5af3f455b18f9feb9f060732fb457529c6c76975a309c72171aa4e88b31aa70c",
  "src/core/scene.js": "520a465f771829162dde114880224eb30efbab3cff859cb8a24a28e49d8e198c",
  "src/core/shapes.js": "3e28f77e25b3083949f083c74304ead6826b7b1da20a658ccb114ab531fc8898",
  "src/core/sim.js": "517febe05b72de9d07e3596c019b9bb01e1f97a74089a30fa80e9e98849ba4b0",
  "src/fx/impacts/_lib.js": "0f47f85f805295eac267f159e27ce88a8766bbcd4e3b31c75359c97471861d9f",
  "tools/lib/png.mjs": "19da8ce363e7a4722fa49f06dd9066e07e83262c24da14a496b39a793111ed7c"
};
const args = process.argv.slice(2);
const option = (key) => { const i = args.indexOf(key); return i < 0 ? null : args[i + 1]; };
const upstream = option("--pixelfx"), destination = option("--output");
if (!upstream || !destination) throw new Error("Supply --pixelfx (the pinned library) and --output (a dedicated art directory)");
const root = resolve(upstream), out = resolve(destination);
const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");
for (const [path, wanted] of Object.entries(expected)) {
  if (digest(readFileSync(join(root, path))) !== wanted) throw new Error("Pinned pixelfx source differs: " + path);
}
const load = (path) => import(pathToFileURL(join(root, path)).href);
const core = await load("src/core/index.js");
const impacts = await load("src/fx/impacts/_lib.js");
const { encodePNG } = await load("tools/lib/png.mjs");
const { rasterText, textWidth } = await load("src/core/font.js");
const width = 768, height = 328, bytes = new Uint8ClampedArray(width * height * 4);
function pixel(x, y, r, g, b, a) {
  if (x < 0 || y < 0 || x >= width || y >= height) return;
  const i = (y * width + x) * 4;
  bytes.set([r, g, b, a], i);
}
function stamp(rgba, sw, sx, sy, w, h, dx, dy, alpha = 1) {
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = ((sy + y) * sw + sx + x) * 4;
    pixel(dx + x, dy + y, rgba[i], rgba[i + 1], rgba[i + 2], Math.round(rgba[i + 3] * alpha));
  }
}
// Match the adopted local preview's rounded 60 Hz sampling at 1.25x source time.
const fx = core.createFx(criticalHit(core, impacts), {
  x: 160, y: 150, height: 0, aim: -0.07, seed: 3, light: 0.25,
  palette: ["#2d1010", "#70331a", "#b86424", "#e8992e", "#ffc33e", "#ffe46b", "#fff5c4", "#ffffff"],
});
let sourceFrame = 0;
for (let i = 0; i < 26; i++) {
  const age = i / 60, sample = age * 1.25 * 60, lower = Math.floor(sample);
  const target = sample - lower === 0.5 ? lower + (lower % 2) : Math.round(sample);
  while (sourceFrame < target) { fx.update(1 / 60); sourceFrame++; }
  const frame = core.createFrame(400, 300);
  fx.draw(frame);
  const rgba = core.composite(frame, new Uint8ClampedArray(400 * 300 * 4));
  stamp(rgba, 400, 120, 114, 96, 64, (i % 8) * 96, Math.floor(i / 8) * 64,
    Math.min(1, Math.max(0, (0.42 - age) / 0.1)));
}
// The same pixelfx core/font.js CRIT glyphs, rather than a runtime font substitution.
const gw = textWidth("CRIT", "big"), glyph = new Uint8Array(gw * 7);
rasterText("CRIT", "big", (x, y) => { glyph[y * gw + x] = 1; });
for (let i = 0; i < 21; i++) {
  const age = i / 60, scale = 2.2 + 0.22 * Math.exp(-age * 35);
  const w = Math.round(gw * scale), h = Math.round(7 * scale);
  const mask = new Uint8Array((w + 4) * (h + 4)), mw = w + 4;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++)
    mask[(y + 2) * mw + x + 2] = glyph[Math.min(6, Math.floor((y + 0.5) * 7 / h)) * gw + Math.min(gw - 1, Math.floor((x + 0.5) * gw / w))];
  const x0 = (i % 8) * 64 + Math.round((64 - mw) / 2), y0 = 256 + Math.floor(i / 8) * 24 + 24 - (h + 4);
  const alpha = Math.round(255 * Math.min(1, Math.max(0, (0.34 - age) / 0.12)));
  for (let y = 0; y < h + 4; y++) for (let x = 0; x < mw; x++) {
    let border = false;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++)
      if (x + dx >= 0 && x + dx < mw && y + dy >= 0 && y + dy < h + 4 && mask[(y + dy) * mw + x + dx]) border = true;
    if (mask[y * mw + x]) pixel(x0 + x, y0 + y, 255, age < 0.025 ? 250 : 228, age < 0.025 ? 222 : 107, alpha);
    else if (border) pixel(x0 + x, y0 + y, 10, 10, 17, alpha);
  }
}
mkdirSync(out, { recursive: true });
writeFileSync(join(out, "critical_hit.png"), encodePNG(width, height, bytes));
const legalFile = (name) => join(existsSync(join(root, name)) ? root : dirname(root), name);
const license = readFileSync(legalFile("LICENSE"), "utf8");
const notice = readFileSync(legalFile("NOTICE.md"), "utf8");
writeFileSync(join(out, "LICENSE.txt"), license);
writeFileSync(join(out, "NOTICE.txt"), notice);
const resource = `[gd_resource type="Resource" script_class="CriticalHitAssets" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data_types/critical_hit_assets.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/effects/critical_hit/critical_hit.png" id="2"]

[resource]
script = ExtResource("1")
texture = ExtResource("2")
effect_frame_size = Vector2i(96, 64)
effect_origin = Vector2(40, 36)
effect_scale = 1.35
effect_frames = 26
label_frame_size = Vector2i(64, 24)
label_atlas_origin = Vector2i(0, 256)
label_frames = 21
columns = 8
fps = 60.0
effect_life = 0.42
label_life = 0.34
label_rise = 12.0
metadata/upstream_commit = "a84159688af3ca37a4be05a0d422b94451b2e24e"
metadata/source_sha256 = "${digest(readFileSync(fileURLToPath(new URL("./critical_hit_source.mjs", import.meta.url))))}"
metadata/baker_sha256 = "${digest(readFileSync(fileURLToPath(import.meta.url)))}"
metadata/texture_sha256 = "${digest(readFileSync(join(out, "critical_hit.png")))}"
metadata/pixelfx_license = ${JSON.stringify(license)}
metadata/pixelfx_notice = ${JSON.stringify(notice)}
`;
writeFileSync(join(out, "critical_hit.tres"), resource);
console.log("Exported critical_hit.png (768x328 RGBA), dedicated Resource and MIT notices to " + out);

