#!/usr/bin/env python3
"""Builds the campaign levels from segment lists: the ASCII maps AND a bot route per level.

Run from the project root:  python3 tools/build_maps.py
Writes scripts/world/campaign_maps.gd (class CampaignMaps) and scripts/game/campaign_routes.gd
(class CampaignRoutes). This file is the source of truth for campaign levels; the generated
ASCII is still readable (see the legend in scripts/world/maps.gd) for a quick look.

A level is a left-to-right run of segments. The builder tracks the ground height (gy, the
row of the ground's top surface) and emits, for every segment that needs a deliberate
action, the matching bot step, so every level is provably finishable at real speed:
  flat, up/down (slopes of any gradient: `run` tiles per tile of rise), step (a ledge to
  climb), drop, gap (long jump), tree_gap (kick the dead tree over), swing (whip chasm),
  swing2 (two anchors), crack (cracked wall under a cliff), gate (pressure plate + gate),
  crumble (crumbling bridge), cave on/off (ceiling + darkness), and story/prop pieces:
  npc, trigger, sign, fragments (slab / cellar / arc), supplies, checkpoints, enemies.
Numbers match the hero: long jump clears 4 tiles comfortably, ledges up to 3 tiles are
grabbed, a swing anchor sits 10 rows over the lip with a 14-tile chasm.
"""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
T = 16


class L:
    def __init__(self, id_, title, biome, H, gy, ambient="Color(1.0, 0.94, 0.86)"):
        self.id, self.title, self.biome, self.H = id_, title, biome, H
        self.gy = gy
        self.x = 0
        self.rows = [[] for _ in range(H)]
        self.route = []
        self.dark = []
        self.ceil = None  # rows of air under a cave ceiling, or None (open sky)
        self._dark_from = None
        self.ambient = ambient
        self.lists = {"signs": [], "npcs": [], "triggers": []}
        self.frag = 0

    # --- grid ---------------------------------------------------------------------
    def _w(self, x):
        for r in self.rows:
            while len(r) <= x:
                r.append(".")

    def put(self, x, y, ch):
        self._w(x)
        self.rows[y][x] = ch

    def get(self, x, y):
        if y < 0 or y >= self.H or x >= len(self.rows[0]):
            return "."
        return self.rows[y][x]

    def column(self, x, top, surface=None):
        """Ground from `top` down; cave ceiling above if in a cave, measured from `surface`
        (the walking level; for pits that's the lip, not the pit floor)."""
        self._w(x)
        for y in range(self.H):
            self.rows[y][x] = "#" if y >= top else "."
        if self.ceil is not None:
            s = top if surface is None else surface
            for y in range(0, max(0, s - self.ceil)):
                self.rows[y][x] = "#"

    def on(self, dx, ch, dy=-1):
        """Put a thing standing on the ground at x+dx (dy rows above the surface)."""
        self.put(self.x + dx, self.gy + dy, ch)

    def _list(self, kind, dx, dy, value):
        self.lists[kind].append((self.gy + dy, self.x + dx, value))

    def go(self, tiles_back=0.0, run=True):
        self.route.append("b.go(%d, %s)" % ((self.x - tiles_back) * T, "true" if run else "false"))

    # --- terrain ----------------------------------------------------------------
    def flat(self, n, things=()):
        """things: (dx, char) or (dx, char, dy)."""
        for i in range(n):
            self.column(self.x + i, self.gy)
        for t in things:
            dy = t[2] if len(t) > 2 else -1
            if t[1] == "L" and len(t) == 2:
                dy = -6  # lanterns hang from the rock, their light two tiles over the floor
            self.put(self.x + t[0], self.gy + dy, t[1])
        self.x += n

    def up(self, rise, run):
        for _ in range(rise):
            for i in range(run):
                self.column(self.x + i, self.gy)
                self.put(self.x + i, self.gy - 1, "/")
            self.x += run
            self.gy -= 1

    def down(self, drop, run):
        for _ in range(drop):
            for i in range(run):
                self.column(self.x + i, self.gy + 1)
                self.put(self.x + i, self.gy, "\\")
            self.x += run
            self.gy += 1

    def step(self, h):
        """A ledge h tiles up (grab and climb)."""
        self.route.append("b.go(%d, true)" % ((self.x - 3) * T))
        self.route.append("b.climb_wall(1)")
        self.gy -= h

    def drop(self, h):
        self.gy += h

    def gap(self, w=4, spikes=True):
        """A pit crossed with a running long jump. Needs 4+ tiles of runway before it."""
        x0 = self.x
        floor = min(self.H - 1, self.gy + 4)
        for i in range(w):
            self.column(x0 + i, floor, self.gy)
            if spikes:
                self.put(x0 + i, floor, "^")
        self.route.append("b.go(%d, true)" % ((x0 - 5) * T))
        self.route.append("b.long_jump(%d, 1, %d)" % (x0 * T - 10, (x0 + w + 1) * T))
        self.x += w

    def tree_gap(self, w=6):
        """A chasm with a dead tree (or pillar) at the lip: kick it over, walk across."""
        x0 = self.x
        edge = x0 - 1
        for k in range(w + 1):
            self.put(edge, self.gy - 1 - k, "Y")
        floor = min(self.H - 1, self.gy + 4)
        for i in range(w):
            self.column(x0 + i, floor, self.gy)
            self.put(x0 + i, floor, "^")
        self.route.append("b.go(%d, true)" % ((edge - 4) * T))
        self.route.append("b.climb_to_contact(1)")
        self.route.append('b.kick_until("kick the tree over", 1, func(): return b.toppler_fallen(%d))' % (edge * T + 8))
        self.route.append("b.go(%d, true)" % ((x0 + w + 2) * T))
        self.x += w

    def swing(self, frag=False):
        """A 14-tile chasm with an anchor 10 rows over the lip, 6 tiles out."""
        x0 = self.x
        ax, ay = x0 + 5, self.gy - 10
        floor = min(self.H - 1, self.gy + 4)
        for i in range(14):
            self.column(x0 + i, floor, self.gy)
            self.put(x0 + i, floor, "^")
        self.put(ax, ay, "o")
        if frag:
            # Hanging low in the arc: only a full-blooded swing reaches it.
            self.put(ax + 3, self.gy - 1, "*")
        self.route.append("b.go(%d, true)" % ((x0 - 3) * T))
        self.route.append("b.go(%d, false)" % (x0 * T - 10))
        self.route.append("b.halt()")
        self.route.append("b.swing(%d, %d, 1, %d)" % (ax, ay, ax * T + 60))
        self.route.append("b.land(1, %d)" % ((x0 + 15) * T))
        self.x += 14

    def swing2(self):
        """A wider chasm crossed on two anchors, the second caught in the air."""
        x0 = self.x
        a1, a2 = x0 + 3, x0 + 9
        ay = self.gy - 11
        floor = min(self.H - 1, self.gy + 4)
        for i in range(15):
            self.column(x0 + i, floor, self.gy)
            self.put(x0 + i, floor, "^")
        self.put(a1, ay, "o")
        self.put(a2, ay, "o")
        self.route.append("b.go(%d, true)" % ((x0 - 3) * T))
        self.route.append("b.go(%d, false)" % (x0 * T - 10))
        self.route.append("b.halt()")
        self.route.append("b.swing(%d, %d, 1, %d)" % (a1, ay, a1 * T + 40))
        self.route.append("b.swing_next(%d, %d, 1, %d)" % (a2, ay, a2 * T + 60))
        self.route.append("b.land(1, %d)" % ((x0 + 16) * T))
        self.x += 15

    def crack(self, h=2):
        """A cliff with a cracked opening at the bottom: kick through (or grenade)."""
        x0 = self.x
        for i in range(3):
            self.column(x0 + i, self.gy)
            for y in range(0, self.gy - h):
                self.put(x0 + i, y, "#")
        for k in range(h):
            self.put(x0, self.gy - 1 - k, "%")
        self.route.append("b.go(%d, true)" % ((x0 - 4) * T))
        self.route.append("b.climb_to_contact(1)")
        self.route.append('b.kick_until("kick through the cracked wall", 1, func(): return b.wall_gone(%d))' % (x0 * T))
        self.x += 3

    def gate(self, run=14):
        """A pressure plate, then a gate `run` tiles on under a rock lintel: sprint."""
        x0 = self.x
        self.flat(run + 3, [(1, "_")])
        gx = x0 + run
        for k in range(3):
            self.put(gx, self.gy - 1 - k, "|")
        for y in range(0, self.gy - 3):
            self.put(gx, y, "#")
            self.put(gx + 1, y, "#")
        self.route.append("b.go(%d, false)" % ((x0 - 1) * T))
        self.route.append("b.dash(%d)" % ((gx + 2) * T))

    def crumble(self, w=6):
        x0 = self.x
        floor = min(self.H - 1, self.gy + 4)
        for i in range(w):
            self.column(x0 + i, floor, self.gy)
            self.put(x0 + i, floor, "^")
            self.put(x0 + i, self.gy, "c")
        self.route.append("b.go(%d, true)" % ((x0 - 4) * T))
        self.route.append("b.dash(%d)" % ((x0 + w + 2) * T))
        self.x += w

    def cave(self, air=7):
        """Enter a cave (or change its ceiling height): rock overhead, darkness, back wall."""
        self.ceil = air
        if self._dark_from is None:
            self._dark_from = self.x

    def open_sky(self):
        if self._dark_from is not None:
            self.dark.append((self._dark_from, self.x - self._dark_from))
        self.ceil = None
        self._dark_from = None

    # --- story & props ----------------------------------------------------------------
    def npc(self, dx, who, talk, after="", reward=None):
        self.on(dx, "N")
        self._list("npcs", dx, -1, [who, talk, after, reward or {}])

    def trigger(self, dx, talk):
        self.on(dx, "!")
        self._list("triggers", dx, -1, talk)

    def sign(self, dx, text):
        self.on(dx, "?")
        self._list("signs", dx, -1, text)

    def slab_fragment(self, dx):
        """A thin rock shelf 4 rows up with a fragment on it: jump, grab, climb."""
        for i in range(4):
            self.put(self.x + dx + i, self.gy - 4, "#")
        self.put(self.x + dx + 2, self.gy - 5, "*")

    def cellar_fragment(self, dx):
        """Loose flagstones over a hollow: a grenade opens it."""
        x = self.x + dx
        for i in range(2):
            self.put(x + i, self.gy, "%")
            self.put(x + i, self.gy + 1, ".")
            self.put(x + i, self.gy + 2, ".")
        self.put(x, self.gy + 2, "*")

    def exit(self, dx):
        self.on(dx, "E")
        self.route.append("b.reach_exit()")

    def raw(self, line):
        self.route.append(line)

    # --- output -------------------------------------------------------------------
    def gd_map(self, hour):
        self.open_sky()
        width = len(self.rows[0])
        rows = ["".join(r) for r in self.rows]
        # Past the right edge counts as rock; make sure the exit side is walled off.
        out = ['\t"%s": {' % self.id,
               '\t\t"title": "%s",' % self.title,
               '\t\t"biome": "%s",' % self.biome,
               '\t\t"hour": %s,' % hour,
               '\t\t"ambient": %s,' % self.ambient,
               '\t\t"dark": [%s],' % ", ".join("Rect2i(%d, 0, %d, %d)" % (x, w, self.H) for x, w in self.dark)]
        for kind in ("signs", "npcs", "triggers"):
            items = [v for _, _, v in sorted(self.lists[kind], key=lambda e: (e[0], e[1]))]
            out.append('\t\t"%s": [' % kind)
            for v in items:
                out.append("\t\t\t%s," % gd_value(v))
            out.append("\t\t],")
        out.append('\t\t"rows": [')
        for r in rows:
            out.append('\t\t\tr"%s",' % r)
        out.append("\t\t],")
        out.append("\t},")
        return "\n".join(out), width

    def gd_route(self):
        name = "_" + self.id
        lines = self.route + ["b.route_built()"]
        return "static func %s(b: Bot) -> void:\n%s\n" % (name, "\n".join("\t" + l for l in lines))


def gd_value(v):
    if isinstance(v, str):
        return '"%s"' % v.replace('"', '\\"')
    if isinstance(v, dict):
        return "{%s}" % ", ".join('"%s": %s' % (k, gd_value(x)) for k, x in v.items())
    if isinstance(v, list):
        return "[%s]" % ", ".join(gd_value(x) for x in v)
    return str(v)


# --- The campaign --------------------------------------------------------------------

def dry_gulch():
    m = L("dry_gulch", "Dry Gulch", "canyon", 32, 24)
    m.flat(4)
    m.flat(12, [(2, "P")])
    m.npc(-5, "hattie", "hattie_hello", "hattie_after", {"gold": 10})
    m.sign(-1, "A / D to walk. Hold SHIFT to run. Let go at speed and you'll skid.")
    m.up(1, 4)
    m.flat(6)
    m.up(1, 2)
    m.flat(5)
    m.down(1, 3)
    m.down(1, 4)
    m.flat(8)
    m.sign(-3, "SPACE jumps. Jump at a ledge to grab its lip, then W to climb.")
    m.step(2)
    m.flat(10, [(5, "s")])
    m.slab_fragment(2)
    m.flat(6)
    m.sign(-5, "Run, then SPACE: a running jump clears wide gaps.")
    m.gap(4)
    m.flat(10, [(3, "K")])
    m.trigger(-4, "gulch_crane_sign")
    m.up(2, 2)
    m.flat(6)
    m.down(2, 3)
    m.flat(12, [(6, "r")])
    m.sign(-10, "Hold RIGHT MOUSE to raise your revolver; LEFT MOUSE fires. X reloads.")
    m.trigger(-2, "gulch_tree")
    m.tree_gap(6)
    m.flat(14, [(5, "d"), (8, "d"), (11, "g")])
    m.flat(8)
    m.npc(-6, "hattie", "hattie_rope", "hattie_rope")
    m.swing()
    m.flat(10, [(3, "K")])
    m.sign(-6, "Loose flagstones. Tap Q to lob a grenade, or hold Q to aim it.")
    m.cellar_fragment(-3)
    m.up(3, 3)
    m.flat(12, [(4, "B"), (9, "l")])
    m.down(1, 2)
    m.down(2, 3)
    m.flat(6)
    m.sign(-4, "Cracked rock. Kick it (F), or throw a grenade.")
    m.crack()
    m.flat(12, [(6, "m"), (10, "K")])
    m.swing(frag=True)
    m.flat(8, [(4, "s")])
    m.up(1, 1)
    m.flat(6)
    m.up(1, 3)
    m.flat(16)
    m.npc(-10, "tomas", "tomas_camp1", "tomas_camp1")
    m.exit(-4)
    m.flat(3)
    return m


def rattler_mesa():
    m = L("rattler_mesa", "Rattler Mesa", "canyon", 60, 54)
    m.flat(12, [(2, "P")])
    m.trigger(-4, "mesa_start")
    m.up(2, 3)
    m.flat(6, [(3, "r")])
    m.step(3)
    m.flat(8)
    m.up(3, 2)
    m.flat(6)
    m.step(2)
    m.flat(10, [(5, "s"), (8, "K")])
    m.slab_fragment(1)
    m.up(2, 1)
    m.flat(8, [(4, "l")])
    m.gap(4)
    m.flat(8)
    m.step(3)
    m.flat(10, [(4, "r"), (8, "g")])
    m.trigger(-1, "mesa_journal")
    m.up(4, 2)
    m.flat(8, [(5, "K")])
    m.tree_gap(6)
    m.flat(8, [(4, "d")])
    m.step(3)
    m.flat(8)
    m.up(2, 4)
    m.flat(10, [(3, "s"), (7, "r")])
    m.cellar_fragment(-5)
    m.swing(frag=True)
    m.flat(8, [(5, "K")])
    m.step(3)
    m.flat(6)
    m.up(3, 1)
    m.flat(8, [(4, "l")])
    m.step(2)
    m.flat(6)
    m.crack()
    m.flat(8, [(3, "m")])
    m.up(2, 2)
    m.flat(14, [(4, "T"), (10, "T")])
    m.trigger(-8, "mesa_top")
    m.exit(-3)
    m.flat(3)
    return m


def bandit_mine():
    m = L("bandit_mine", "The Silver Mine", "canyon", 34, 24)
    m.flat(14, [(2, "P"), (9, "B")])
    m.down(1, 3)
    m.flat(8, [(4, "d"), (6, "d")])
    m.cave(8)
    m.flat(6, [(2, "L")], )
    m.trigger(-3, "mine_enter")
    m.flat(12, [(3, "C"), (4, "C"), (8, "B"), (10, "L")])
    m.flat(8, [(2, "K")])
    m.gap(4)
    m.flat(10, [(3, "L"), (6, "m")])
    m.down(1, 2)
    m.flat(10, [(2, "T"), (7, "B")])
    m.slab_fragment(3)
    m.cave(12)
    m.flat(4, [(2, "L")])
    m.swing()
    m.flat(10, [(3, "K"), (7, "L")])
    m.npc(-4, "nico", "nico_help", "nico_after", {"grenades": 3})
    m.trigger(-1, "mine_wall")
    m.cave(8)
    m.crack()
    m.flat(10, [(3, "b"), (7, "L")])
    m.up(1, 2)
    m.flat(6, [(3, "T")])
    m.gate(14)
    m.flat(8, [(4, "L"), (6, "K")])
    m.crumble(6)
    m.flat(10, [(4, "B"), (7, "L")])
    m.cellar_fragment(-8)
    m.cave(12)
    m.flat(4)
    m.swing(frag=True)
    m.flat(10, [(4, "L"), (6, "m")])
    m.up(2, 2)
    m.flat(10, [(5, "T")])
    m.trigger(-3, "mine_key")
    m.cave(8)
    m.flat(6, [(3, "L")])
    m.open_sky()
    m.flat(10, [(3, "d")])
    m.exit(-4)
    m.flat(3)
    return m


def canopy_run():
    m = L("canopy_run", "Canopy Run", "jungle", 34, 22, "Color(0.92, 1.0, 0.9)")
    m.flat(12, [(2, "P")])
    m.npc(-4, "itzel", "itzel_meet", "itzel_after", {"grenades": 1})
    m.swing()
    m.flat(8, [(4, "K")])
    m.up(1, 3)
    m.flat(6, [(3, "J")])
    m.down(1, 3)
    m.swing2()
    m.flat(10, [(5, "d"), (7, "d")])
    m.slab_fragment(2)
    m.trigger(-1, "canopy_tree")
    m.tree_gap(6)
    m.flat(10, [(4, "K"), (7, "g")])
    m.up(2, 2)
    m.flat(8, [(4, "J")])
    m.down(3, 2)
    m.flat(8)
    m.gap(4)
    m.flat(8, [(4, "B")])
    m.swing(frag=True)
    m.flat(10, [(4, "K")])
    m.step(2)
    m.flat(6)
    m.step(2)
    m.flat(10, [(3, "J"), (7, "m")])
    m.cellar_fragment(-6)
    m.down(2, 4)
    m.flat(8)
    m.crack()
    m.flat(8, [(4, "b")])
    m.swing2()
    m.flat(12, [(4, "K")])
    m.up(1, 2)
    m.flat(12)
    m.exit(-4)
    m.flat(3)
    return m


def sunken_temple():
    m = L("sunken_temple", "The Drowned Temple", "jungle", 34, 24, "Color(0.9, 1.0, 0.92)")
    m.cave(7)
    m.flat(12, [(2, "P"), (6, "T")])
    m.trigger(-3, "temple_enter")
    m.gap(4)
    m.flat(8, [(4, "T")])
    m.gap(4)
    m.flat(10, [(3, "K"), (6, "r")])
    m.crumble(6)
    m.flat(8, [(4, "T")])
    m.sign(-6, "The plate opens the gate, but not for long. Run!")
    m.gate(14)
    m.flat(10, [(3, "K"), (6, "d"), (8, "d")])
    m.slab_fragment(2)
    m.down(1, 2)
    m.flat(10, [(4, "T"), (7, "s")])
    m.trigger(-2, "ortiz_camp")
    m.cave(12)
    m.flat(4, [(2, "T")])
    m.swing2()
    m.flat(10, [(4, "K"), (7, "b")])
    m.cave(7)
    m.crack()
    m.flat(8, [(3, "T")])
    m.cellar_fragment(-5)
    m.crumble(5)
    m.flat(8, [(4, "m")])
    m.up(2, 2)
    m.flat(6, [(3, "T")])
    m.gate(12)
    m.flat(8, [(3, "K")])
    m.cave(12)
    m.flat(4)
    m.swing(frag=True)
    m.flat(10, [(4, "r"), (7, "T")])
    m.exit(-2)
    m.flat(3)
    return m


def idol_chamber():
    m = L("idol_chamber", "The Idol Chamber", "jungle", 34, 24, "Color(0.9, 1.0, 0.92)")
    m.cave(12)
    m.flat(10, [(2, "P"), (5, "T")])
    m.sign(-2, "The idol's armour turns bullets. Wait for its chest glyph to glow, then shoot it. Grenades work too.")
    m.trigger(-1, "idol_crane")
    m.flat(6, [(3, "g")])
    # The arena: a long hall with two low plinths to duck behind.
    m.flat(30, [(4, "T"), (8, "#"), (14, "G"), (20, "#"), (26, "T")])
    m.raw("b.boss_fight()")
    gx = m.x
    for k in range(4):
        m.put(gx, m.gy - 1 - k, "|")
    for y in range(0, m.gy - 4):
        m.put(gx, y, "#")
    m.flat(4)
    m.npc(-2, "ortiz", "idol_after", "idol_after")
    m.slab_fragment(-3)
    m.flat(6, [(3, "K")])
    # The escape: out through the collapsing halls to the sunset.
    m.crumble(6)
    m.flat(6, [(3, "T")])
    m.swing2()
    m.flat(8, [(4, "T")])
    m.cellar_fragment(-6)
    m.open_sky()
    m.up(1, 2)
    m.flat(6)
    m.swing(frag=True)
    m.flat(12)
    m.exit(-4)
    m.flat(3)
    return m


LEVELS = [(dry_gulch, 15.2), (rattler_mesa, 17.6), (bandit_mine, 21.0), (canopy_run, 5.8), (sunken_temple, 11.0),
          (idol_chamber, 17.0)]


def main():
    maps, routes, names = [], [], []
    for fn, hour in LEVELS:
        m = fn()
        text, width = m.gd_map(hour)
        maps.append(text)
        routes.append(m.gd_route())
        names.append(m.id)
        print("%-14s %4d x %d tiles  (%d route steps)" % (m.id, width, m.H, len(m.route)))
    header = "# GENERATED by tools/build_maps.py: edit the segment lists there, then rerun.\n"
    with open(os.path.join(ROOT, "scripts", "world", "campaign_maps.gd"), "w") as f:
        f.write(header + "class_name CampaignMaps\nextends RefCounted\n## The six campaign levels. Legend: see Maps.\n\n")
        f.write("const ALL := {\n" + "\n".join(maps) + "\n}\n")
    with open(os.path.join(ROOT, "scripts", "game", "campaign_routes.gd"), "w") as f:
        f.write(header + "class_name CampaignRoutes\nextends RefCounted\n## Bot routes through the campaign levels, built alongside the maps.\n\n")
        f.write("static func has(id: String) -> bool:\n\treturn id in %s\n\n\n" % gd_value(names))
        f.write("static func run(b: Bot, id: String) -> void:\n\tmatch id:\n")
        for nme in names:
            f.write('\t\t"%s":\n\t\t\t_%s(b)\n' % (nme, nme))
        f.write("\n\n" + "\n\n".join(routes))


if __name__ == "__main__":
    main()
