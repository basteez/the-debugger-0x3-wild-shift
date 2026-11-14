#!/usr/bin/env python3
"""Generates every one-shot SFX of the game (Story 7.2, FR63, FR28, GFR32, GFR64, D-S72-1).

Replaces gen_shift_sfx.py (Story 2.4). One table of clip recipes (CLIPS), one main() writing them.

Output: game/assets/audio/sfx/<name>.wav, 16-bit mono PCM, 22050 Hz, imported by Godot as
AudioStreamWAV (compress mode Disabled, so AudioStreamWAV.data stays 16-bit PCM). Every clip is
scaled to its own peak (always <= PEAK_MAX of full scale), starts from silence and ends with a
linear fade to zero, so nothing clicks.

The sounds are synthesised by this project's own code (square / triangle / sine oscillators,
pitch slides, envelopes, LFSR noise), so they are CC0 by construction.

Run from anywhere (standard library only, no packages, no encoder):
    python3 game/tools/gen_sfx.py               # writes into game/assets/audio/sfx/
    python3 game/tools/gen_sfx.py --out DIR     # writes into DIR (determinism check)
The output is deterministic: no `random`, fixed constants, a fixed-seed LFSR for noise. Running it
twice gives byte-identical files. To change a sound, edit its recipe here and regenerate (H-S72-2).
"""

import argparse
import math
import os
import struct
import wave

MIX_RATE = 22050
## Story 7.2 AC 2 / D-S72-8: no clip peaks above this fraction of full scale.
PEAK_MAX = 0.8
## Short ramp-in so a clip never starts on a non-zero sample.
ATTACK_RAMP_S = 0.0008
## Every clip ends with a linear fade to zero over this long (or less for very short clips).
FADE_OUT_S = 0.012
DEFAULT_OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")
TAU = 2.0 * math.pi


# --- building blocks ---------------------------------------------------------------------------


def n_frames(seconds: float) -> int:
    return max(1, int(round(seconds * MIX_RATE)))


class Lfsr:
    """15-bit Galois LFSR (taps 0x6000, NES-style) with a fixed seed: deterministic white noise."""

    def __init__(self, seed: int = 0x4A5D) -> None:
        self.state = seed & 0x7FFF or 1

    def next(self) -> float:
        bit = ((self.state >> 0) ^ (self.state >> 1)) & 1
        self.state = (self.state >> 1) | (bit << 14)
        return 1.0 if self.state & 1 else -1.0


def osc(wave_kind: str, phase: float, duty: float = 0.5) -> float:
    """One sample of a waveform at `phase` (cycles, any value)."""
    p = phase % 1.0
    if wave_kind == "square":
        return 1.0 if p < duty else -1.0
    if wave_kind == "triangle":
        return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p
    if wave_kind == "saw":
        return 2.0 * p - 1.0
    return math.sin(TAU * p)


def tone(seconds, f0, f1=None, wave_kind="square", duty=0.5, curve=1.0, vibrato_hz=0.0,
         vibrato_depth=0.0, attack=0.002, decay_pow=1.0, sustain=0.0):
    """Pitch slide f0 -> f1 (curve > 1 bends late, < 1 early), envelope: linear attack then a
    decay from 1 to `sustain` shaped by decay_pow. Returns a list of floats in [-1, 1]."""
    f1 = f0 if f1 is None else f1
    count = n_frames(seconds)
    att = max(1, n_frames(attack))
    out = []
    phase = 0.0
    for i in range(count):
        t = i / count
        freq = f0 + (f1 - f0) * (t ** curve)
        if vibrato_hz > 0.0:
            freq *= 1.0 + vibrato_depth * math.sin(TAU * vibrato_hz * i / MIX_RATE)
        phase += freq / MIX_RATE
        if i < att:
            env = i / att
        else:
            env = sustain + (1.0 - sustain) * (1.0 - (i - att) / max(count - att, 1)) ** decay_pow
        out.append(osc(wave_kind, phase, duty) * env)
    return out


def noise(seconds, hold_hz=MIX_RATE, seed=0x4A5D, attack=0.001, decay_pow=1.0, lowpass=1.0,
          hold_hz_end=None):
    """LFSR noise. `hold_hz` is the sample-and-hold rate (lower = grittier, more 8-bit), sliding
    to hold_hz_end; `lowpass` is a one-pole coefficient in (0, 1] (1 = no filter)."""
    hold_hz_end = hold_hz if hold_hz_end is None else hold_hz_end
    gen = Lfsr(seed)
    count = n_frames(seconds)
    att = max(1, n_frames(attack))
    out = []
    held = gen.next()
    acc = 0.0
    filtered = 0.0
    for i in range(count):
        t = i / count
        rate = hold_hz + (hold_hz_end - hold_hz) * t
        acc += rate / MIX_RATE
        while acc >= 1.0:
            acc -= 1.0
            held = gen.next()
        filtered += lowpass * (held - filtered)
        env = i / att if i < att else (1.0 - (i - att) / max(count - att, 1)) ** decay_pow
        out.append(filtered * env)
    return out


def silence(seconds):
    return [0.0] * n_frames(seconds)


def mix(*parts):
    """Sums (signal, gain) pairs, padding the shorter ones with silence."""
    length = max(len(sig) for sig, _ in parts)
    out = [0.0] * length
    for sig, gain in parts:
        for i, v in enumerate(sig):
            out[i] += v * gain
    return out


def cat(*parts):
    out = []
    for sig in parts:
        out.extend(sig)
    return out


def gate(sig, period_s, duty):
    """Chops `sig` on/off (stutter): on for `duty` of every period (glitch sounds)."""
    period = max(2, n_frames(period_s))
    on = int(period * duty)
    return [v if (i % period) < on else 0.0 for i, v in enumerate(sig)]


def crush(sig, step):
    """Sample-rate reduction: holds every `step`-th sample (8-bit grit)."""
    return [sig[i - i % step] for i in range(len(sig))]


def stutter(sig, chunk_s, repeats):
    """Repeats the first `chunk_s` of `sig` `repeats` times, then plays the rest (a looping glitch)."""
    chunk = sig[: n_frames(chunk_s)]
    return cat(*([chunk] * repeats), sig[len(chunk):])


def finish(sig, peak):
    """Ramp in, fade out to exactly zero, then scale so max |sample| == peak (<= PEAK_MAX)."""
    assert 0.0 < peak <= PEAK_MAX, peak
    sig = list(sig)
    count = len(sig)
    ramp = min(n_frames(ATTACK_RAMP_S), count // 4)
    for i in range(ramp):
        sig[i] *= i / ramp
    fade = min(n_frames(FADE_OUT_S), count // 3)
    for k in range(fade):
        sig[count - fade + k] *= 1.0 - (k + 1) / fade
    top = max(abs(v) for v in sig) or 1.0
    return [v * peak / top for v in sig]


def to_pcm16(sig) -> bytes:
    return b"".join(struct.pack("<h", max(-32767, min(32767, int(round(v * 32767.0))))) for v in sig)


# --- recipes (D-S72-2, D-S72-7 lengths) --------------------------------------------------------
# Each recipe returns a finished signal. Names are final (a re-export is a file swap, not code).


def shift_left():
    # `<<`: a low, falling "tock" (wide square, sweep down) with a dark click on the front.
    body = tone(0.050, 1250.0, 620.0, "square", duty=0.5, curve=0.6, decay_pow=1.4)
    click = noise(0.006, hold_hz=6000, seed=0x1111, lowpass=0.5, decay_pow=2.0)
    return finish(mix((body, 0.7), (click, 0.5)), 0.6)


def shift_right():
    # `>>`: a higher, rising "tick" (thin pulse, sweep up) with a bright click: the mirror of `<<`,
    # distinct in pitch, direction and timbre so the two can be told apart by ear.
    body = tone(0.050, 820.0, 1650.0, "square", duty=0.2, curve=0.6, decay_pow=1.4)
    click = noise(0.006, hold_hz=MIX_RATE, seed=0x2222, decay_pow=2.0)
    return finish(mix((body, 0.7), (click, 0.5)), 0.6)


def hit():
    # Landed hit (BASE): a noise smack on top of a fast square pitch drop. Punchy, mid.
    smack = noise(0.045, hold_hz=11000, hold_hz_end=3000, seed=0x0BAD, decay_pow=2.2)
    body = tone(0.090, 520.0, 130.0, "square", duty=0.4, curve=0.5, decay_pow=1.6)
    return finish(mix((smack, 0.8), (body, 0.6)), 0.75)


def hit_resisted():
    # Resisted hit (UNPATCHED): a dull, muffled low clunk; no bright noise, the hit "bounces off".
    body = tone(0.110, 150.0, 70.0, "triangle", curve=0.7, decay_pow=1.8)
    knock = noise(0.030, hold_hz=1800, seed=0x0DED, lowpass=0.15, decay_pow=2.0)
    sub = tone(0.110, 95.0, 55.0, "sine", decay_pow=1.5)
    return finish(mix((body, 0.8), (knock, 0.7), (sub, 0.5)), 0.7)


def patched_chime():
    # Patched applied: a bright rising three-note arpeggio (E6, B6, E7) with a ringing tail.
    notes = [1318.5, 1975.5, 2637.0]
    parts = [tone(0.055, f, None, "square", duty=0.25, decay_pow=0.8, sustain=0.25) for f in notes[:2]]
    tail = tone(0.200, notes[2], None, "square", duty=0.25, decay_pow=1.6, vibrato_hz=7.0, vibrato_depth=0.004)
    shimmer = tone(0.310, 2637.0 * 2.0, None, "triangle", decay_pow=2.5)
    return finish(mix((cat(*parts, tail), 0.75), (shimmer, 0.15)), 0.6)


def duck_squeak():
    # Rubber duck: a quick up-then-down squeak with wobble (two triangle slides).
    up = tone(0.055, 950.0, 1750.0, "triangle", curve=0.5, decay_pow=0.3, sustain=0.6, vibrato_hz=38.0, vibrato_depth=0.05)
    down = tone(0.085, 1750.0, 1150.0, "triangle", curve=1.2, decay_pow=1.4, vibrato_hz=38.0, vibrato_depth=0.05)
    reed = tone(0.140, 1900.0, 1500.0, "square", duty=0.12, decay_pow=1.2)
    return finish(mix((cat(up, down), 0.8), (reed, 0.12)), 0.6)


def tell_infinite_loop():
    # Infinite Loop tell: a fast spinning trill between two notes that repeats (it loops).
    notes = [523.25, 784.0]
    steps = []
    for k in range(8):
        steps.append(tone(0.032, notes[k % 2], None, "square", duty=0.5, decay_pow=0.5, sustain=0.5))
    sig = cat(*steps)
    env = [v * (1.0 - 0.5 * i / len(sig)) for i, v in enumerate(sig)]
    return finish(env, 0.6)


def tell_null_pointer():
    # Null Pointer tell: a hollow "void" drop, a sine falling into nothing with a tremolo flutter.
    body = tone(0.280, 980.0, 220.0, "sine", curve=0.7, decay_pow=1.0, vibrato_hz=18.0, vibrato_depth=0.03)
    ghost = tone(0.280, 1960.0, 440.0, "triangle", curve=0.7, decay_pow=1.4)
    sig = mix((body, 0.8), (ghost, 0.3))
    trem = [v * (0.6 + 0.4 * math.cos(TAU * 14.0 * i / MIX_RATE)) for i, v in enumerate(sig)]
    return finish(trem, 0.65)


def tell_segfault():
    # Segfault tell = the SIGSEGV alarm (D-S72-3): a harsh two-tone klaxon, square, fast alternation.
    steps = []
    for k in range(7):
        f = 1480.0 if k % 2 == 0 else 1046.5
        steps.append(tone(0.040, f, None, "square", duty=0.5, decay_pow=0.2, sustain=0.85))
    buzz = noise(0.280, hold_hz=4000, seed=0x5E65, decay_pow=1.0)
    return finish(mix((cat(*steps), 0.85), (buzz, 0.15)), 0.6)


def glitch_infinite_loop():
    # Infinite Loop glitch: a rising sweep stuck in a loop (the first 18 ms stutters 6 times).
    sweep = tone(0.120, 300.0, 1800.0, "saw", decay_pow=0.6, sustain=0.3)
    return finish(crush(stutter(sweep, 0.018, 6), 3), 0.65)


def glitch_null_pointer():
    # Null Pointer glitch: a tone that keeps dropping out (gated) and falling, with dead-air holes.
    body = tone(0.200, 1400.0, 180.0, "triangle", curve=0.6, decay_pow=0.8)
    hiss = noise(0.200, hold_hz=7000, seed=0x3A3A, decay_pow=1.2)
    return finish(gate(mix((body, 0.8), (hiss, 0.25)), 0.025, 0.55), 0.6)


def glitch_segfault():
    # Segfault glitch: crushed, chopped noise with a buzzing square underneath (memory tearing).
    tear = noise(0.220, hold_hz=9000, hold_hz_end=700, seed=0x7B1D, decay_pow=0.9)
    buzz = tone(0.220, 110.0, 90.0, "square", duty=0.3, decay_pow=0.9)
    return finish(gate(crush(mix((tear, 0.7), (buzz, 0.5)), 4), 0.017, 0.7), 0.65)


def phase_roar():
    # Phase roar: a big low growl, square + noise sliding down with a heavy wobble.
    growl = tone(0.700, 240.0, 65.0, "square", duty=0.4, curve=0.8, attack=0.03, decay_pow=1.3,
                 vibrato_hz=11.0, vibrato_depth=0.08)
    rumble = noise(0.700, hold_hz=1500, hold_hz_end=400, seed=0x4040, attack=0.03, decay_pow=1.1)
    under = tone(0.700, 120.0, 40.0, "triangle", attack=0.03, decay_pow=1.2)
    return finish(mix((growl, 0.6), (rumble, 0.45), (under, 0.5)), 0.75)


def defeat():
    # Boss defeated: a crash of noise, then a falling four-note "power down" arpeggio.
    crash = noise(0.350, hold_hz=14000, hold_hz_end=1200, seed=0x0DEF, decay_pow=2.0)
    notes = [880.0, 659.25, 523.25, 392.0]
    steps = [tone(0.110, f, f * 0.97, "square", duty=0.5, decay_pow=0.7, sustain=0.3) for f in notes]
    tail = tone(0.300, 196.0, 98.0, "square", duty=0.5, decay_pow=1.5)
    melody = cat(*steps, tail)
    return finish(mix((crash, 0.5), (melody, 0.6)), 0.75)


def player_hit():
    # Player damaged: a harsh crunch (gritty noise) + a sour falling square, lower than `hit`.
    crunch = noise(0.090, hold_hz=5000, hold_hz_end=1500, seed=0x0F0F, decay_pow=1.4)
    sour = tone(0.120, 330.0, 90.0, "square", duty=0.5, curve=0.7, decay_pow=1.2)
    beat = tone(0.120, 349.0, 95.0, "square", duty=0.5, curve=0.7, decay_pow=1.2)
    return finish(mix((crunch, 0.7), (sour, 0.45), (beat, 0.35)), 0.75)


## D-S72-2: the final file list (15 one-shots). The Null Pointer hum stays in code (D-S72-9).
CLIPS = {
    "shift_left": shift_left,
    "shift_right": shift_right,
    "hit": hit,
    "hit_resisted": hit_resisted,
    "patched_chime": patched_chime,
    "duck_squeak": duck_squeak,
    "tell_infinite_loop": tell_infinite_loop,
    "tell_null_pointer": tell_null_pointer,
    "tell_segfault": tell_segfault,
    "glitch_infinite_loop": glitch_infinite_loop,
    "glitch_null_pointer": glitch_null_pointer,
    "glitch_segfault": glitch_segfault,
    "phase_roar": phase_roar,
    "defeat": defeat,
    "player_hit": player_hit,
}


def write_wav(path: str, sig) -> None:
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(MIX_RATE)
        w.writeframes(to_pcm16(sig))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=DEFAULT_OUT_DIR, help="output directory")
    args = parser.parse_args()
    out_dir = os.path.normpath(args.out)
    os.makedirs(out_dir, exist_ok=True)
    for name, recipe in CLIPS.items():
        sig = recipe()
        path = os.path.join(out_dir, name + ".wav")
        write_wav(path, sig)
        print(f"wrote {path} ({len(sig) / MIX_RATE * 1000.0:.0f} ms)")


if __name__ == "__main__":
    main()
