"""Compile local Electrified paths beside the shared enemy distance masks.

Midpoint displacement and branching follow pixelfx / Sprite Fusion lightning.
See assets/effects/elite/LICENSE.txt. All image analysis belongs to this step.
"""
import hashlib
import math
import random

import numpy as np


class PackedPoints(list):
    pass


def _edge(alpha):
    pad = np.pad(alpha, 1)
    edge = alpha & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    y, x = np.nonzero(edge)
    return np.column_stack((x + 0.5, y + 0.5))


def _zigzag(rng, a, b, width=1.0, depth=0):
    length = math.dist(a, b)
    points = [a, b]
    offset = length * 0.42
    while len(points) < 2 + length / 3:
        nxt = [points[0]]
        for p, q in zip(points, points[1:]):
            dx, dy = q[0] - p[0], q[1] - p[1]
            size = math.hypot(dx, dy) or 1
            shift = rng.uniform(-offset, offset)
            nxt.extend([((p[0] + q[0]) / 2 - dy / size * shift,
                         (p[1] + q[1]) / 2 + dx / size * shift), q])
        points = nxt
        offset *= 0.52
    paths = [(points, width)]
    if depth < 2:
        for i in range(2, len(points) - 3):
            if rng.random() >= 0.35 / (1 + depth) / max(4, len(points) / 6):
                continue
            p, q = points[i], points[min(len(points) - 1, i + 3)]
            angle = math.atan2(q[1] - p[1], q[0] - p[0]) + rng.choice((-1, 1)) * rng.uniform(0.35, 0.9)
            size = (length - i / len(points) * length) * rng.uniform(0.25, 0.55)
            tip = (p[0] + math.cos(angle) * size, p[1] + math.sin(angle) * size)
            paths.extend(_zigzag(rng, p, tip, width * 0.55, depth + 1))
    return paths


def contacts_for(key, alpha, groups=None):
    rng = random.Random(int(hashlib.sha256(key.encode()).hexdigest()[:16], 16))
    groups = groups or [(0, alpha)]
    patterns = []
    for part, visible in groups:
        edge = _edge(visible)
        if not len(edge):
            continue
        for _ in range(12 if len(groups) > 1 else 32):
            a = edge[rng.randrange(len(edge))]
            distances = np.linalg.norm(edge - a, axis=1)
            nearby = edge[(distances >= 6) & (distances <= 14)]
            if not len(nearby):
                nearby = edge[distances >= 3]
            if not len(nearby):
                continue
            b = nearby[rng.randrange(len(nearby))]
            frames = []
            for _frame in range(4):
                segments = PackedPoints()
                for points, width in _zigzag(rng, tuple(a), tuple(b)):
                    # Store segment ends and width; the GPU rasterizes on the source pixel grid.
                    for p, q in zip(points, points[1:]):
                        segments.extend([tuple(round(float(v), 4) for v in p),
                                         tuple(round(float(v), 4) for v in q), (width, width)])
                frames.append(segments)
            patterns.append({"a": tuple(a), "b": tuple(b), "part": part, "frames": frames})
    if not patterns:
        raise ValueError("No elite contact pairs: " + key)
    return patterns
