#!/usr/bin/env python3
"""Make an invisible copy of a Steam Frame controller render model.

Reads Valve's model JSON (read only), writes <out_dir>/<name>/<name>.json plus a tiny empty mesh.
Every component that has geometry is pointed at a single zero-size triangle and marked not visible.
Components without geometry (tip, base, grip, openxr_aim, openxr_grip, handgrip, ...) are kept
exactly, because SteamVR uses them for the laser pointer and for game aim/grip poses.

usage: make_hidden_model.py <valve_model.json> <out_dir> <name>
"""
import json
import os
import struct
import sys
import zlib


def png_1x1_transparent() -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    raw = b"\x00" + b"\x00\x00\x00\x00"  # filter byte + one RGBA pixel, fully transparent
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


EMPTY_OBJ = """mtllib empty.mtl
v 0 0 0
v 0 0 0
v 0 0 0
vt 0 0
vn 0 0 1
usemtl empty
f 1/1/1 2/1/1 3/1/1
"""

EMPTY_MTL = """newmtl empty
Ka 0 0 0
Kd 0 0 0
d 0
map_Kd empty.png
"""


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    src, out_dir, name = sys.argv[1:]
    with open(src) as f:
        model = json.load(f)

    hidden = {}
    for key, comp in model.get("components", {}).items():
        comp = dict(comp)
        if "filename" in comp:
            comp["filename"] = "empty.obj"
            comp.pop("motion", None)  # nothing to animate
            comp["visibility"] = {"default": False}
        hidden[key] = comp
    if not hidden:
        print(f"no components in {src}; refusing to write an empty model", file=sys.stderr)
        return 1

    dest = os.path.join(out_dir, name)
    os.makedirs(dest, exist_ok=True)
    with open(os.path.join(dest, name + ".json"), "w") as f:
        json.dump({"components": hidden}, f, indent=2)
    with open(os.path.join(dest, "empty.obj"), "w") as f:
        f.write(EMPTY_OBJ)
    with open(os.path.join(dest, "empty.mtl"), "w") as f:
        f.write(EMPTY_MTL)
    with open(os.path.join(dest, "empty.png"), "wb") as f:
        f.write(png_1x1_transparent())
    kept = [k for k, c in hidden.items() if "filename" not in c]
    print(f"{name}: {len(hidden) - len(kept)} parts hidden, kept poses: {', '.join(kept)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
