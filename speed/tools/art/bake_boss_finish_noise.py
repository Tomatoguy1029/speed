#!/usr/bin/env python3
"""ボス撃破演出のひび・崩れ方に使う、繰り返し並べられるノイズを1枚に焼く。

制作時に1回だけ実行する（Godot不要）。シェーダーは毎フレーム計算せず、この画像を読む。
1画素はボスの絵の1ドット。252ドットで端がつながる。
  R: ひびの太さに使う、ボロノイの境界までの距離（ドット）÷16
  G: ボロノイの区画ごとの乱数
  B: 9ドット間隔のなめらかなノイズ（崩れる順番のばらつき）
  A: 画素ごとの乱数（光の粒の個性）
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/effects/build/boss_finish_noise.png"
SIZE = 252
CELL = 21


def hash1(n):
    s = math.sin(n * 127.1 + 311.7) * 43758.5453
    return s - math.floor(s)


def lattice(x, y, period):
    x %= period
    y %= period
    return hash1(x * 12.9898 + y * 78.233 + x * y * 0.0137)


def smooth(t):
    return t * t * (3 - 2 * t)


def value_noise(x, y, period):
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = smooth(x - xi), smooth(y - yi)
    a = lattice(xi, yi, period) + (lattice(xi + 1, yi, period) - lattice(xi, yi, period)) * fx
    b = lattice(xi, yi + 1, period) + (lattice(xi + 1, yi + 1, period) - lattice(xi, yi + 1, period)) * fx
    return a + (b - a) * fy


def bake():
    cells = SIZE // CELL
    image = Image.new("RGBA", (SIZE, SIZE))
    pixels = image.load()
    for j in range(SIZE):
        for i in range(SIZE):
            px = i + (value_noise(i / 7, j / 7, SIZE // 7) - 0.5) * 9
            py = j + (value_noise(i / 7 + 40, j / 7 + 17, SIZE // 7) - 0.5) * 9
            cx, cy = math.floor(px / CELL), math.floor(py / CELL)
            d1 = d2 = 1e9
            owner = 0
            for b in (-1, 0, 1):
                for a in (-1, 0, 1):
                    gx, gy = (cx + a) % cells, (cy + b) % cells
                    fx = (cx + a + lattice(gx, gy, cells)) * CELL
                    fy = (cy + b + lattice(gy + 31, gx, cells + 31)) * CELL
                    q = math.hypot(px - fx, py - fy)
                    if q < d1:
                        d2, d1, owner = d1, q, gx * 131 + gy
                    elif q < d2:
                        d2 = q
            edge = min(15.99, d2 - d1) / 16
            pixels[i, j] = (round(edge * 255), round(hash1(owner) * 255),
                            round(value_noise(i / 9, j / 9, SIZE // 9) * 255), round(hash1((j * SIZE + i) * 0.731) * 255))
    image.save(OUTPUT, compress_level=9)


if __name__ == "__main__":
    bake()
