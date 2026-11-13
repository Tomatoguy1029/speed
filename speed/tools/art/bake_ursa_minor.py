#!/usr/bin/env python3
"""りゅう座の決着で吠えるこぐま座の絵から、塗り分けに使う情報を1枚に焼く。

制作時に絵を差し替えたら1回実行する（Godot・Aseprite不要）。元は ursa_minor.aseprite の4コマで、
部位のレイヤーを後ろ脚・胴・脚・頭・尾の順に奥から重ね、200×160のコマを横に並べる。
  R: 見えている後ろ脚（255）。奥の脚として暗くする
  G: 外側のふちまでの距離（ドット、8で頭打ち）÷8。ふちの光に使う
  B: コマの中で形の上端を1、下端を0とする高さ。上ほど明るくする
  A: 形の中（255）
"""
import struct
import zlib
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/pixel/ursa_minor/ursa_minor.aseprite"
OUTPUT = ROOT / "assets/pixel/ursa_minor/ursa_minor_parts.png"
# 奥から順に重ねるレイヤー名
ORDER = ["back_leg", "body", "legs", "head", "tail"]
BACK_LEG = "back_leg"
EDGE_MAX = 8


def read_frames(path: Path) -> tuple[int, int, list[dict[str, np.ndarray]]]:
	"""32ビット色の .aseprite から、コマごとにレイヤー名→コマ全体の大きさのRGBA配列を返す。"""
	data = path.read_bytes()
	_, magic, count, width, height, depth = struct.unpack_from("<IHHHHH", data, 0)
	if magic != 0xA5E0 or depth != 32:
		raise SystemExit("32ビット色の .aseprite だけを読めます")
	names: list[str] = []
	frames = []
	offset = 128
	for _ in range(count):
		size, _, old_chunks, _ = struct.unpack_from("<IHHH", data, offset)
		chunks = struct.unpack_from("<I", data, offset + 12)[0] or old_chunks
		at = offset + 16
		layers: dict[str, np.ndarray] = {}
		for _ in range(chunks):
			chunk_size, kind = struct.unpack_from("<IH", data, at)
			body = data[at + 6:at + chunk_size]
			if kind == 0x2004:
				length = struct.unpack_from("<H", body, 16)[0]
				names.append(body[18:18 + length].decode())
			elif kind == 0x2005:
				layer, x, y, _, cel_type = struct.unpack_from("<HhhBH", body, 0)
				if cel_type != 2:
					raise SystemExit("圧縮したセルだけを読めます")
				w, h = struct.unpack_from("<HH", body, 16)
				pixels = np.frombuffer(zlib.decompress(body[20:]), np.uint8).reshape(h, w, 4)
				canvas = np.zeros((height, width, 4), np.uint8)
				canvas[y:y + h, x:x + w] = pixels
				layers[names[layer]] = canvas
			at += chunk_size
		frames.append(layers)
		offset += size
	return width, height, frames


def edge_distance(inside: np.ndarray) -> np.ndarray:
	distance = np.where(inside, float(EDGE_MAX), 0.0)
	for _ in range(EDGE_MAX):
		near = np.minimum.reduce([np.roll(distance, 1, 0), np.roll(distance, -1, 0), np.roll(distance, 1, 1), np.roll(distance, -1, 1)]) + 1.0
		distance = np.where(inside, np.minimum(distance, near), 0.0)
	return distance


def main() -> None:
	width, height, frames = read_frames(SOURCE)
	sheet = np.zeros((height, width * len(frames), 4), np.uint8)
	for index, layers in enumerate(frames):
		top = np.full((height, width), "", object)
		for name in ORDER:
			top[layers[name][..., 3] > 0] = name
		inside = top != ""
		rows = np.where(inside.any(axis=1))[0]
		up = 1.0 - np.clip((np.arange(height) - rows.min()) / max(1, rows.max() - rows.min()), 0.0, 1.0)
		cell = sheet[:, index * width:(index + 1) * width]
		cell[..., 0] = np.where(top == BACK_LEG, 255, 0)
		cell[..., 1] = np.rint(edge_distance(inside) / EDGE_MAX * 255.0)
		cell[..., 2] = np.rint(np.broadcast_to(up[:, None], (height, width)) * 255.0)
		cell[..., 3] = np.where(inside, 255, 0)
	Image.fromarray(sheet).save(OUTPUT)
	print(OUTPUT)


if __name__ == "__main__":
	main()
