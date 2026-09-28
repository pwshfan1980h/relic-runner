#!/usr/bin/env python3
"""Generates Relic Runner environment art into assets/sprites (no dependencies).

Run from the project root:  python3 tools/gen_art.py

90s look: limited palettes, ordered (Bayer) dithering between palette steps,
light from the upper left. Characters are not here - they are polygon rigs in code.

Tilesets: 16x16 tiles, one column per 4-neighbour mask (U=1 R=2 D=4 L=8, bit set =
neighbour is solid), two rows of variants. Backdrops tile horizontally (480 wide).
"""
import math
import os
import random
import struct
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sprites")
T = 16
CLEAR = (0, 0, 0, 0)

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def ramp(pal, v, x, y):
    """Dithered pick along a palette ramp; v in 0..1."""
    v = max(0.0, min(0.9999, v)) * (len(pal) - 1)
    i = int(v)
    return pal[i + 1] if (v - i) > bayer(x, y) and i + 1 < len(pal) else pal[i]


def ramp_soft(pal, v, x, y, width=0.3):
    """Like ramp, but flat tones with dithering only in a narrow band between them."""
    v = max(0.0, min(0.9999, v)) * (len(pal) - 1)
    i = int(v)
    f = v - i
    lo, hi = 0.5 - width / 2, 0.5 + width / 2
    if f < lo or i + 1 >= len(pal):
        return pal[i]
    if f > hi:
        return pal[i + 1]
    return pal[i + 1] if (f - lo) / width > bayer(x, y) else pal[i]


class Canvas:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 3:
                c = (*c, 255)
            self.px[y][x] = c

    def get(self, x, y):
        return self.px[y][x]

    def blit(self, src, ox, oy):
        for y in range(src.h):
            for x in range(src.w):
                c = src.px[y][x]
                if c[3]:
                    self.set(ox + x, oy + y, c)

    def save(self, name):
        raw = b"".join(b"\x00" + b"".join(struct.pack("4B", *p) for p in row) for row in self.px)

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
        with open(os.path.join(OUT, name + ".png"), "wb") as f:
            f.write(png)
        print("wrote", name, self.w, "x", self.h)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def periodic_noise(x, period, seed, octaves=4):
    """Smooth 1-D noise that repeats every `period` px (for tiling backdrops)."""
    rng = random.Random(seed)
    v, amp, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        k = 2 ** o
        ph = rng.uniform(0, math.tau)
        ph2 = rng.uniform(0, math.tau)
        v += amp * (math.sin(math.tau * k * x / period + ph) * 0.6 + math.sin(math.tau * (k + 1) * x / period + ph2) * 0.4)
        tot += amp
        amp *= 0.55
    return v / tot


# --- Biome palettes -----------------------------------------------------------

BIOMES = {
    "canyon": {
        "rock": [hexc(c) for c in ("#3a1f14", "#5c3320", "#7e4a2a", "#9c6236", "#b87c45")],
        "crust": [hexc(c) for c in ("#b87c45", "#d6a060", "#ecc684")],
        "under": hexc("#22120c"),
        "strata": 5,
        "grit": hexc("#e8c690"),
    },
    "jungle": {
        "rock": [hexc(c) for c in ("#1a2420", "#2c3a30", "#445244", "#5e6a52", "#7a8266")],
        "crust": [hexc(c) for c in ("#2f6a28", "#4f9434", "#86c24a")],
        "under": hexc("#0c1210"),
        "strata": 8,
        "grit": hexc("#a7b08a"),
    },
}


def tile(biome, mask, variant):
    b = BIOMES[biome]
    rng = random.Random(mask * 31 + variant * 977 + len(biome))
    c = Canvas(T, T)
    up, right, down, left = mask & 1, mask & 2, mask & 4, mask & 8
    for y in range(T):
        for x in range(T):
            # Strata: horizontal banding with a gentle wobble, plus grain.
            band = math.sin((y + 0.8 * math.sin(x * 0.4 + variant * 2.1)) * math.tau / b["strata"])
            v = 0.55 + band * 0.12 + rng.uniform(-0.025, 0.025)
            # Ambient light: exposed faces catch light (top/left) or fall into shade (right/bottom).
            if not up:
                v += max(0, 4 - y) * 0.05
            if not left:
                v += max(0, 3 - x) * 0.04
            if not right:
                v -= max(0, x - (T - 4)) * 0.06
            if not down:
                v -= max(0, y - (T - 5)) * 0.08
            if biome == "jungle":
                # Temple blocks: mortar lines every 8px, offset per row.
                if y % 8 == 0 or (x + (4 if (y // 8) % 2 else 0)) % 8 == 0:
                    v -= 0.22
            col = ramp_soft(b["rock"], v, x, y)
            c.set(x, y, col)
    # An occasional hairline crack, following the strata more than crossing it.
    if rng.random() < 0.45:
        x, y = rng.randrange(2, T - 5), rng.randrange(4, T - 3)
        for _ in range(rng.randrange(3, 6)):
            c.set(x, y, b["rock"][1])
            x += 1
            y += rng.choice((0, 0, 1))
    # Pebbles / grit.
    for _ in range(1):
        c.set(rng.randrange(T), rng.randrange(4, T), b["grit"] if rng.random() < 0.3 else b["rock"][3])
    if not up:
        # Walkable crust: bright lip, dithered into the rock, dark line under it.
        for x in range(T):
            depth = 2 + (1 if rng.random() < 0.35 else 0)
            for y in range(depth):
                c.set(x, y, ramp(b["crust"], 1.0 - y / (depth + 0.5), x, y))
            c.set(x, depth, b["rock"][1])
            if biome == "jungle" and rng.random() < 0.3:
                # Hanging moss strands.
                for y in range(depth, depth + rng.randrange(1, 4)):
                    c.set(x, y, b["crust"][0])
    if not down:
        for x in range(T):
            c.set(x, T - 1, b["under"])
            if rng.random() < 0.5:
                c.set(x, T - 2, b["under"])
    if not left:
        for y in range(T):
            c.set(0, y, b["rock"][4] if up or y > 2 else c.get(0, y)[:3])
    if not right:
        for y in range(T):
            c.set(T - 1, y, b["under"] if up or y > 2 else c.get(T - 1, y)[:3])
    return c


def tileset(biome):
    sheet = Canvas(T * 16, T * 2)
    for mask in range(16):
        for v in range(2):
            sheet.blit(tile(biome, mask, v), mask * T, v * T)
    sheet.save(biome + "_tiles")


# --- Canyon backdrops ---------------------------------------------------------

W, H = 480, 270

# --- Backdrops ----------------------------------------------------------------
# The sky itself is a shader driven by the time of day (scripts/world/sky.gd); these
# are the silhouettes in front of it. They are deliberately calm: flat fills, two or
# three tones lit from the upper left, and dithering only in a narrow transition band,
# so they read as distance instead of noise. The game tints them per time of day and
# fades each layer toward the horizon colour (atmospheric perspective).


def shade_column(c, x, top, pal, rim=2, band=None, seed=0):
    """Fill x from `top` down: lit rim, body, darker base; banded strata optional."""
    for y in range(int(top), H):
        d = y - top
        if d < rim:
            col = pal[-1]
        else:
            v = 0.62 - min(0.5, d / 260.0)
            if band:
                v += 0.08 * math.sin((y + periodic_noise(x, W, seed, 2) * 6) * math.tau / band)
            # Two-pixel dither transition between tones, nothing more.
            col = ramp(pal[:-1], v, x, y) if abs((v * (len(pal) - 2)) % 1 - 0.5) < 0.12 else pal[min(len(pal) - 2, int(v * (len(pal) - 2) + 0.5))]
        c.set(x, y, col)


def canyon_far():
    c = Canvas(W, H)
    pal = [hexc(h) for h in ("#8a6a6c", "#a07c78", "#b89088", "#d0a898")]
    for x in range(W):
        n = periodic_noise(x, W, 11, 3)
        top = 150 + n * 26
        top = round(top / 10) * 10  # flat-topped mesas with sheer sides
        shade_column(c, x, top, pal, rim=1)
    c.save("canyon_far")


def canyon_mid():
    c = Canvas(W, H)
    pal = [hexc(h) for h in ("#6a3c2c", "#84503a", "#9c6446", "#c08058")]
    for x in range(W):
        n = periodic_noise(x, W, 21, 4)
        top = 178 + n * 34
        spire = max(0.0, periodic_noise(x, W / 3, 23, 2) - 0.55) * 150
        shade_column(c, x, top - spire, pal, rim=2, band=14, seed=22)
    c.save("canyon_mid")


def canyon_near():
    c = Canvas(W, H)
    pal = [hexc(h) for h in ("#2e1810", "#40221a", "#56301f", "#7a4a2e")]
    for x in range(W):
        top = 218 + periodic_noise(x, W, 31, 4) * 26
        shade_column(c, x, top, pal, rim=1)
    rng = random.Random(33)
    for _ in range(8):
        bx = rng.randrange(W)
        base = 218 + periodic_noise(bx, W, 31, 4) * 26
        for _ in range(10):
            x, y = bx, int(base)
            for _ in range(rng.randrange(4, 11)):
                c.set(x % W, y, pal[0])
                x += rng.choice((-1, 0, 1))
                y -= 1
    c.save("canyon_near")


def jungle_far():
    c = Canvas(W, H)
    pal = [hexc(h) for h in ("#4a6a5c", "#587a68", "#6a8c76", "#86a88c")]
    # Distant temple ziggurat on a ridge.
    base, cx = 188, 150
    for step in range(6):
        half = 58 - step * 9
        top = base - step * 11
        for y in range(top - 11, top):
            for x in range(cx - half, cx + half):
                c.set(x, y, pal[2] if y == top - 11 else pal[1])
    for x in range(W):
        top = 172 + periodic_noise(x, W, 41, 4) * 22
        shade_column(c, x, top, pal, rim=1)
    c.save("jungle_far")


def jungle_mid():
    c = Canvas(W, H)
    pal = [hexc(h) for h in ("#16301e", "#1e3e28", "#2a5032", "#3e6a3e", "#5a8a48")]
    rng = random.Random(51)
    for i in range(6):
        tx = int(W * i / 6 + rng.randrange(-24, 24)) % W
        tw = rng.randrange(7, 12)
        for y in range(40, H):
            wob = int(2 * math.sin(y * 0.03 + i))
            for k in range(tw):
                c.set((tx + k + wob) % W, y, pal[2] if k < 2 else (pal[0] if k > tw - 3 else pal[1]))
    # Canopy: rounded leaf masses in flat tones, lit rims on the lower-left.
    for x in range(W):
        edge = 60 + periodic_noise(x, W, 52, 5) * 22
        for y in range(0, int(edge)):
            c.set(x, y, pal[0] if y < edge - 6 else pal[1])
    for _ in range(420):
        bx = rng.randrange(W)
        edge = 60 + periodic_noise(bx, W, 52, 5) * 22
        by = rng.uniform(-4, edge + 8)
        r = rng.uniform(4.0, 9.0)
        for y in range(int(by - r), int(by + r) + 1):
            for x in range(int(bx - r), int(bx + r) + 1):
                dx, dy = x - bx, y - by
                d = math.hypot(dx, dy * 1.3) / r
                if d < 1 and y >= 0:
                    lit = -(dx + dy) / r
                    col = pal[3] if lit > 0.9 and d > 0.6 else (pal[2] if lit > 0.2 else pal[1])
                    c.set(x % W, y, col)
    for _ in range(16):
        x = rng.randrange(W)
        top = int(66 + periodic_noise(x, W, 52, 5) * 24)
        for y in range(top, top + rng.randrange(40, 130)):
            c.set((x + int(1.5 * math.sin(y * 0.08 + x))) % W, y, pal[1])
    c.save("jungle_mid")


def jungle_near():
    c = Canvas(W, H)
    pal = [hexc(h) for h in ("#08140c", "#10241a", "#1c3824")]
    rng = random.Random(61)
    for x in range(W):
        top = 240 + periodic_noise(x, W, 62, 4) * 10
        for y in range(int(top), H):
            c.set(x, y, pal[0] if y > top + 1 else pal[1])
    for _ in range(22):
        bx = rng.randrange(W)
        by = 250 + rng.randrange(0, 12)
        lean = rng.choice((-1, 1)) * rng.uniform(0.4, 1.0)
        length = rng.randrange(30, 58)
        for i in range(length):
            t = i / length
            x = bx + lean * i * 0.9
            y = by - i * (1.0 - t) * 1.1
            c.set(int(x) % W, int(y), pal[1])
            if i % 3 == 0 and i > 4:
                leaf = int(6 * math.sin(math.pi * t) + 1)
                for k in range(1, leaf):
                    c.set(int(x - lean * k * 0.3) % W, int(y + k), pal[2 if k < 2 else 1])
                    c.set(int(x + lean * k * 0.3) % W, int(y + k * 0.6), pal[1])
    c.save("jungle_near")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for b in BIOMES:
        tileset(b)
    canyon_far()
    canyon_mid()
    canyon_near()
    jungle_far()
    jungle_mid()
    jungle_near()
