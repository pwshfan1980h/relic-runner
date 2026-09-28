#!/usr/bin/env python3
"""Synthesizes every Relic Runner sound effect and ambient loop (no dependencies).

Run from the project root:  python3 tools/gen_audio.py [name ...]
Writes 22.05 kHz mono 16-bit WAVs into assets/audio. Files ending in _loop are made
seamless; tools/fix_audio_imports.py marks them as looping for Godot.
DSP helpers are shared with Rocket Bus.
"""
import math
import os
import random
import struct
import sys
import wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050
TAU = math.tau


# --- DSP helpers ------------------------------------------------------------

def silence(sec):
    return [0.0] * int(sec * SR)


def mix(dst, src, at=0.0, gain=1.0):
    i0 = int(at * SR)
    end = min(len(dst), i0 + len(src))
    for i in range(max(i0, 0), end):
        dst[i] += src[i - i0] * gain
    return dst


def osc(freq, dur, wave_="sine", duty=0.5, phase=0.0):
    """freq may be a number or a function of time (seconds)."""
    n = int(dur * SR)
    out = [0.0] * n
    fn = freq if callable(freq) else None
    f = 0.0 if fn else freq
    ph = phase
    for i in range(n):
        if fn:
            f = fn(i / SR)
        ph = (ph + f / SR) % 1.0
        if wave_ == "sine":
            v = math.sin(ph * TAU)
        elif wave_ == "square":
            v = 1.0 if ph < duty else -1.0
        elif wave_ == "saw":
            v = 2.0 * ph - 1.0
        else:  # triangle
            v = 4.0 * abs(ph - 0.5) - 1.0
        out[i] = v
    return out


def noise(dur, seed=1):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(int(dur * SR))]


def brown(dur, seed=1):
    rng = random.Random(seed)
    out, v = [], 0.0
    for _ in range(int(dur * SR)):
        v = (v + rng.uniform(-1, 1) * 0.08) * 0.995
        out.append(v * 4)
    return out


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be a function of time."""
    out = [0.0] * len(x)
    y = 0.0
    fn = cutoff if callable(cutoff) else None
    a = 1 - math.exp(-TAU * (cutoff if not fn else 1000) / SR)
    for i, v in enumerate(x):
        if fn and i % 32 == 0:
            a = 1 - math.exp(-TAU * max(20.0, fn(i / SR)) / SR)
        y += a * (v - y)
        out[i] = y
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def env(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def decay(tau, attack=0.002):
    return lambda t: min(1.0, t / attack) * math.exp(-t / tau)


def gain(x, g):
    return [v * g for v in x]


def drive(x, amount):
    return [math.tanh(v * amount) / math.tanh(amount) for v in x]


def normalize(x, peak=0.9):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * peak / m for v in x]


def loopify(x, fade=0.08):
    """Crossfade the tail into the head so the sample loops without a click."""
    n = int(fade * SR)
    body = x[:len(x) - n]
    for i in range(n):
        t = i / n
        body[i] = body[i] * t + x[len(x) - n + i] * (1 - t)
    return body


def fade_out(x, sec=0.02):
    n = min(len(x), int(sec * SR))
    for i in range(n):
        x[len(x) - 1 - i] *= i / n
    return x


def echo(x, delay, fb, taps=4):
    out = x + silence(delay * taps)
    for k in range(1, taps + 1):
        mix(out, lowpass(x, 2500 / k), delay * k, fb ** k)
    return out


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def write(name, x, peak=0.9):
    x = normalize(x, peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))


# --- Revolver ---------------------------------------------------------------

def gunshot():
    out = silence(0.9)
    crack = env(lowpass(noise(0.12, 3), 4200), decay(0.018, 0.0005))
    body = env(lowpass(noise(0.3, 4), 900), decay(0.07, 0.001))
    thump = env(osc(lambda t: 90 - 40 * t, 0.2), decay(0.05))
    mix(out, drive(crack, 3.0), 0, 1.0)
    mix(out, body, 0, 0.8)
    mix(out, thump, 0, 0.9)
    # Canyon slap-back.
    tail = env(lowpass(brown(0.8, 5), 700), decay(0.25, 0.01))
    mix(out, tail, 0.03, 0.35)
    return echo(out, 0.19, 0.28, 3)


def ricochet():
    out = silence(0.45)
    mix(out, env(highpass(noise(0.02, 7), 2000), decay(0.004)), 0, 0.8)
    sweep = osc(lambda t: 3400 - 2200 * t + 120 * math.sin(t * 90), 0.4)
    mix(out, env(sweep, lambda t: min(1, t / 0.01) * math.exp(-t / 0.14)), 0.005, 0.5)
    return out


def _click(freq, seed, tau=0.012):
    c = env(highpass(noise(0.03, seed), 3000), decay(0.003, 0.0003))
    mix(c, env(osc(freq, 0.05), decay(tau)), 0, 0.5)
    return c


def empty_click():
    out = silence(0.15)
    mix(out, _click(2600, 11), 0)
    mix(out, _click(3100, 12), 0.05, 0.6)
    return out


def reload_open():
    out = silence(0.2)
    mix(out, _click(2200, 13, 0.02), 0)
    mix(out, _click(1800, 14, 0.03), 0.07, 0.8)
    return out


def reload_shell():
    out = silence(0.12)
    mix(out, _click(3600, 15, 0.025), 0)
    mix(out, env(osc(5200, 0.06), decay(0.015)), 0.002, 0.2)
    return out


def reload_spin():
    out = silence(0.45)
    for i in range(10):
        mix(out, _click(2800 + i * 60, 20 + i, 0.006), i * 0.032, 0.9 - i * 0.05)
    mix(out, _click(1900, 40, 0.04), 0.36, 1.0)
    return out


# --- Whip -------------------------------------------------------------------

def whip_throw():
    n = noise(0.2, 21)
    swoosh = lowpass(highpass(n, 400), lambda t: 900 + 9000 * t)
    return env(swoosh, lambda t: math.sin(math.pi * min(1, t / 0.2)) ** 2)


def whip_crack():
    out = silence(0.5)
    mix(out, gain(whip_throw()[:int(0.07 * SR)], 0.5), 0)
    snap = env(highpass(noise(0.03, 22), 1800), decay(0.0025, 0.0002))
    mix(out, drive(snap, 4.0), 0.07, 1.0)
    mix(out, env(lowpass(noise(0.3, 23), 3000), decay(0.05)), 0.072, 0.3)
    return echo(out, 0.14, 0.25, 3)


def whip_latch():
    out = silence(0.35)
    snap = env(highpass(noise(0.02, 24), 2000), decay(0.002, 0.0002))
    mix(out, drive(snap, 3.0), 0, 0.7)
    wrap = env(lowpass(noise(0.12, 25), 2500), lambda t: math.sin(math.pi * min(1, t / 0.12)))
    mix(out, wrap, 0.01, 0.5)
    mix(out, env(osc(1750, 0.2), decay(0.05)), 0.02, 0.35)
    mix(out, env(osc(2630, 0.2), decay(0.03)), 0.02, 0.2)
    return out


# --- Body -------------------------------------------------------------------

def step_dirt():
    grains = silence(0.07)
    rng = random.Random(31)
    for _ in range(14):
        mix(grains, env(highpass(noise(0.004, rng.randrange(999)), 1500), decay(0.0015)), rng.uniform(0, 0.04), rng.uniform(0.2, 0.6))
    mix(grains, env(lowpass(noise(0.07, 32), 600), decay(0.015)), 0, 0.8)
    return grains


def skid_dirt():
    n = bandpass(noise(0.5, 33), 500, 3500)
    rng = random.Random(34)
    flutter = [0.6 + 0.4 * rng.random() for _ in range(64)]
    return env(n, lambda t: flutter[int(t * 120) % 64] * min(1, t / 0.02) * max(0, 1 - t / 0.5))


def jump():
    return env(lowpass(noise(0.14, 35), lambda t: 800 + 3000 * t), lambda t: math.sin(math.pi * min(1, t / 0.14)))


def land():
    out = silence(0.18)
    mix(out, env(osc(lambda t: 95 - 50 * t, 0.15), decay(0.035)), 0, 1.0)
    mix(out, env(lowpass(noise(0.12, 36), 900), decay(0.03)), 0, 0.6)
    mix(out, step_dirt(), 0.005, 0.5)
    return out


def roll():
    out = silence(0.55)
    mix(out, land(), 0, 1.0)
    mix(out, env(lowpass(noise(0.35, 37), 1200), lambda t: math.sin(math.pi * min(1, t / 0.35))), 0.08, 0.4)
    mix(out, gain(land(), 0.6), 0.38)
    return out


def grab():
    out = silence(0.12)
    mix(out, env(lowpass(noise(0.05, 38), 1600), decay(0.012)), 0)
    mix(out, env(osc(140, 0.08), decay(0.02)), 0, 0.5)
    return out


def climb():
    out = silence(0.5)
    mix(out, env(lowpass(noise(0.4, 39), 1400), lambda t: math.sin(math.pi * min(1, t / 0.4))), 0, 0.5)
    mix(out, grab(), 0.05, 0.6)
    mix(out, gain(step_dirt(), 0.8), 0.42)
    return out


def hurt():
    out = silence(0.35)
    mix(out, land(), 0, 0.8)
    grunt = osc(lambda t: 130 - 60 * t, 0.25, "saw")
    grunt = bandpass(grunt, 300, 1100)
    mix(out, env(grunt, lambda t: min(1, t / 0.02) * math.exp(-t / 0.08)), 0.01, 0.9)
    return out


def hit_wood():
    out = silence(0.2)
    mix(out, env(osc(410, 0.2), decay(0.04)), 0, 0.7)
    mix(out, env(osc(655, 0.2), decay(0.025)), 0, 0.5)
    mix(out, env(lowpass(noise(0.05, 41), 2500), decay(0.008)), 0, 0.7)
    return out


def hit_straw():
    return env(lowpass(noise(0.16, 42), 2200), decay(0.04, 0.003))


def level_clear():
    out = silence(1.6)
    notes = [(60, 0.0, 0.14), (64, 0.15, 0.14), (67, 0.3, 0.14), (72, 0.45, 0.9)]
    for n, at, d in notes:
        f = midi(n + 12)
        tone = osc(lambda t, f=f: f * (1 + 0.006 * math.sin(t * 34)), d + 0.1, "square", 0.3)
        tone = lowpass(tone, 3000)
        mix(out, env(tone, lambda t, d=d: min(1, t / 0.01) * (1 if t < d else max(0, 1 - (t - d) / 0.1))), at, 0.35)
    return out


# --- Ambience ---------------------------------------------------------------

def amb_canyon_loop():
    dur = 8.0
    wind = bandpass(brown(dur, 51), 120, 900)
    wind = env(wind, lambda t: 0.55 + 0.45 * math.sin(TAU * t / dur) ** 2)
    out = gain(wind, 0.8)
    # A distant hawk.
    cry = osc(lambda t: 2200 - 900 * t + 200 * math.sin(t * 40), 0.7)
    mix(out, env(bandpass(cry, 900, 4000), lambda t: min(1, t / 0.05) * math.exp(-t / 0.3)), 3.1, 0.06)
    return loopify(out, 0.4)


def amb_jungle_loop():
    dur = 8.0
    out = gain(lowpass(brown(dur, 61), 500), 0.3)
    rng = random.Random(62)
    # Cicada bed: amplitude-modulated high tone.
    bed = osc(4800, dur)
    mix(out, env(bed, lambda t: 0.5 + 0.5 * math.sin(TAU * 38 * t)), 0, 0.03)
    # Bird calls.
    for _ in range(7):
        at = rng.uniform(0, dur - 0.6)
        base = rng.uniform(1400, 2600)
        call = osc(lambda t, b=base: b + 600 * math.sin(t * 50), 0.18)
        mix(out, env(call, decay(0.05, 0.01)), at, 0.12)
        mix(out, env(call, decay(0.05, 0.01)), at + 0.22, 0.09)
    return loopify(out, 0.4)


# --- Enemies & hazards ------------------------------------------------------

def hit_flesh():
    out = silence(0.15)
    mix(out, env(lowpass(noise(0.1, 71), 1400), decay(0.02)), 0, 0.9)
    mix(out, env(osc(lambda t: 180 - 200 * t, 0.1), decay(0.03)), 0, 0.6)
    return out


def scorpion_hiss():
    return env(bandpass(noise(0.3, 72), 3000, 8000), lambda t: min(1, t / 0.05) * max(0, 1 - t / 0.3))


def rattle():
    out = silence(0.4)
    for i in range(22):
        mix(out, env(highpass(noise(0.01, 80 + i), 3500), decay(0.004)), i * 0.016, 0.7 + 0.3 * math.sin(i))
    return out


def snake_hiss():
    return env(bandpass(noise(0.35, 73), 2500, 9000), lambda t: min(1, t / 0.02) * math.exp(-t / 0.15))


def rifle():
    out = gunshot()
    return lowpass(out, 5000)


def bandit_groan():
    g = osc(lambda t: 150 - 70 * t, 0.5, "saw")
    return env(bandpass(g, 250, 1200), lambda t: min(1, t / 0.03) * max(0, 1 - t / 0.5))


def jaguar_growl():
    base = osc(lambda t: 70 + 10 * math.sin(t * 23), 0.7, "saw")
    grit = [b * (0.6 + 0.4 * n) for b, n in zip(base, lowpass(noise(0.7, 74), 60))]
    return env(lowpass(grit, 900), lambda t: min(1, t / 0.1) * max(0, 1 - t / 0.7))


def jaguar_roar():
    base = osc(lambda t: 120 + 140 * math.sin(math.pi * min(1, t / 0.5)), 0.6, "saw")
    return env(drive(bandpass(base, 150, 1800), 2.0), lambda t: min(1, t / 0.03) * max(0, 1 - t / 0.6))


def stone_grind():
    n = lowpass(brown(0.9, 75), 500)
    rng = random.Random(76)
    out = env(n, lambda t: math.sin(math.pi * t / 0.9))
    for _ in range(12):
        mix(out, env(lowpass(noise(0.02, rng.randrange(999)), 1500), decay(0.006)), rng.uniform(0, 0.85), 0.4)
    return out


def slam():
    out = silence(1.0)
    mix(out, env(osc(lambda t: 60 - 25 * t, 0.6), decay(0.18)), 0, 1.0)
    mix(out, env(lowpass(noise(0.6, 77), 700), decay(0.12)), 0, 0.9)
    mix(out, env(lowpass(brown(0.9, 78), 400), decay(0.3)), 0.05, 0.5)
    return drive(out, 1.5)


def glyph_hit():
    out = silence(0.6)
    for f, g in ((880, 0.5), (1320, 0.35), (1760, 0.25)):
        mix(out, env(osc(f, 0.6), decay(0.18)), 0, g)
    mix(out, env(highpass(noise(0.05, 79), 2000), decay(0.01)), 0, 0.5)
    return out


def stone_crumble():
    out = silence(1.4)
    rng = random.Random(81)
    for _ in range(40):
        at = rng.uniform(0, 1.1)
        mix(out, env(lowpass(noise(0.08, rng.randrange(999)), rng.uniform(400, 1800)), decay(0.03)), at, rng.uniform(0.3, 1.0))
    mix(out, slam()[:int(0.8 * SR)], 0, 0.6)
    return out


def spike_hit():
    out = silence(0.3)
    mix(out, env(osc(2100, 0.2), decay(0.03)), 0, 0.4)
    mix(out, hit_flesh(), 0, 1.0)
    return out


def crumble_crack():
    out = silence(0.5)
    rng = random.Random(82)
    for _ in range(10):
        mix(out, env(highpass(noise(0.01, rng.randrange(999)), 1200), decay(0.005)), rng.uniform(0, 0.35), 0.6)
    mix(out, env(lowpass(noise(0.3, 83), 800), decay(0.1)), 0.3, 0.8)
    return out


def gate_rumble():
    n = lowpass(brown(0.8, 84), 300)
    out = env(n, lambda t: math.sin(math.pi * t / 0.8))
    for i in range(8):
        mix(out, _click(900 + i * 20, 90 + i, 0.02), i * 0.1, 0.3)
    return out


def plate_click():
    out = silence(0.3)
    mix(out, env(lowpass(noise(0.05, 85), 1200), decay(0.02)), 0, 0.8)
    mix(out, env(osc(320, 0.2), decay(0.05)), 0.01, 0.6)
    return out


def gate_tick():
    return _click(1500, 86, 0.01)


def checkpoint():
    out = silence(0.8)
    for n, at in ((67, 0.0), (72, 0.12)):
        tone = osc(midi(n + 12), 0.5, "triangle")
        mix(out, env(tone, decay(0.18)), at, 0.5)
    return out


def squelch():
    out = silence(0.35)
    wet = lowpass(noise(0.3, 91), lambda t: 2500 - 6000 * t)
    mix(out, env(wet, decay(0.06, 0.004)), 0, 1.0)
    mix(out, env(osc(lambda t: 220 - 300 * t, 0.2), decay(0.04)), 0.01, 0.5)
    return out


def splat():
    out = silence(0.25)
    mix(out, env(lowpass(noise(0.2, 92), 1800), decay(0.03, 0.002)), 0, 1.0)
    mix(out, env(osc(90, 0.15), decay(0.03)), 0, 0.6)
    return out


def whoosh_punch():
    return env(lowpass(highpass(noise(0.12, 101), 700), lambda t: 1500 + 9000 * t), lambda t: math.sin(math.pi * min(1, t / 0.12)))


def whoosh_kick():
    return env(lowpass(highpass(noise(0.2, 102), 300), lambda t: 900 + 5000 * t), lambda t: math.sin(math.pi * min(1, t / 0.2)))


def punch_hit():
    out = silence(0.2)
    mix(out, env(lowpass(noise(0.08, 103), 1200), decay(0.012, 0.001)), 0, 1.0)
    mix(out, env(osc(lambda t: 140 - 200 * t, 0.12), decay(0.025)), 0, 0.9)
    return drive(out, 2.0)


def kick_hit():
    out = silence(0.3)
    mix(out, env(lowpass(noise(0.12, 104), 900), decay(0.02, 0.001)), 0, 1.0)
    mix(out, env(osc(lambda t: 95 - 120 * t, 0.2), decay(0.05)), 0, 1.0)
    mix(out, env(highpass(noise(0.02, 105), 3000), decay(0.003)), 0, 0.5)
    return drive(out, 2.5)


def coin_drop():
    out = silence(0.2)
    mix(out, env(osc(3200, 0.15), decay(0.03)), 0, 0.5)
    mix(out, env(osc(4700, 0.15), decay(0.02)), 0.04, 0.35)
    return out


def item_drop():
    out = silence(0.2)
    mix(out, env(lowpass(noise(0.05, 111), 2000), decay(0.01)), 0, 0.6)
    mix(out, env(osc(700, 0.1), decay(0.02)), 0, 0.4)
    return out


def coin_pickup():
    out = silence(0.3)
    mix(out, env(osc(midi(88), 0.2, "square", 0.3), decay(0.05)), 0, 0.3)
    mix(out, env(osc(midi(95), 0.25, "square", 0.3), decay(0.08)), 0.06, 0.3)
    return lowpass(out, 5000)


def item_pickup():
    out = silence(0.6)
    for i, n in enumerate((72, 76, 79, 84)):
        mix(out, env(osc(midi(n), 0.3, "triangle"), decay(0.12)), i * 0.06, 0.4)
    return out


# --- Grenades and the intro ---------------------------------------------------

def explosion():
    out = silence(2.4)
    crack = env(lowpass(noise(0.2, 81), 5000), decay(0.03, 0.0005))
    boom = env(lowpass(noise(1.4, 82), lambda t: 1600 * math.exp(-t * 4) + 120), decay(0.35, 0.002))
    thump = env(osc(lambda t: 70 - 40 * t, 0.6), decay(0.18))
    mix(out, drive(crack, 4.0), 0, 0.9)
    mix(out, drive(boom, 2.5), 0, 1.0)
    mix(out, thump, 0, 1.0)
    # Debris pattering down afterwards.
    rng = random.Random(83)
    for i in range(26):
        at = 0.25 + rng.random() * 1.2
        mix(out, env(bandpass(noise(0.03, 90 + i), 900, 4000), decay(0.008)), at, 0.12 * (1.4 - at * 0.6))
    tail = env(lowpass(brown(2.0, 84), 400), decay(0.7, 0.05))
    mix(out, tail, 0.05, 0.5)
    return echo(out, 0.24, 0.3, 3)


def grenade_pin():
    out = silence(0.3)
    mix(out, env(highpass(noise(0.02, 91), 2500), decay(0.004)), 0, 0.7)
    mix(out, env(osc(3100, 0.2, "triangle"), decay(0.05)), 0.01, 0.3)
    mix(out, env(osc(4200, 0.2, "triangle"), decay(0.04)), 0.07, 0.25)
    return out


def grenade_bounce():
    out = silence(0.2)
    mix(out, env(bandpass(noise(0.1, 92), 300, 2200), decay(0.015)), 0, 0.9)
    mix(out, env(osc(520, 0.1, "square"), decay(0.01)), 0, 0.15)
    return out


def throw_whoosh():
    return env(bandpass(noise(0.3, 93), 400, 1800), lambda t: math.sin(min(1.0, t / 0.25) * math.pi) ** 2)


def intro_boom():
    """A low cinematic hit for title cards."""
    out = silence(3.0)
    mix(out, env(osc(lambda t: 55 - 15 * t, 3.0), decay(0.9, 0.01)), 0, 1.0)
    mix(out, env(lowpass(brown(3.0, 95), 300), decay(1.0, 0.01)), 0, 0.6)
    mix(out, env(lowpass(noise(0.3, 96), 2500), decay(0.05)), 0, 0.4)
    return echo(out, 0.35, 0.3, 3)


SFX = [
    gunshot, ricochet, empty_click, reload_open, reload_shell, reload_spin,
    whip_throw, whip_crack, whip_latch,
    step_dirt, skid_dirt, jump, land, roll, grab, climb, hurt,
    hit_wood, hit_straw, level_clear, amb_canyon_loop, amb_jungle_loop,
    hit_flesh, scorpion_hiss, rattle, snake_hiss, rifle, bandit_groan, jaguar_growl, jaguar_roar,
    stone_grind, slam, glyph_hit, stone_crumble, spike_hit, crumble_crack, gate_rumble, plate_click,
    gate_tick, checkpoint, squelch, splat, whoosh_punch, whoosh_kick, punch_hit, kick_hit,
    coin_drop, item_drop, coin_pickup, item_pickup,
    explosion, grenade_pin, grenade_bounce, throw_whoosh, intro_boom,
]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])
    for fn in SFX:
        if not only or fn.__name__ in only:
            write(fn.__name__, fn())
    print("audio written to", os.path.normpath(OUT))
