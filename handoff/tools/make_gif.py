# Stdlib-only GIF89a encoder: raw RGB8 frames -> looping animated GIF with a shared 256-color palette.
import sys, os, struct
from collections import Counter

src, out, w, h, fps = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
names = sorted(n for n in os.listdir(src) if n.endswith(".raw"))
frames = [open(os.path.join(src, n), "rb").read() for n in names]

counts = Counter()
for f in frames[:: max(1, len(frames) // 12)]:
    counts.update(f[i:i + 3] for i in range(0, len(f), 3 * 7))
palette = [c for c, _ in counts.most_common(256)]
while len(palette) < 256: palette.append(b"\0\0\0")
pal_rgb = [tuple(c) for c in palette]
cache = {c: i for i, c in enumerate(palette)}

def index(c):
    i = cache.get(c)
    if i is None:
        r, g, b = c
        i = min(range(256), key=lambda k: (pal_rgb[k][0] - r) ** 2 * 3 + (pal_rgb[k][1] - g) ** 2 * 4 + (pal_rgb[k][2] - b) ** 2 * 2)
        cache[c] = i
    return i

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

g = bytearray(b"GIF89a" + struct.pack("<HHBBB", w, h, 0xF7, 0, 0))
for c in palette: g += c
g += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"
delay = round(100 / fps)
for f in frames:
    idx = bytes(index(f[i:i + 3]) for i in range(0, len(f), 3))
    g += b"\x21\xF9\x04\x04" + struct.pack("<H", delay) + b"\x00\x00"
    g += b"\x2C" + struct.pack("<HHHHB", 0, 0, w, h, 0) + b"\x08"
    data = lzw(idx)
    for i in range(0, len(data), 255):
        chunk = data[i:i + 255]; g += bytes([len(chunk)]) + chunk
    g += b"\x00"
g += b"\x3B"
open(out, "wb").write(g)
print(out, len(frames), "frames", len(g) // 1024, "KB")
