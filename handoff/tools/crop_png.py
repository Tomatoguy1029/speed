# Stdlib-only: crop a region of an 8-bit RGB/RGBA PNG and scale it up by an integer factor (nearest).
import sys, struct, zlib

def read_png(path):
    b = open(path, "rb").read(); p = 8; idat = b""
    while p < len(b):
        n = struct.unpack(">I", b[p:p + 4])[0]; t = b[p + 4:p + 8]; d = b[p + 8:p + 8 + n]; p += 12 + n
        if t == b"IHDR": w, h, depth, ctype = struct.unpack(">IIBB", d[:10])
        elif t == b"IDAT": idat += d
    bpp = {2: 3, 6: 4}[ctype]; raw = zlib.decompress(idat); stride = w * bpp
    rows = []; prev = bytearray(stride); i = 0
    for y in range(h):
        f = raw[i]; line = bytearray(raw[i + 1:i + 1 + stride]); i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0; up = prev[x]; c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + up) & 255
            elif f == 3: line[x] = (line[x] + (a + up) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(up - c), abs(a - c), abs(a + up - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else up if pb <= pc else c)) & 255
        rows.append(line); prev = line
    return w, h, bpp, rows

def write_png(path, w, h, rows):
    raw = b"".join(b"\0" + bytes(r) for r in rows)
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))

src, dst, x0, y0, cw, ch, s = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:8])
w, h, bpp, rows = read_png(src)
out = []
for y in range(ch):
    line = bytearray()
    for x in range(cw):
        px = rows[y0 + y][(x0 + x) * bpp:(x0 + x) * bpp + 3]
        line += px * s
    for _ in range(s): out.append(line)
write_png(dst, cw * s, ch * s, out)
