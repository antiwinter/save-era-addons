#!/usr/bin/env python3
"""Convert an RGBA PNG to the BLP2 variant WoW's stock art uses:
uncompressed BGRA8888 with a full mip chain. Needs Pillow."""
import struct, sys
from PIL import Image


def png2blp(src, dst):
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    if (w & (w - 1)) or (h & (h - 1)):
        raise SystemExit(f"dimensions must be power-of-two, got {w}x{h}")

    mips, cur = [], img
    while True:
        mips.append(cur)
        if cur.width == 1 and cur.height == 1:
            break
        cur = cur.resize((max(1, cur.width // 2), max(1, cur.height // 2)), Image.LANCZOS)

    HEADER = 4 + 4 + 4 + 4 + 4 + 16 * 4 + 16 * 4
    PALETTE = 256 * 4
    offsets, sizes, blobs, off = [0] * 16, [0] * 16, [], HEADER + PALETTE
    for i, m in enumerate(mips):
        b = bytearray()
        for r, g, bl, a in m.get_flattened_data():
            b += bytes((bl, g, r, a))  # BGRA
        blobs.append(bytes(b))
        offsets[i], sizes[i] = off, len(b)
        off += len(b)

    out = bytearray(b"BLP2")
    out += struct.pack("<I", 1)   # type: direct
    out += struct.pack("<B", 3)   # encoding: uncompressed BGRA8888
    out += struct.pack("<B", 8)   # alpha depth
    out += struct.pack("<B", 8)   # alpha type
    out += struct.pack("<B", 1)   # has mips
    out += struct.pack("<I", w) + struct.pack("<I", h)
    for o in offsets:
        out += struct.pack("<I", o)
    for s in sizes:
        out += struct.pack("<I", s)
    out += b"\x00" * PALETTE
    for blob in blobs:
        out += blob

    with open(dst, "wb") as f:
        f.write(out)
    print(f"wrote {dst}: {w}x{h}, {len(mips)} mips, {len(out)} bytes")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: png2blp.py <src.png> <dst.blp>")
    png2blp(sys.argv[1], sys.argv[2])
