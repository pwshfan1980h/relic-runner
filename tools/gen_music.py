#!/usr/bin/env python3
"""Composes and synthesizes Relic Runner's music (no dependencies; ffmpeg or lame to encode).

Run from the project root:  python3 tools/gen_music.py [track ...]
Writes assets/music/<track>.mp3 (stereo, 32 kHz). Every track is a seamless loop:
note releases and the reverb tail that run past the end are folded back onto the start.

The aim is warm, soft "adventure film on a small budget": no raw square waves, nothing
un-filtered. Instruments:
  pad     wavetable of soft harmonics, three detuned voices, slow swell, drifting filter
  guitar  Karplus-Strong plucked nylon string (strums roll across the chord)
  marimba sine partials 1 : 3.93 : 9.2 with fast-decaying upper partials
  flute   near-sine with a touch of 2nd/3rd harmonic, breath noise, delayed vibrato
  bass    round sine + soft 2nd harmonic, plucked envelope
  bell    two inharmonic sines with long decay (mine lamps, temple glyphs)
  drums   hand drum, low tom, taiko, shaker: all synthesized, all soft-edged
"""
import math
import multiprocessing
import os
import random
import shutil
import struct
import subprocess
import sys
import wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "music")
SR = 32000
TAU = math.tau


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}
NOTE.update({"Db": 1, "Eb": 3, "Gb": 6, "Ab": 8, "Bb": 10})


def n(name):
    """'D4' -> midi."""
    return NOTE[name[:-1]] + 12 * (int(name[-1]) + 1)


def chord(root, kind="m", octave=3):
    r = n(root + str(octave))
    shape = {"m": [0, 3, 7], "M": [0, 4, 7], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10], "sus": [0, 5, 7],
             "M7": [0, 4, 7, 11], "dim": [0, 3, 6], "5": [0, 7, 12]}[kind]
    return [r + s for s in shape]


# --- Instruments ------------------------------------------------------------------

_tables = {}


def table(name):
    if name in _tables:
        return _tables[name]
    size = 2048
    if name == "pad":
        harm = [(k, 1.0 / k ** 1.6) for k in range(1, 9)]
    elif name == "bright":
        harm = [(k, 1.0 / k ** 1.1) for k in range(1, 12)]
    elif name == "flute":
        harm = [(1, 1.0), (2, 0.18), (3, 0.09), (4, 0.03)]
    else:  # sine
        harm = [(1, 1.0)]
    t = [sum(a * math.sin(TAU * k * i / size) for k, a in harm) for i in range(size)]
    peak = max(abs(v) for v in t)
    t = [v / peak for v in t]
    _tables[name] = t
    return t


def osc_table(tab, freq, count, detune=0.0, vib=0.0, vib_rate=5.0, vib_delay=0.0, phase=0.0):
    size = len(tab)
    out = [0.0] * count
    ph = phase * size
    base = freq * 2 ** (detune / 1200.0) * size / SR
    for i in range(count):
        inc = base
        if vib:
            t = i / SR
            depth = vib * min(1.0, max(0.0, (t - vib_delay) / 0.4))
            inc = base * (1.0 + depth * math.sin(TAU * vib_rate * t))
        ph += inc
        if ph >= size:
            ph -= size
        k = int(ph)
        f = ph - k
        out[i] = tab[k] + (tab[(k + 1) % size] - tab[k]) * f
    return out


def lowpass(x, cutoff):
    a = 1 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = [0.0] * len(x)
    for i, v in enumerate(x):
        y += a * (v - y)
        out[i] = y
    return out


def adsr(count, a, d, s, r, hold):
    """hold: seconds before release starts."""
    out = [0.0] * count
    ha = int(a * SR)
    hd = int(d * SR)
    hh = int(hold * SR)
    hr = max(1, int(r * SR))
    for i in range(count):
        if i < ha:
            v = i / max(1, ha)
        elif i < ha + hd:
            v = 1.0 - (1.0 - s) * (i - ha) / max(1, hd)
        else:
            v = s
        if i > hh:
            v *= max(0.0, 1.0 - (i - hh) / hr)
        out[i] = v
    return out


_cache = {}


def cached(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


def pad(m, dur, bright=False):
    def make():
        rel = 1.6
        count = int((dur + rel) * SR)
        tab = table("bright" if bright else "pad")
        f = mtof(m)
        s = [0.0] * count
        for det, ph in ((-7, 0.0), (0, 0.33), (7, 0.66)):
            o = osc_table(tab, f, count, det, vib=0.002, vib_rate=0.4 + ph, phase=ph)
            for i in range(count):
                s[i] += o[i]
        s = lowpass(s, 1400 if bright else 900)
        e = adsr(count, 0.9 if not bright else 0.04, 0.3, 0.85 if not bright else 0.5, rel, dur)
        return [s[i] * e[i] * 0.33 for i in range(count)]
    return cached(("pad", m, dur, bright), make)


def guitar(m, dur=2.5, bright=0.5):
    def make():
        f = mtof(m)
        period = SR / f
        p = int(period)
        rng = random.Random(m * 31 + int(bright * 10))
        buf = [rng.uniform(-1, 1) for _ in range(p)]
        # Soften the excitation: nylon, thumb not pick.
        for _ in range(2 if bright < 0.6 else 1):
            buf = [(buf[i] + buf[i - 1]) * 0.5 for i in range(p)]
        count = int(dur * SR)
        out = [0.0] * count
        decay = 0.9965 if f < 200 else 0.994
        idx = 0
        for i in range(count):
            a = buf[idx]
            b = buf[(idx + 1) % p]
            v = (a + b) * 0.5 * decay
            buf[idx] = v
            out[i] = a
            idx = (idx + 1) % p
        out = lowpass(out, 2600 + bright * 2000)
        fade = int(0.05 * SR)
        for i in range(fade):
            out[count - 1 - i] *= i / fade
        return [v * 0.6 for v in out]
    return cached(("gtr", m, dur, bright), make)


def marimba(m, dur=1.2):
    def make():
        f = mtof(m)
        count = int(dur * SR)
        out = [0.0] * count
        for mult, amp, tau in ((1.0, 1.0, 0.45), (3.93, 0.28, 0.08), (9.2, 0.08, 0.025)):
            w = TAU * f * mult / SR
            for i in range(count):
                out[i] += amp * math.sin(w * i) * math.exp(-i / (tau * SR))
        att = int(0.003 * SR)
        for i in range(att):
            out[i] *= i / att
        return [v * 0.45 for v in out]
    return cached(("mar", m, dur), make)


def flute(m, dur):
    def make():
        rel = 0.35
        count = int((dur + rel) * SR)
        o = osc_table(table("flute"), mtof(m), count, vib=0.006, vib_rate=5.2, vib_delay=0.25)
        rng = random.Random(m)
        breath = lowpass([rng.uniform(-1, 1) for _ in range(count)], 1800)
        e = adsr(count, 0.08, 0.2, 0.8, rel, dur)
        return [(o[i] + breath[i] * 0.35) * e[i] * 0.3 for i in range(count)]
    return cached(("fl", m, dur), make)


def bass(m, dur):
    def make():
        count = int((dur + 0.2) * SR)
        f = mtof(m)
        out = [0.0] * count
        w = TAU * f / SR
        for i in range(count):
            out[i] = math.sin(w * i) + 0.25 * math.sin(2 * w * i)
        e = adsr(count, 0.01, 0.4, 0.55, 0.2, dur)
        return [out[i] * e[i] * 0.55 for i in range(count)]
    return cached(("bass", m, dur), make)


def bell(m, dur=3.0):
    def make():
        f = mtof(m)
        count = int(dur * SR)
        out = [0.0] * count
        for mult, amp, tau in ((1.0, 1.0, 1.2), (2.76, 0.4, 0.5), (5.4, 0.15, 0.2)):
            w = TAU * f * mult / SR
            for i in range(count):
                out[i] += amp * math.sin(w * i) * math.exp(-i / (tau * SR))
        att = int(0.004 * SR)
        for i in range(att):
            out[i] *= i / att
        return [v * 0.22 for v in out]
    return cached(("bell", m, dur), make)


def drum(kind):
    def make():
        rng = random.Random(hash(kind) & 0xFFFF)
        if kind == "hand":
            count = int(0.35 * SR)
            out = [math.sin(TAU * (190 - 60 * min(1, i / (0.04 * SR))) * i / SR) * math.exp(-i / (0.07 * SR)) for i in range(count)]
            nz = lowpass([rng.uniform(-1, 1) * math.exp(-i / (0.01 * SR)) for i in range(count)], 3000)
            return [(out[i] + nz[i] * 0.4) * 0.5 for i in range(count)]
        if kind == "slap":
            count = int(0.25 * SR)
            out = [math.sin(TAU * 330 * i / SR) * math.exp(-i / (0.03 * SR)) for i in range(count)]
            nz = lowpass([rng.uniform(-1, 1) * math.exp(-i / (0.015 * SR)) for i in range(count)], 4500)
            return [(out[i] * 0.6 + nz[i] * 0.6) * 0.4 for i in range(count)]
        if kind == "tom":
            count = int(0.8 * SR)
            ph = 0.0
            out = []
            for i in range(count):
                f = 70 + 50 * math.exp(-i / (0.05 * SR))
                ph += TAU * f / SR
                out.append(math.sin(ph) * math.exp(-i / (0.22 * SR)))
            return [v * 0.8 for v in out]
        if kind == "taiko":
            count = int(1.4 * SR)
            ph = 0.0
            out = []
            for i in range(count):
                f = 48 + 40 * math.exp(-i / (0.06 * SR))
                ph += TAU * f / SR
                out.append(math.sin(ph) * math.exp(-i / (0.4 * SR)))
            nz = lowpass([rng.uniform(-1, 1) * math.exp(-i / (0.03 * SR)) for i in range(count)], 900)
            return [(out[i] + nz[i] * 0.5) * 0.9 for i in range(count)]
        if kind == "shaker":
            count = int(0.12 * SR)
            nz = [rng.uniform(-1, 1) for _ in range(count)]
            lp = lowpass(nz, 6000)
            hp = [a - b for a, b in zip(lp, lowpass(lp, 2200))]  # band: 2.2-6 kHz
            return [hp[i] * math.sin(math.pi * i / count) ** 2 * 0.35 for i in range(count)]
        if kind == "drip":
            count = int(0.4 * SR)
            ph = 0.0
            out = []
            for i in range(count):
                f = 1400 + 900 * (1 - math.exp(-i / (0.02 * SR)))
                ph += TAU * f / SR
                out.append(math.sin(ph) * math.exp(-i / (0.05 * SR)))
            return [v * 0.18 for v in out]
        raise ValueError(kind)
    return cached(("drum", kind), make)


# --- Mixer ------------------------------------------------------------------------

class Track:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = bars * beats_per_bar * self.beat
        self.count = int(self.length * SR)
        self.L = [0.0] * self.count
        self.R = [0.0] * self.count
        self.send = [0.0] * self.count  # reverb send (mono)
        self.rng = random.Random(bpm * 7 + bars)

    def add(self, sig, at_beat, gain=1.0, pan=0.0, verb=0.3, humanize=0.008):
        start = int((at_beat * self.beat + self.rng.uniform(0, humanize)) * SR)
        gl = gain * math.cos((pan + 1) * math.pi / 4) * 1.4142
        gr = gain * math.sin((pan + 1) * math.pi / 4) * 1.4142
        L, R, S, c = self.L, self.R, self.send, self.count
        for i, v in enumerate(sig):
            j = (start + i) % c  # wrap: seamless loop
            L[j] += v * gl
            R[j] += v * gr
            S[j] += v * gain * verb

    def render(self, name, level=1.0):
        wet_l, wet_r = reverb(self.send)
        L = [self.L[i] + wet_l[i] for i in range(self.count)]
        R = [self.R[i] + wet_r[i] for i in range(self.count)]
        # Master: gentle high cut, soft saturation, normalise to about -1 dB.
        L = lowpass(L, 9000)
        R = lowpass(R, 9000)
        peak = max(max(abs(v) for v in L), max(abs(v) for v in R), 1e-9)
        drive = 1.3
        L = [math.tanh(v / peak * drive) / math.tanh(drive) * 0.89 * level for v in L]
        R = [math.tanh(v / peak * drive) / math.tanh(drive) * 0.89 * level for v in R]
        write(name, L, R)


def reverb(send, decay=0.84):
    """Stereo Schroeder-style reverb at half rate (cheaper, softer), looped so the tail
    wraps onto the start. Returns full-rate L and R."""
    half = send[::2]
    n_ = len(half)
    sr2 = SR / 2
    combs_l = [int(sr2 * t) for t in (0.0297, 0.0371, 0.0411, 0.0437)]
    combs_r = [int(sr2 * t) for t in (0.0301, 0.0359, 0.0423, 0.0449)]
    aps = [int(sr2 * t) for t in (0.005, 0.0017)]

    def side(combs):
        out = [0.0] * n_
        for d in combs:
            buf = [0.0] * d
            idx = 0
            lp = 0.0
            # Two passes around the loop so the tail from the end feeds the start.
            for _pass in range(2):
                for i in range(n_):
                    y = buf[idx]
                    lp = y * 0.6 + lp * 0.4  # damping: highs die first
                    buf[idx] = half[i] + lp * decay
                    idx = (idx + 1) % d
                    if _pass == 1:
                        out[i] += y
        for d in aps:
            buf = [0.0] * d
            idx = 0
            res = [0.0] * n_
            for i in range(n_):
                b = buf[idx]
                x = out[i]
                y = -x * 0.5 + b
                buf[idx] = x + b * 0.5
                res[i] = y
                idx = (idx + 1) % d
            out = res
        return out

    wl, wr = side(combs_l), side(combs_r)
    full_l = [0.0] * len(send)
    full_r = [0.0] * len(send)
    for i in range(len(send)):
        k = i // 2
        k2 = (k + 1) % n_
        f = (i % 2) * 0.5
        full_l[i] = (wl[k] + (wl[k2] - wl[k]) * f) * 0.28
        full_r[i] = (wr[k] + (wr[k2] - wr[k]) * f) * 0.28
    return full_l, full_r


def write(name, L, R):
    tmp = os.path.join(OUT, name + ".tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for a, b in zip(L, R):
            frames += struct.pack("<hh", int(max(-1, min(1, a)) * 32767), int(max(-1, min(1, b)) * 32767))
        w.writeframes(bytes(frames))
    mp3 = os.path.join(OUT, name + ".mp3")
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-b:a", "96k", mp3], check=True)
    else:
        subprocess.run(["lame", "--quiet", "-b", "96", tmp, mp3], check=True)
    os.remove(tmp)
    print("wrote", name, "%.1fs" % (len(L) / SR))


# --- Composition helpers ------------------------------------------------------------

def pads(t, chords, beats_each, gain=0.5, bright=False, pan=0.0):
    for i, ch in enumerate(chords):
        for k, m in enumerate(ch):
            t.add(pad(m, beats_each * t.beat * 0.98, bright), i * beats_each, gain, pan + (k - 1) * 0.25, verb=0.5)


def strum(t, notes, at, gain=0.45, spread=0.018, pan=0.1, bright=0.5, dur=2.5):
    for k, m in enumerate(notes):
        t.add(guitar(m, dur, bright), at + k * spread / t.beat, gain * (0.85 + 0.15 * k / len(notes)), pan, verb=0.25)


def melody(t, notes, start, inst="flute", gain=0.5, pan=-0.15, verb=0.45):
    """notes: [(beat offset, midi or None, dur beats)]"""
    for off, m, d in notes:
        if m is None:
            continue
        sig = flute(m, d * t.beat) if inst == "flute" else (marimba(m) if inst == "marimba" else bell(m))
        t.add(sig, start + off, gain, pan, verb)


def seq(pattern, step=0.5):
    """'D5 . A4 - F5' -> [(beat, midi, dur)]: '.' rest, '-' holds the previous note."""
    out = []
    for i, tok in enumerate(pattern.split()):
        if tok == ".":
            continue
        if tok == "-":
            if out:
                b, m, d = out[-1]
                out[-1] = (b, m, d + step)
            continue
        out.append((i * step, n(tok), step))
    return out


# --- Tracks -------------------------------------------------------------------------

def title():
    t = Track(84, 16)
    prog = [chord("D", "m"), chord("A#", "M", 2), chord("F", "M"), chord("C", "M"),
            chord("D", "m"), chord("A#", "M", 2), chord("G", "m", 2), chord("A", "M", 2)]
    pads(t, prog, 8, 0.45)
    for i, ch in enumerate(prog):
        root = ch[0] - 12
        t.add(bass(root, t.beat * 3.5), i * 8, 0.55, 0, verb=0.1)
        t.add(bass(root, t.beat * 3.5), i * 8 + 4, 0.45, 0, verb=0.1)
        arp = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 24]
        for k in range(16):
            t.add(guitar(arp[k % 4], 1.6, 0.4), i * 8 + k * 0.5, 0.26 if k % 4 else 0.34, 0.35, verb=0.35)
        t.add(drum("tom"), i * 8, 0.5, -0.1, verb=0.3)
        t.add(drum("tom"), i * 8 + 4, 0.3, -0.1, verb=0.3)
        if i >= 2:
            for k in range(16):
                t.add(drum("shaker"), i * 8 + k * 0.5, 0.35 if k % 2 else 0.2, 0.4, verb=0.1)
    # The theme: a rising call, an answer, then home.
    theme = seq("D5 - - A4 D5 E5 F5 - - - E5 - D5 - C5 - "
                "A4 - - - . . . . A#4 - C5 - D5 - C5 - "
                "A4 - G4 - F4 - - - E4 - F4 - G4 - A4 - "
                "D5 - - - - - - - . . . . . . . .")
    melody(t, theme, 32, gain=0.5)
    return t


def intro():
    t = Track(60, 7)
    prog = [chord("D", "m", 2), chord("A#", "M", 2), chord("G", "m", 2), chord("A", "sus", 2), chord("A", "M", 2),
            chord("D", "m", 2), chord("D", "m", 2)]
    pads(t, prog, 4, 0.55)
    for i in range(7):
        t.add(bass(prog[i][0] - 12, t.beat * 3.8), i * 4, 0.5, 0, verb=0.2)
    for b, m in ((2, "A5"), (6, "F5"), (10, "D5"), (14, "E5"), (18, "C#6")):
        t.add(bell(n(m), 4.0), b, 0.5, 0.3, verb=0.7)
    # Taiko roll building into the title slam (about 23s in).
    for k in range(16):
        t.add(drum("taiko"), 17 + k * 0.25, 0.1 + k * 0.035, 0.0, verb=0.3)
    t.add(drum("taiko"), 21.5, 1.0, 0, verb=0.6)
    melody(t, seq("D5 - - - A4 - D5 E5 F5 - - - - - - -"), 21.5, gain=0.55)
    return t


def canyon():
    t = Track(92, 16)
    prog = [chord("E", "M"), chord("F", "M"), chord("E", "M"), chord("D", "m")]
    for bar in range(16):
        ch = prog[(bar // 2) % 4]
        voicing = [ch[0] - 12, ch[0], ch[1], ch[2], ch[0] + 12]
        strum(t, voicing, bar * 4, 0.36, pan=0.25)
        strum(t, voicing[1:], bar * 4 + 1.5, 0.22, pan=0.25, spread=0.012)
        strum(t, voicing[1:], bar * 4 + 2.5, 0.28, pan=0.25)
        t.add(bass(ch[0] - 12, t.beat * 1.8), bar * 4, 0.45, 0, verb=0.1)
        t.add(bass(ch[0] - 5, t.beat * 1.8), bar * 4 + 2, 0.35, 0, verb=0.1)
        for k in range(8):
            t.add(drum("shaker"), bar * 4 + k * 0.5 + (0.08 if k % 2 else 0), 0.3 if k % 2 else 0.18, 0.5, verb=0.1)
        t.add(drum("hand"), bar * 4, 0.45, -0.3, verb=0.2)
        t.add(drum("slap"), bar * 4 + 1.5, 0.3, -0.3, verb=0.2)
        t.add(drum("hand"), bar * 4 + 2.5, 0.35, -0.3, verb=0.2)
    pads(t, [[c - 12 for c in prog[(i // 2) % 4]] for i in range(16)], 4, 0.18)
    tune = seq("B4 - - C5 B4 - G#4 - A4 - B4 - - - . . "
               "E5 - - D5 C5 - B4 - A4 - G#4 - F4 - E4 - "
               "E4 - F4 G#4 A4 - B4 - C5 - B4 - A4 - G#4 - "
               "E4 - - - - - - - . . . . . . . .")
    melody(t, tune, 32, gain=0.42)
    return t


def mesa():
    t = Track(76, 16)
    prog = [chord("A", "m"), chord("F", "M"), chord("C", "M"), chord("G", "M", 2),
            chord("A", "m"), chord("F", "M"), chord("E", "M", 2), chord("E", "M", 2)]
    pads(t, prog, 8, 0.35)
    for i, ch in enumerate(prog):
        pat = [ch[0], ch[2], ch[1] + 12, ch[2], ch[0] + 12, ch[2], ch[1] + 12, ch[2]]
        for k in range(16):
            t.add(guitar(pat[k % 8], 2.0, 0.35), i * 8 + k * 0.5, 0.3 if k % 4 == 0 else 0.2, 0.3, verb=0.4)
        t.add(bass(ch[0] - 12, t.beat * 7.5), i * 8, 0.45, 0, verb=0.15)
        t.add(drum("tom"), i * 8, 0.25, -0.2, verb=0.5)
    melody(t, seq("E5 - - - - - D5 - C5 - - - B4 - A4 - "
                  "C5 - - - - - B4 - A4 - - - G4 - E4 - "
                  "A4 - - - C5 - - - E5 - - - D5 - C5 - "
                  "B4 - - - - - - - G#4 - - - - - - -", 1.0), 32, gain=0.4, verb=0.6)
    return t


def mine():
    t = Track(66, 12)
    prog = [[n("D2"), n("A2"), n("D3")], [n("D2"), n("A2"), n("D#3")], [n("D2"), n("A2"), n("F3")], [n("C2"), n("G2"), n("D#3")]]
    pads(t, [prog[i % 4] for i in range(12)], 4, 0.55)
    for bar in range(12):
        t.add(drum("tom"), bar * 4, 0.55, 0, verb=0.4)
        t.add(drum("tom"), bar * 4 + 0.6, 0.35, 0, verb=0.4)
        t.add(bass(n("D2"), t.beat * 3.5), bar * 4, 0.3, 0, verb=0.2)
    rng = random.Random(7)
    pent = [n(x) for x in ("D5", "F5", "G5", "A5", "C6", "D6")]
    for k in range(18):
        t.add(bell(rng.choice(pent), 3.0), rng.uniform(0, 46), rng.uniform(0.2, 0.45), rng.uniform(-0.8, 0.8), verb=0.8)
    for k in range(24):
        t.add(drum("drip"), rng.uniform(0, 47), rng.uniform(0.3, 0.7), rng.uniform(-0.9, 0.9), verb=0.7)
    melody(t, seq("A4 - - - - - A#4 - A4 - - - F4 - - - - - - - - - - - D4 - - - - - - -", 1.0), 16, gain=0.28, verb=0.7)
    return t


def jungle():
    t = Track(104, 16)
    prog = [chord("G", "m7"), chord("C", "7"), chord("G", "m7"), chord("F", "M")]
    pads(t, [prog[(i // 2) % 4] for i in range(16)], 4, 0.22)
    riff = [0, 2, 1, 3, 2, 1, 0, 2]
    for bar in range(16):
        ch = prog[(bar // 2) % 4]
        tones = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]
        for k in range(8):
            t.add(marimba(tones[riff[k] % len(tones)]), bar * 4 + k * 0.5, 0.35 if k % 2 == 0 else 0.25, 0.3, verb=0.3)
        t.add(bass(ch[0] - 12, t.beat * 1.4), bar * 4, 0.45, 0, verb=0.1)
        t.add(bass(ch[0] - 12, t.beat * 0.8), bar * 4 + 1.5, 0.35, 0, verb=0.1)
        t.add(bass(ch[0] - 5, t.beat * 1.4), bar * 4 + 2.5, 0.35, 0, verb=0.1)
        for k, (b, kind, g) in enumerate([(0, "hand", 0.4), (1, "slap", 0.3), (1.75, "hand", 0.25), (2.5, "hand", 0.35), (3, "slap", 0.3), (3.5, "hand", 0.2)]):
            t.add(drum(kind), bar * 4 + b, g, -0.35, verb=0.25)
        for k in range(16):
            t.add(drum("shaker"), bar * 4 + k * 0.25, 0.18 if k % 2 else 0.1, 0.55, verb=0.1)
    # Bird-like calls on the flute.
    for start in (16, 40, 48):
        melody(t, seq("D6 A#5 D6 . . . . . F6 - D6 - . . . .", 0.25), start, gain=0.3, pan=-0.5, verb=0.6)
    melody(t, seq("G5 - - - F5 - D5 - C5 - A#4 - C5 - - - D5 - - - - - - - . . . . . . . .", 0.5), 32, gain=0.38)
    return t


def temple():
    t = Track(70, 12)
    prog = [chord("C", "m", 2), chord("G#", "M", 1), chord("F", "m", 2), chord("G", "M", 2)]
    pads(t, [prog[(i // 3) % 4] for i in range(12)], 4, 0.5)
    for bar in range(12):
        t.add(drum("taiko"), bar * 4, 0.6 if bar % 2 == 0 else 0.4, 0, verb=0.5)
        t.add(drum("tom"), bar * 4 + 3, 0.25, 0.2, verb=0.5)
    motif = seq("G5 . D#5 . C5 - . . B4 . C5 . D#5 - - -", 0.5)
    for s in (8, 24, 40):
        melody(t, motif, s, inst="bell", gain=0.55, pan=0.3, verb=0.8)
    for bar in range(12):
        ch = prog[(bar // 3) % 4]
        for k in range(4):
            t.add(marimba(ch[k % 3] + 12, 1.5), bar * 4 + k, 0.18, -0.3, verb=0.5)
    return t


def boss():
    t = Track(128, 16)
    prog = [chord("D", "m", 2), chord("D", "m", 2), chord("A#", "M", 1), chord("C", "M", 2)]
    line = ["D2", "D2", "F2", "D2", "G2", "D2", "F2", "E2"]
    for bar in range(16):
        ch = prog[bar % 4]
        shift = ch[0] - n("D2") if bar % 4 >= 2 else 0
        for k in range(8):
            t.add(bass(n(line[k]) + shift, t.beat * 0.45), bar * 4 + k * 0.5, 0.5, 0, verb=0.05)
        for k in range(8):
            kind = "taiko" if k in (0, 3, 6) else "tom"
            t.add(drum(kind), bar * 4 + k * 0.5, 0.55 if kind == "taiko" else 0.22, -0.1 if k % 2 else 0.1, verb=0.25)
        for off in (0.5, 1.5, 2.5, 3.5):
            for m in ch:
                t.add(pad(m + 12, t.beat * 0.4, True), bar * 4 + off, 0.2, 0.25, verb=0.3)
        for k in range(8):
            t.add(drum("shaker"), bar * 4 + k * 0.5 + 0.25, 0.25, 0.5, verb=0.1)
    theme = seq("D5 - - A4 D5 E5 F5 - E5 - D5 - C5 - A4 - "
                "A#4 - - - A4 - G4 - A4 - - - - - - - ")
    melody(t, theme, 32, gain=0.5)
    melody(t, theme, 48, gain=0.55)
    return t


def camp():
    t = Track(72, 16)
    prog = [chord("G", "M", 2), chord("E", "m", 2), chord("C", "M", 2), chord("D", "M", 2)]
    pads(t, [prog[(i // 2) % 4] for i in range(16)], 4, 0.25)
    pattern = [0, 2, 1, 2, 3, 2, 1, 2]
    for bar in range(16):
        ch = prog[(bar // 2) % 4]
        tones = [ch[0], ch[1] + 12, ch[2] + 12, ch[0] + 24]
        for k in range(8):
            t.add(guitar(tones[pattern[k]], 2.2, 0.3), bar * 4 + k * 0.5, 0.32 if k == 0 else 0.22, 0.2, verb=0.4)
        t.add(bass(ch[0] - 12, t.beat * 3.8), bar * 4, 0.35, 0, verb=0.2)
    melody(t, seq("B4 - - - A4 - G4 - E4 - - - D4 - - - "
                  "G4 - A4 - B4 - D5 - B4 - - - A4 - - - ", 1.0), 32, gain=0.3, verb=0.6)
    return t


TRACKS = {"title": title, "intro": intro, "canyon": canyon, "mesa": mesa, "mine": mine, "jungle": jungle,
          "temple": temple, "boss": boss, "camp": camp}


## Ambient cues sit lower than the themes.
LEVEL = {"mine": 0.6, "temple": 0.75, "camp": 0.7, "mesa": 0.85, "jungle": 0.9}


def _render(name):
    random.seed(hash(name) & 0xFFFF)
    TRACKS[name]().render(name, LEVEL.get(name, 1.0))
    return name


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(TRACKS)
    with multiprocessing.Pool(min(len(names), os.cpu_count() or 2)) as pool:
        for done in pool.imap_unordered(_render, names):
            pass
