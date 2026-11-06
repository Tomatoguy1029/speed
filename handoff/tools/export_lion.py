# Stdlib-only: lion_aura.aseprite -> two PNGs for hero_leo.gdshader.
#   lion_body.png : frames side by side (W*frames x H). RGB = layer shade (gray), A = body coverage (body/legs/fur/head).
#   lion_aux.png  : W x H, opaque. R = face mask, G = eyes, B = tail coverage.
# Usage: py -3 -I export_lion.py <in.aseprite> <out_dir>
import sys, struct, zlib, os

EYES = [(51, 25), (52, 25), (53, 25), (63, 25), (64, 25), (65, 25), (50, 26), (51, 26), (52, 26), (53, 26), (63, 26), (64, 26),
        (65, 26), (66, 26), (49, 27), (50, 27), (51, 27), (52, 27), (53, 27), (63, 27), (64, 27), (65, 27), (66, 27), (67, 27),
        (48, 28), (49, 28), (50, 28), (51, 28), (52, 28), (64, 28), (65, 28), (66, 28), (67, 28), (68, 28), (47, 29), (48, 29),
        (49, 29), (50, 29), (51, 29), (65, 29), (66, 29), (67, 29), (68, 29), (69, 29), (47, 30), (48, 30), (49, 30), (50, 30),
        (66, 30), (67, 30), (68, 30), (69, 30)]
# はぐれた1ドット（fur）
STRAY = {("fur", 107, 184)}

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
b = open(src, "rb").read()
_, magic, nframes, W, H, depth = struct.unpack("<IHHHHH", b[:14])
assert magic == 0xA5E0 and depth == 32
layers = []; frames = []
p = 128
for fi in range(nframes):
    flen, _, oldn, _ = struct.unpack("<IHHH", b[p:p + 10])
    newn = struct.unpack("<I", b[p + 12:p + 16])[0]
    q = p + 16; cels = {}
    for _ in range(newn or oldn):
        clen, ctype = struct.unpack("<IH", b[q:q + 6]); d = b[q + 6:q + clen]
        if ctype == 0x2004:
            n = struct.unpack("<H", d[16:18])[0]; layers.append(d[18:18 + n].decode())
        elif ctype == 0x2005:
            li, x, y, _, ct = struct.unpack("<HhhBH", d[:9])
            if ct in (0, 2):
                w, h = struct.unpack("<HH", d[16:20]); raw = d[20:]
                cels[li] = (x, y, w, h, zlib.decompress(raw) if ct == 2 else raw)
            elif ct == 1:
                cels[li] = ("link", struct.unpack("<H", d[16:18])[0])
        q += clen
    frames.append(cels); p += flen

def cel(fi, li):
    c = frames[fi].get(li)
    if c and c[0] == "link": c = frames[c[1]].get(li)
    return c

def plot(fi, name):
    li = layers.index(name); c = cel(fi, li); res = {}
    if not c: return res
    x0, y0, w, h, px = c
    for yy in range(h):
        for xx in range(w):
            r, g, bb, a = px[(yy * w + xx) * 4:(yy * w + xx) * 4 + 4]
            X, Y = x0 + xx, y0 + yy
            if a and 0 <= X < W and 0 <= Y < H and (name, X, Y) not in STRAY: res[(X, Y)] = bb
    return res

def write_png(path, w, h, rows, ctype):
    raw = b"".join(b"\0" + bytes(r) for r in rows)
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

body_rows = [bytearray(W * nframes * 4) for _ in range(H)]
for fi in range(nframes):
    for name in ("body", "legs", "fur", "head"):  # 下から順に重ねる
        for (X, Y), v in plot(fi, name).items():
            i = (fi * W + X) * 4; body_rows[Y][i:i + 4] = bytes((v, v, v, 255))
write_png(os.path.join(out, "lion_body.png"), W * nframes, H, body_rows, 6)

aux_rows = [bytearray(W * 3) for _ in range(H)]
mask = layers.index("mask"); x0, y0, w, h, px = cel(0, mask)
for yy in range(h):
    for xx in range(w):
        if px[(yy * w + xx) * 4] > 127 and px[(yy * w + xx) * 4 + 3]: aux_rows[y0 + yy][(x0 + xx) * 3] = 255
for X, Y in EYES: aux_rows[Y][X * 3 + 1] = 255
for (X, Y) in plot(0, "tails"): aux_rows[Y][X * 3 + 2] = 255
write_png(os.path.join(out, "lion_aux.png"), W, H, aux_rows, 2)
print(f"{W}x{H} frames {nframes} -> {out}")
