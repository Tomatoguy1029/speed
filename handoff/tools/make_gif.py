# Stdlib-only GIF89a encoder: raw RGB8 frames -> looping animated GIF.
# Each frame gets its own 256-color palette (median cut over that frame's colors), so wide gradients in one part of
# the screen do not steal colors from small subjects. Colors are mapped to the box median cut put them in.
import sys, os, struct
from collections import Counter

src, out, w, h, fps = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
names = sorted(n for n in os.listdir(src) if n.endswith(".raw"))

def median_cut(counts, size=256):
    """counts: {rgb bytes: n}. Returns (palette list of 3-byte, mapping {rgb bytes: index})."""
    boxes = [list(counts.items())]
    while len(boxes) < size:
        # split the box with the widest channel range (weighted by population)
        best, best_score, best_ch = -1, -1, 0
        for bi, box in enumerate(boxes):
            if len(box) < 2: continue
            lo = [min(c[0][k] for c in box) for k in range(3)]
            hi = [max(c[0][k] for c in box) for k in range(3)]
            ch = max(range(3), key=lambda k: hi[k] - lo[k])
            pop = sum(n for _, n in box)
            score = (hi[ch] - lo[ch]) * (pop ** 0.5)
            if score > best_score: best, best_score, best_ch = bi, score, ch
        if best < 0: break
        box = sorted(boxes[best], key=lambda c: c[0][best_ch])
        total = sum(n for _, n in box); acc = 0; cut = 1
        for i, (_, n) in enumerate(box):
            acc += n
            if acc >= total / 2: cut = max(1, min(len(box) - 1, i + 1)); break
        boxes[best:best + 1] = [box[:cut], box[cut:]]
    palette, mapping = [], {}
    for i, box in enumerate(boxes):
        total = sum(n for _, n in box)
        palette.append(bytes(round(sum(c[k] * n for c, n in box) / total) for k in range(3)))
        for c, _ in box: mapping[c] = i
    while len(palette) < size: palette.append(b"\0\0\0")
    return palette, mapping

def lzw(data):
    clear, end = 256, 257
    table = {bytes([i]): i for i in range(256)}
    code_size, next_code = 9, 258
    bits, nbits, out = 0, 0, bytearray()
    def emit(code):
        nonlocal bits, nbits
        bits |= code << nbits
        nbits += code_size
        while nbits >= 8:
            out.append(bits & 255); bits >>= 8; nbits -= 8
    emit(clear)
    cur = b""
    for byte in data:
        nxt = cur + bytes([byte])
        if nxt in table: cur = nxt; continue
        emit(table[cur])
        if next_code < 4096:
            table[nxt] = next_code; next_code += 1
            if next_code > (1 << code_size) and code_size < 12: code_size += 1
        else:
            emit(clear); table = {bytes([i]): i for i in range(256)}; code_size, next_code = 9, 258
        cur = bytes([byte])
    if cur: emit(table[cur])
    emit(end)
    if nbits: out.append(bits & 255)
    return out

g = bytearray(b"GIF89a" + struct.pack("<HHBBB", w, h, 0x70, 0, 0))
g += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"
delay = round(100 / fps)
for name in names:
    f = open(os.path.join(src, name), "rb").read()
    pixels = [f[i:i + 3] for i in range(0, len(f), 3)]
    palette, mapping = median_cut(Counter(pixels))
    idx = bytes(mapping[p] for p in pixels)
    g += b"\x21\xF9\x04\x04" + struct.pack("<H", delay) + b"\x00\x00"
    # image descriptor with a local 256-color table
    g += b"\x2C" + struct.pack("<HHHHB", 0, 0, w, h, 0x87)
    for c in palette: g += c
    g += b"\x08"
    data = lzw(idx)
    for i in range(0, len(data), 255):
        chunk = data[i:i + 255]; g += bytes([len(chunk)]) + chunk
    g += b"\x00"
g += b"\x3B"
open(out, "wb").write(g)
print(out, len(names), "frames", len(g) // 1024, "KB")
