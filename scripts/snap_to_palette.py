#!/usr/bin/env python3
"""Snap every pixel of a PNG sprite to the nearest color in a GIMP palette.

Usage:
  snap_to_palette.py <input.png> <palette.gpl> <output.png>

Pixels with alpha < 128 are treated as fully transparent and left as such.
Color matching uses squared distance in sRGB (good enough for pixel art).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from PIL import Image

ALPHA_THRESHOLD = 128


def load_gpl(path: Path) -> list[tuple[int, int, int]]:
    colors: list[tuple[int, int, int]] = []
    for line in path.read_text().splitlines():
        s = line.strip()
        if not s or s.startswith("#") or s.startswith(("GIMP", "Name:", "Columns:")):
            continue
        m = re.match(r"\s*(\d+)\s+(\d+)\s+(\d+)", line)
        if m:
            colors.append((int(m.group(1)), int(m.group(2)), int(m.group(3))))
    if not colors:
        raise SystemExit(f"no colors found in palette {path}")
    return colors


def make_snapper(palette: list[tuple[int, int, int]]):
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}

    def snap(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
        if rgb in cache:
            return cache[rgb]
        r, g, b = rgb
        best = min(
            palette,
            key=lambda p: (p[0] - r) ** 2 + (p[1] - g) ** 2 + (p[2] - b) ** 2,
        )
        cache[rgb] = best
        return best

    return snap


def snap_image(img: Image.Image, snap) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < ALPHA_THRESHOLD:
                px[x, y] = (0, 0, 0, 0)
            else:
                nr, ng, nb = snap((r, g, b))
                px[x, y] = (nr, ng, nb, 255)
    return img


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(f"usage: {argv[0]} <input.png> <palette.gpl> <output.png>", file=sys.stderr)
        return 1
    src = Path(argv[1])
    palette_path = Path(argv[2])
    dst = Path(argv[3])
    palette = load_gpl(palette_path)
    print(f"loaded {len(palette)} colors from {palette_path}", file=sys.stderr)
    snap = make_snapper(palette)
    img = Image.open(src)
    snap_image(img, snap).save(dst)
    print(f"wrote {dst}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
