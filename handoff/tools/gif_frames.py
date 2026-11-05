# Stdlib-only GIF decoder: writes chosen frames of a GIF as PNG (full canvas, frames composited in order).
import sys, struct, zlib

def lzw_decode(data, min_size, count):
    clear, end = 1 << min_size, (1 << min_size) + 1
    size = min_size + 1
    table = [bytes([i]) for i in range(clear)] + [b"", b""]
    out = bytearray(); prev = None; bits = 0; nbits = 0; pos = 0
    while len(out) < count:
        while nbits < size and pos < len(data):
            bits |= data[pos] << nbits; nbits += 8; pos += 1
        if nbits < size: break
        code = bits & ((1 << size) - 1); bits >>= size; nbits -= size
        if code == clear:
            table = table[:end + 1]; size = min_size + 1; prev = None; continue
        if code == end: break
        if code < len(table):
            entry = table[code]
            if prev is not None: table.append(prev + entry[:1])
        else:
            entry = prev + prev[:1]; table.append(entry)
        out += entry; prev = entry
        if len(table) == (1 << size) and size < 12: size += 1
    return out

def png(path, w, h, rgb):
    raw = b"".join(b"\0" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))

src, out_prefix, wanted = sys.argv[1], sys.argv[2], {int(x) for x in sys.argv[3].split(",")}
b = open(src, "rb").read()
w, h, flags = struct.unpack("<HHB", b[6:11]); p = 13
gct = None
if flags & 0x80:
    n = 3 * (2 << (flags & 7)); gct = b[p:p + n]; p += n
canvas = bytearray(w * h * 3); index = 0
while p < len(b):
    tag = b[p]; p += 1
    if tag == 0x3B: break
    if tag == 0x21:
        p += 1
        while b[p]: p += b[p] + 1
        p += 1; continue
    if tag == 0x2C:
        x, y, fw, fh, fl = struct.unpack("<HHHHB", b[p:p + 9]); p += 9
        pal = gct
        if fl & 0x80:
            n = 3 * (2 << (fl & 7)); pal = b[p:p + n]; p += n
        min_size = b[p]; p += 1; data = bytearray()
        while b[p]: data += b[p + 1:p + 1 + b[p]]; p += b[p] + 1
        p += 1
        if index in wanted or index <= max(wanted):
            idx = lzw_decode(bytes(data), min_size, fw * fh)
            for j in range(fh):
                for i in range(fw):
                    k = idx[j * fw + i] if j * fw + i < len(idx) else 0
                    o = ((y + j) * w + x + i) * 3; canvas[o:o + 3] = pal[k * 3:k * 3 + 3]
            if index in wanted: png(f"{out_prefix}{index:03d}.png", w, h, canvas)
        index += 1
        if index > max(wanted): break
print("frames read", index)
