#!/usr/bin/env node
// Authoring only: node speed/tools/art/bake_armor_block.mjs --pixelfx /pinned/library --output /tmp/armor-block
// Match the adopted straight B GIF: 50 fps, 1.5x source time, seed 11, light 0.7.
// Runtime only reads the committed image. Do not invoke from a run or on a collision.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve, join, dirname } from "node:path";
import { pathToFileURL } from "node:url";
import { armorBlock } from "./armor_block_source.mjs";

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
  "tools/lib/png.mjs": "19da8ce363e7a4722fa49f06dd9066e07e83262c24da14a496b39a793111ed7c"
};
const args = process.argv.slice(2);
const option = key => { const i = args.indexOf(key); return i < 0 ? null : args[i + 1]; };
const upstream = option("--pixelfx"), destination = option("--output");
if (!upstream || !destination) throw new Error("Supply --pixelfx (the pinned library) and --output (a dedicated art directory)");
const root = resolve(upstream), out = resolve(destination);
const digest = bytes => createHash("sha256").update(bytes).digest("hex");
for (const [path, wanted] of Object.entries(expected)) {
  if (digest(readFileSync(join(root, path))) !== wanted) throw new Error("Pinned pixelfx source differs: " + path);
}
const core = await import(pathToFileURL(join(root, "src/core/index.js")).href);
const { encodePNG } = await import(pathToFileURL(join(root, "tools/lib/png.mjs")).href);
const fx = core.createFx(armorBlock(core), { x: 188.4, y: 90, angle: -Math.PI / 2, light: 0.7 });
const frame = core.createFrame(320, 180), rgba = new Uint8ClampedArray(320 * 180 * 4);
const width = 1120, height = 480, sheet = new Uint8ClampedArray(width * height * 4);
for (let i = 0; i < 21; i++) {
  core.clearFrame(frame);
  fx.draw(frame, "front");
  core.composite(frame, rgba);
  const dx = (i % 7) * 160, dy = Math.floor(i / 7) * 160;
  for (let y = 0; y < 160; y++) {
    const start = ((10 + y) * 320 + 108) * 4;
    sheet.set(rgba.subarray(start, start + 160 * 4), ((dy + y) * width + dx) * 4);
  }
  fx.update(1.5 / 50);
}
mkdirSync(out, { recursive: true });
writeFileSync(join(out, "armor_block.png"), encodePNG(width, height, sheet));
for (const [source, target] of [["LICENSE", "LICENSE.txt"], ["NOTICE.md", "NOTICE.txt"]]) {
  const legal = join(existsSync(join(root, source)) ? root : dirname(root), source);
  writeFileSync(join(out, target), readFileSync(legal));
}
console.log("Exported armor_block.png (1120x480 RGBA, 21 frames) and MIT notices to " + out);
