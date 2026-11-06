#!/usr/bin/env python3
"""りゅう座の決着の固定経路と星雲の素材を生成する（Python標準ライブラリのみ）。

本人が承認した試作と同じ乱数・同じ式で作る。値を変えるときはこのファイルを編集して実行し、
生成物と一緒に確定する。
"""
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RUSH_PATH = ROOT / 'speed/data/bosses/draco_finale_rush.tres'
PUFF_PATH = ROOT / 'speed/assets/effects/build/draco_finale_puff.png'
TAU = math.pi * 2
BODY_LENGTH = 1500.0
BODY_WIDTH = 154.0
SEGMENTS = 80
RUSH = {'first': 0.30, 'ratio': 0.938, 'flurry': 0.022, 'total': 5.0, 'start': 0.3, 'enter': 0.08}
SHIP_START = (0.0, 396.0)
WAYPOINTS = [(-226, -205), (-140, -182), (40, -176), (170, -140), (214, -70), (150, -12), (-60, 0), (-205, 30), (-235, 92), (-170, 144), (10, 158), (130, 146), (190, 108)]


def rng(seed):
    state = [seed & 0xffffffff]

    def imul(a, b):
        return (a * b) & 0xffffffff

    def next_value():
        state[0] = (state[0] + 0x6D2B79F5) & 0xffffffff
        s = state[0]
        t = imul(s ^ (s >> 15), 1 | s)
        t = ((t + imul(t ^ (t >> 7), 61 | t)) & 0xffffffff) ^ t
        return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296
    return next_value


def lerp(a, b, k):
    return a + (b - a) * k


def clamp(x, a=0.0, b=1.0):
    return min(b, max(a, x))


def final_pose():
    dense = []
    at = lambda i: WAYPOINTS[int(clamp(i, 0, len(WAYPOINTS) - 1))]
    for i in range(len(WAYPOINTS) - 1):
        for k in range(24):
            u = k / 24
            p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
            f = lambda d: 0.5 * (2 * p1[d] + (p2[d] - p0[d]) * u + (2 * p0[d] - 5 * p1[d] + 4 * p2[d] - p3[d]) * u * u + (3 * p1[d] - p0[d] - 3 * p2[d] + p3[d]) * u * u * u)
            dense.append((f(0), f(1)))
    dense.append(WAYPOINTS[-1])
    length = sum(math.dist(dense[i], dense[i - 1]) for i in range(1, len(dense)))
    scale = BODY_LENGTH / length
    dense = [(x * scale, y * scale) for x, y in dense]
    step = BODY_LENGTH / SEGMENTS
    points = [dense[0]]
    cursor, walked = 0, 0.0
    span = math.dist(dense[0], dense[1])
    for j in range(1, SEGMENTS + 1):
        target = step * j
        while cursor < len(dense) - 2 and target > walked + span:
            walked += span
            cursor += 1
            span = math.dist(dense[cursor], dense[cursor + 1])
        k = clamp((target - walked) / span)
        points.append((lerp(dense[cursor][0], dense[cursor + 1][0], k), lerp(dense[cursor][1], dense[cursor + 1][1], k)))
    return points


def bezier(a, b, c, e, u):
    m = 1 - u
    return tuple(m * m * m * a[d] + 3 * m * m * u * b[d] + 3 * m * u * u * c[d] + u * u * u * e[d] for d in (0, 1))


def bake_rush(points):
    q = rng(2718)
    times = []
    t, dt = RUSH['start'], RUSH['first']
    while dt > 0.03:
        times.append((t, dt))
        t += dt
        dt *= RUSH['ratio']
    while t < RUSH['total']:
        times.append((t, RUSH['flurry']))
        t += RUSH['flurry']
    hits = []
    direction, turn = -1.3, 1
    for i, (time, gap) in enumerate(times):
        j = 5 + int(q() * 64)
        if q() < 0.22:
            turn = -turn
        direction += turn * (math.pi - (0.42 + q() * 0.62))
        x = points[j][0] + (q() - 0.5) * 40
        y = points[j][1] + (q() - 0.5) * 40
        hits.append({'t': time, 'gap': gap, 'j': j, 'p': (x, y), 'd': (math.cos(direction), math.sin(direction)), 'sharp': gap > 0.05 or i % 6 == 0, 'big': gap > 0.05})
    path, ghosts = [], []

    def segment(a, b, c, e, ta, tb):
        for k in range(19):
            u = k / 18
            p = bezier(a, b, c, e, u)
            path.append((lerp(ta, tb, u), p[0], p[1]))
    first = hits[0]
    segment(SHIP_START, (SHIP_START[0] + 260, SHIP_START[1] - 60), (first['p'][0] - first['d'][0] * 420, first['p'][1] - first['d'][1] * 420), first['p'], RUSH['enter'], first['t'])
    for i, hit in enumerate(hits):
        hold = min(0.03, hit['gap'] * 0.22)
        p, d = hit['p'], hit['d']
        if i + 1 < len(hits):
            nxt = hits[i + 1]
            r = lerp(540, 360, i / len(hits)) * (0.8 + q() * 0.45)
            out = (p[0] + d[0] * r, p[1] + d[1] * r)
            back = (nxt['p'][0] - nxt['d'][0] * r, nxt['p'][1] - nxt['d'][1] * r)
            segment(p, out, back, nxt['p'], hit['t'] + hold, nxt['t'])
            if i % 3 == 1:
                mid = bezier(p, out, back, nxt['p'], 0.5)
                ghosts.append((lerp(hit['t'], nxt['t'], 0.5), mid[0], mid[1], math.atan2(d[1], d[0]) + 1.6))
        else:
            segment(p, (p[0] + d[0] * 600, p[1] + d[1] * 600), (0, 1200), (0, 1500), hit['t'] + 0.01, hit['t'] + 0.1)
        if hit['sharp']:
            ghosts.append((hit['t'] + 0.04, p[0], p[1], math.atan2(d[1], d[0])))
    return hits, path, ghosts


def taper(t):
    return lerp(1.0, 0.23, pow(clamp((t - 0.55) / 0.45), 1.35))


def bake_cuts(points):
    cuts = []
    for j in range(SEGMENTS):
        a, b = points[j], points[j + 1]
        if a[0] * b[0] <= 0:
            k = a[0] / (a[0] - b[0]) if a[0] != b[0] else 0
            cuts.append((lerp(a[1], b[1], k), BODY_WIDTH * taper(j / SEGMENTS) * 0.62))
    return cuts


def packed(values):
    return 'PackedFloat32Array(' + ', '.join(f'{v:.5g}' for v in values) + ')'


def write_rush():
    points = final_pose()
    hits, path, ghosts = bake_rush(points)
    flat_hits = []
    for h in hits:
        flat_hits += [h['t'], h['gap'], h['j'] / SEGMENTS, h['p'][0], h['p'][1], h['d'][0], h['d'][1], 1.0 if h['sharp'] else 0.0, 1.0 if h['big'] else 0.0]
    text = '[gd_resource type="Resource" script_class="DracoFinaleRush" load_steps=2 format=3]\n\n'
    text += '[ext_resource type="Script" path="res://scripts/data_types/draco_finale_rush.gd" id="1"]\n\n[resource]\n'
    text += 'script = ExtResource("1")\n'
    text += f'path = {packed([v for row in path for v in row])}\n'
    text += f'hits = {packed(flat_hits)}\n'
    text += f'ghosts = {packed([v for row in ghosts for v in row])}\n'
    text += f'cuts = {packed([v for row in bake_cuts(points) for v in row])}\n'
    RUSH_PATH.write_text(text, encoding='utf8')
    return len(hits), len(path)


def bake_puffs():
    size = 96
    random = rng(7)
    grids = [(8 << o, [random() for _ in range((8 << o) ** 2)]) for o in range(4)]

    def noise(u, w, seed):
        total, amp = 0.0, 0.5
        for n, grid in grids:
            x = (u + seed * 0.37) * n
            y = (w + seed * 0.61) * n
            xi, yi = math.floor(x), math.floor(y)
            f, h = x - xi, y - yi
            sx, sy = f * f * (3 - 2 * f), h * h * (3 - 2 * h)
            at = lambda a, b: grid[(a % n) + (b % n) * n]
            total += amp * lerp(lerp(at(xi, yi), at(xi + 1, yi), sx), lerp(at(xi, yi + 1), at(xi + 1, yi + 1), sx), sy)
            amp *= 0.5
        return total

    def smooth(a, b, x):
        f = clamp((x - a) / (b - a))
        return f * f * (3 - 2 * f)
    rows = []
    for j in range(size):
        row = bytearray([0])
        for k in range(4):
            for i in range(size):
                dx, dy = (i - 48) / 48, (j - 48) / 48
                edge = clamp(1 - math.hypot(dx, dy))
                alpha = smooth(0.34, 0.85, noise(i / size, j / size, k + 1)) * edge * edge
                row += bytes((255, 255, 255, int(255 * clamp(alpha * 1.5))))
        rows.append(bytes(row))

    def chunk(kind, data):
        body = kind + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size * 4, size, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b'')
    PUFF_PATH.write_bytes(png)


if __name__ == '__main__':
    count, samples = write_rush()
    bake_puffs()
    print(f'hits={count} path={samples}')
