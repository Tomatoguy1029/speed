// pixelfx の効果を暗い背景で描き、2倍のドットで生の RGB 連番を書き出す（GIF化の入力）。
import { mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
const [checkout, out, fps, ...ids] = process.argv.slice(2);
const { loadEffect, renderFrames } = await import(pathToFileURL(join(resolve(checkout), "tools/lib/fxlib.mjs")).href);
const S = 2;
for (const id of ids) {
  const fx = await loadEffect(id);
  const r = renderFrames(fx, { fps: Number(fps), bg: "dark" });
  const dir = join(out, id.replace("/", "__"));
  mkdirSync(dir, { recursive: true });
  r.frames.forEach((f, n) => {
    const buf = Buffer.alloc(r.w * S * r.h * S * 3);
    for (let y = 0; y < r.h * S; y++) for (let x = 0; x < r.w * S; x++) {
      const i = ((y / S | 0) * r.w + (x / S | 0)) * 4, o = (y * r.w * S + x) * 3;
      buf[o] = f.color[i]; buf[o + 1] = f.color[i + 1]; buf[o + 2] = f.color[i + 2];
    }
    writeFileSync(join(dir, String(n).padStart(4, "0") + ".raw"), buf);
  });
  writeFileSync(join(dir, "size.txt"), `${r.w * S} ${r.h * S}`);
  console.log(id, r.w * S, r.h * S, r.frames.length);
}
