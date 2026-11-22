#!/usr/bin/env python3
"""Deterministic Stone Age WAV synthesizer for Christ Fallow.

Generates 16-bit PCM mono SFX (assets/audio/sfx/*.wav) and stereo seamless
music loops (assets/audio/music/*.wav) using only Python's standard library.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100


def clamp(x: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return lo if x < lo else (hi if x > hi else x)


def soft_limit(samples: list[float], peak_target: float = 0.86) -> list[float]:
    if not samples:
        return samples
    # Gentle saturation then peak normalize if above target
    out = [math.tanh(s * 1.15) / math.tanh(1.15) for s in samples]
    peak = max(abs(s) for s in out)
    if peak > peak_target and peak > 1e-9:
        scale = peak_target / peak
        out = [s * scale for s in out]
    return [clamp(s, -0.98, 0.98) for s in out]


def soft_limit_stereo(
    left: list[float], right: list[float], peak_target: float = 0.84
) -> tuple[list[float], list[float]]:
    l_out = [math.tanh(s * 1.1) / math.tanh(1.1) for s in left]
    r_out = [math.tanh(s * 1.1) / math.tanh(1.1) for s in right]
    peak = max(
        max((abs(s) for s in l_out), default=0.0),
        max((abs(s) for s in r_out), default=0.0),
    )
    if peak > peak_target and peak > 1e-9:
        scale = peak_target / peak
        l_out = [s * scale for s in l_out]
        r_out = [s * scale for s in r_out]
    return (
        [clamp(s, -0.98, 0.98) for s in l_out],
        [clamp(s, -0.98, 0.98) for s in r_out],
    )


def fade_io(samples: list[float], fade_in_s: float = 0.004, fade_out_s: float = 0.012) -> list[float]:
    n = len(samples)
    fi = min(int(fade_in_s * SAMPLE_RATE), n // 2)
    fo = min(int(fade_out_s * SAMPLE_RATE), n // 2)
    out = list(samples)
    for i in range(fi):
        out[i] *= i / max(1, fi)
    for i in range(fo):
        out[n - 1 - i] *= i / max(1, fo)
    return out


def one_pole_lowpass(samples: list[float], cutoff_hz: float) -> list[float]:
    rc = 1.0 / (2.0 * math.pi * max(10.0, cutoff_hz))
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    out = [0.0] * len(samples)
    y = 0.0
    for i, x in enumerate(samples):
        y += alpha * (x - y)
        out[i] = y
    return out


def one_pole_highpass(samples: list[float], cutoff_hz: float) -> list[float]:
    rc = 1.0 / (2.0 * math.pi * max(10.0, cutoff_hz))
    dt = 1.0 / SAMPLE_RATE
    alpha = rc / (rc + dt)
    out = [0.0] * len(samples)
    y = 0.0
    prev_x = 0.0
    for i, x in enumerate(samples):
        y = alpha * (y + x - prev_x)
        prev_x = x
        out[i] = y
    return out


def bandpass(samples: list[float], low_hz: float, high_hz: float) -> list[float]:
    return one_pole_lowpass(one_pole_highpass(samples, low_hz), high_hz)


def white_noise(rng: random.Random, n: int) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def write_wav_mono(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    final = fade_io(soft_limit(samples))
    pcm = struct.pack(f"<{len(final)}h", *(int(round(s * 32767.0)) for s in final))
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm)


def write_wav_stereo(path: Path, left: list[float], right: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    l_out, r_out = soft_limit_stereo(left, right)
    n = len(l_out)
    interleaved = bytearray(n * 4)
    for i in range(n):
        li = int(round(l_out[i] * 32767.0))
        ri = int(round(r_out[i] * 32767.0))
        struct.pack_into("<2h", interleaved, i * 4, li, ri)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(bytes(interleaved))


# ---------------------------------------------------------------------------
# SFX Generators
# ---------------------------------------------------------------------------


def gen_melee_swing(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.22
    n = int(dur * SAMPLE_RATE)
    noise = bandpass(white_noise(rng, n), 450.0, 2200.0)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        u = t / dur
        env = math.sin(math.pi * u) ** 1.4
        freq = 320.0 * (1.0 - 0.55 * u) + 110.0
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        tone = math.sin(phase) * 0.18 * math.exp(-t * 14.0)
        out[i] = (noise[i] * 1.15 * env + tone) * 0.85
    return out


def gen_melee_hit(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.24
    n = int(dur * SAMPLE_RATE)
    crunch = bandpass(white_noise(rng, n), 300.0, 3200.0)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 165.0 * math.exp(-t * 18.0) + 48.0
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        body = math.sin(phase) * math.exp(-t * 16.0) * 0.85
        snap = crunch[i] * math.exp(-t * 28.0) * 1.2
        out[i] = body + snap
    return out


def gen_club_smash(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.38
    n = int(dur * SAMPLE_RATE)
    grit = bandpass(white_noise(rng, n), 180.0, 1900.0)
    crack = one_pole_highpass(white_noise(rng, n), 1600.0)
    out = [0.0] * n
    phase = 0.0
    sub_phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 135.0 * math.exp(-t * 14.0) + 38.0
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        sub_phase += 2.0 * math.pi * (freq * 0.55) / SAMPLE_RATE
        thump = (math.sin(phase) * 0.8 + math.sin(sub_phase) * 0.45) * math.exp(-t * 10.5)
        wood_crack = crack[i] * math.exp(-t * 42.0) * 0.75
        rubble = grit[i] * math.exp(-t * 14.0) * 0.8
        out[i] = thump + wood_crack + rubble
    return out


def gen_bow_release(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.28
    n = int(dur * SAMPLE_RATE)
    zip_noise = bandpass(white_noise(rng, n), 1500.0, 5200.0)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Taut sinew twang: pitch dips slightly then settles
        f = 240.0 + 130.0 * math.exp(-t * 32.0)
        phase += 2.0 * math.pi * f / SAMPLE_RATE
        twang = (math.sin(phase) + 0.45 * math.sin(2.0 * phase) + 0.2 * math.sin(3.0 * phase)) * math.exp(-t * 15.0)
        arrow_zip = zip_noise[i] * math.exp(-max(0.0, t - 0.012) * 26.0) * (1.0 if t > 0.008 else 0.0)
        out[i] = twang * 0.55 + arrow_zip * 0.85
    return out


def gen_javelin_throw(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.32
    n = int(dur * SAMPLE_RATE)
    air = bandpass(white_noise(rng, n), 320.0, 2600.0)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        u = t / dur
        env = (u ** 0.7) * ((1.0 - u) ** 1.4) * 3.8
        f = 260.0 * (1.0 - 0.65 * u) + 75.0
        phase += 2.0 * math.pi * f / SAMPLE_RATE
        shaft = math.sin(phase) * 0.22 * math.exp(-t * 9.0)
        out[i] = air[i] * env * 1.1 + shaft
    return out


def gen_shield_block(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.26
    n = int(dur * SAMPLE_RATE)
    clack = bandpass(white_noise(rng, n), 700.0, 3600.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        wood_body = (
            math.sin(2.0 * math.pi * 210.0 * t) * 0.55
            + math.sin(2.0 * math.pi * 345.0 * t) * 0.35
            + math.sin(2.0 * math.pi * 520.0 * t) * 0.2
        ) * math.exp(-t * 22.0)
        impact = clack[i] * math.exp(-t * 34.0) * 1.1
        out[i] = wood_body + impact
    return out


def gen_wood_chop(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.25
    n = int(dur * SAMPLE_RATE)
    bite = bandpass(white_noise(rng, n), 550.0, 3800.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        timber = (
            math.sin(2.0 * math.pi * 185.0 * t) * 0.65
            + math.sin(2.0 * math.pi * 310.0 * t) * 0.32
        ) * math.exp(-t * 20.0)
        # Double-micro transient for axe wedge + split
        split = bite[i] * (math.exp(-t * 40.0) + 0.45 * math.exp(-max(0.0, t - 0.025) * 45.0))
        out[i] = timber + split * 0.9
    return out


def gen_stone_mine(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.28
    n = int(dur * SAMPLE_RATE)
    gravel = bandpass(white_noise(rng, n), 1200.0, 5600.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        # High flint/rock harmonic ping + stone grit
        clink = (
            math.sin(2.0 * math.pi * 1680.0 * t) * 0.45
            + math.sin(2.0 * math.pi * 2410.0 * t) * 0.32
            + math.sin(2.0 * math.pi * 3190.0 * t) * 0.18
        ) * math.exp(-t * 28.0)
        thud = math.sin(2.0 * math.pi * 145.0 * t) * math.exp(-t * 24.0) * 0.35
        crumble = gravel[i] * math.exp(-max(0.0, t - 0.018) * 18.0) * 0.75
        out[i] = clink + thud + crumble
    return out


def gen_build_hammer(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.22
    n = int(dur * SAMPLE_RATE)
    tap_noise = bandpass(white_noise(rng, n), 600.0, 2900.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        mallet = (
            math.sin(2.0 * math.pi * 245.0 * t) * 0.65
            + math.sin(2.0 * math.pi * 430.0 * t) * 0.30
        ) * math.exp(-t * 26.0)
        snap = tap_noise[i] * math.exp(-t * 48.0) * 0.9
        out[i] = mallet + snap
    return out


def gen_building_complete(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.95
    n = int(dur * SAMPLE_RATE)
    hit = bandpass(white_noise(rng, n), 400.0, 2200.0)
    out = [0.0] * n
    notes = [(0.0, 293.66), (0.14, 369.99), (0.28, 440.0), (0.42, 587.33)]
    for i in range(n):
        t = i / SAMPLE_RATE
        val = math.sin(2.0 * math.pi * 92.0 * t) * math.exp(-t * 8.0) * 0.55
        val += hit[i] * math.exp(-t * 36.0) * 0.45
        for start, freq in notes:
            if t >= start:
                dt = t - start
                # Warm wooden marimba tone
                tone = (
                    math.sin(2.0 * math.pi * freq * dt) * 0.45
                    + math.sin(2.0 * math.pi * freq * 2.0 * dt) * 0.14 * math.exp(-dt * 12.0)
                ) * math.exp(-dt * 5.8)
                val += tone
        out[i] = val
    return out


def gen_warhorn(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 1.45
    n = int(dur * SAMPLE_RATE)
    breath = bandpass(white_noise(rng, n), 350.0, 1800.0)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        u = t / dur
        # Attack swell, steady brassy hold, tapering tail
        env = min(1.0, t / 0.14) * (1.0 - max(0.0, (t - 0.95) / 0.50))
        env = max(0.0, env) ** 1.15
        # Pitch rises slightly into call then drops gently at the end
        pitch_bend = 1.0 - 0.14 * math.exp(-t * 12.0) - 0.06 * max(0.0, u - 0.72) / 0.28
        vib = 1.0 + 0.012 * math.sin(2.0 * math.pi * 5.2 * t)
        f = 146.83 * pitch_bend * vib
        phase += 2.0 * math.pi * f / SAMPLE_RATE
        horn = (
            math.sin(phase) * 0.58
            + math.sin(2.0 * phase) * 0.42
            + math.sin(3.0 * phase) * 0.24
            + math.sin(4.0 * phase) * 0.11
        )
        out[i] = (horn * 0.72 + breath[i] * 0.16) * env
    return out


def gen_blessing_cast(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 1.10
    n = int(dur * SAMPLE_RATE)
    shimmer_noise = bandpass(white_noise(rng, n), 1400.0, 4800.0)
    out = [0.0] * n
    freqs = [220.0, 329.63, 440.0, 659.25]
    for i in range(n):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.08) * math.exp(-t * 2.7)
        val = 0.0
        for idx, f in enumerate(freqs):
            f_mod = f * (1.0 + 0.006 * math.sin(2.0 * math.pi * (3.2 + idx * 0.7) * t))
            val += math.sin(2.0 * math.pi * f_mod * t) * (0.34 / (1.0 + idx * 0.35))
        # Subtle low shaman drum pulse at cast
        pulse = math.sin(2.0 * math.pi * 85.0 * t) * math.exp(-t * 9.0) * 0.35
        out[i] = val * env + shimmer_noise[i] * env * 0.18 + pulse
    return out


def gen_level_up(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 1.10
    n = int(dur * SAMPLE_RATE)
    snap = bandpass(white_noise(rng, n), 500.0, 2600.0)
    out = [0.0] * n
    # Ascending pentatonic bone-flute & marimba fanfare (D4 - F#4 - A4 - D5)
    hits = [(0.00, 293.66), (0.12, 369.99), (0.24, 440.0), (0.38, 587.33)]
    for i in range(n):
        t = i / SAMPLE_RATE
        val = math.sin(2.0 * math.pi * 98.0 * t) * math.exp(-t * 7.5) * 0.45
        val += snap[i] * math.exp(-t * 32.0) * 0.35
        for idx, (start, freq) in enumerate(hits):
            if t >= start:
                dt = t - start
                decay = 3.2 if idx == 3 else 5.5
                env = min(1.0, dt / 0.015) * math.exp(-dt * decay)
                val += (
                    math.sin(2.0 * math.pi * freq * dt) * 0.48
                    + math.sin(2.0 * math.pi * freq * 2.0 * dt) * 0.16
                ) * env
        out[i] = val
    return out


def gen_ui_click(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.07
    n = int(dur * SAMPLE_RATE)
    tick = bandpass(white_noise(rng, n), 900.0, 4200.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        bone = (
            math.sin(2.0 * math.pi * 680.0 * t) * 0.55
            + math.sin(2.0 * math.pi * 1240.0 * t) * 0.25
        ) * math.exp(-t * 68.0)
        out[i] = bone + tick[i] * math.exp(-t * 95.0) * 0.45
    return out


def gen_animal_roar(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.85
    n = int(dur * SAMPLE_RATE)
    raspy = bandpass(white_noise(rng, n), 160.0, 1400.0)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        u = t / dur
        env = min(1.0, t / 0.09) * ((1.0 - u) ** 1.1)
        f = 96.0 + 48.0 * math.sin(math.pi * min(1.0, u * 1.4)) - 28.0 * u
        fm = 22.0 * math.sin(2.0 * math.pi * 31.0 * t)
        phase += 2.0 * math.pi * max(40.0, f + fm) / SAMPLE_RATE
        growl = math.sin(phase) * 0.65 + math.sin(2.0 * phase) * 0.35 + math.sin(3.0 * phase) * 0.2
        out[i] = (growl * 0.68 + raspy[i] * 0.55) * env
    return out


def gen_footstep_grass(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur = 0.16
    n = int(dur * SAMPLE_RATE)
    rustle = bandpass(white_noise(rng, n), 650.0, 3800.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        u = t / dur
        thud = math.sin(2.0 * math.pi * 110.0 * t) * math.exp(-t * 36.0) * 0.32
        brush = rustle[i] * math.sin(math.pi * u) ** 1.2 * 0.55
        out[i] = thud + brush
    return out


# ---------------------------------------------------------------------------
# Seamless Stereo Music Loop Generators
# ---------------------------------------------------------------------------


def add_stereo_event(
    left: list[float],
    right: list[float],
    loop_samples: int,
    start_s: float,
    event_samples: list[float],
    pan: float = 0.0,
    gain: float = 1.0,
) -> None:
    """Mixes mono event into stereo loop with wrap-around for click-free looping."""
    start_idx = int(round(start_s * SAMPLE_RATE)) % loop_samples
    l_gain = gain * math.sqrt(0.5 * (1.0 - clamp(pan, -0.95, 0.95)))
    r_gain = gain * math.sqrt(0.5 * (1.0 + clamp(pan, -0.95, 0.95)))
    for k, s in enumerate(event_samples):
        idx = (start_idx + k) % loop_samples
        left[idx] += s * l_gain
        right[idx] += s * r_gain


def make_hand_drum(dur_s: float, base_hz: float, accent: float = 1.0) -> list[float]:
    n = int(dur_s * SAMPLE_RATE)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        f = base_hz * (1.0 + 0.55 * math.exp(-t * 34.0))
        phase += 2.0 * math.pi * f / SAMPLE_RATE
        body = math.sin(phase) * math.exp(-t * 11.0)
        slap = math.sin(phase * 2.3) * math.exp(-t * 28.0) * 0.25
        out[i] = (body + slap) * accent * min(1.0, t / 0.003)
    return out


def make_marimba_note(freq: float, dur_s: float = 0.65) -> list[float]:
    n = int(dur_s * SAMPLE_RATE)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.005) * math.exp(-t * 6.5)
        val = (
            math.sin(2.0 * math.pi * freq * t) * 0.72
            + math.sin(2.0 * math.pi * freq * 2.0 * t) * 0.18 * math.exp(-t * 14.0)
            + math.sin(2.0 * math.pi * freq * 3.98 * t) * 0.08 * math.exp(-t * 28.0)
        )
        out[i] = val * env
    return out


def make_bone_flute(rng: random.Random, freq: float, dur_s: float) -> list[float]:
    n = int(dur_s * SAMPLE_RATE)
    breath = bandpass(white_noise(rng, n), freq * 0.8, freq * 3.0)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        u = t / dur_s
        env = math.sin(math.pi * u) ** 0.85
        vib = 1.0 + 0.008 * math.sin(2.0 * math.pi * 4.5 * t)
        phase += 2.0 * math.pi * (freq * vib) / SAMPLE_RATE
        tone = math.sin(phase) * 0.65 + math.sin(2.0 * phase) * 0.14
        out[i] = (tone + breath[i] * 0.20) * env
    return out


def gen_valley_day_peace(seed: int) -> tuple[list[float], list[float]]:
    rng = random.Random(seed)
    dur_s = 12.0  # 16 beats at 80 BPM (0.75 s/beat)
    n = int(dur_s * SAMPLE_RATE)
    left = [0.0] * n
    right = [0.0] * n

    # Warm integer-period drone in D (D2 = 73.42 Hz snapped to exact loop harmonic)
    d2 = round(73.42 * dur_s) / dur_s
    a2 = round(110.0 * dur_s) / dur_s
    for i in range(n):
        t = i / SAMPLE_RATE
        swell = 0.75 + 0.25 * math.sin(2.0 * math.pi * (1.0 / dur_s) * t)
        drone = (math.sin(2.0 * math.pi * d2 * t) * 0.14 + math.sin(2.0 * math.pi * a2 * t) * 0.08) * swell
        left[i] += drone
        right[i] += drone

    beat = 0.75
    low_drum = make_hand_drum(0.32, 82.0, 0.42)
    rim_tap = make_hand_drum(0.14, 195.0, 0.22)
    for b in range(16):
        t_b = b * beat
        if b % 4 == 0:
            add_stereo_event(left, right, n, t_b, low_drum, pan=-0.1, gain=0.8)
        if b % 2 == 1:
            add_stereo_event(left, right, n, t_b, rim_tap, pan=0.18, gain=0.55)
        if b % 4 == 2:
            add_stereo_event(left, right, n, t_b + beat * 0.5, rim_tap, pan=-0.18, gain=0.45)

    # D minor pentatonic wooden marimba ostinato: D4, F4, G4, A4, C5, D5
    melody = [
        (0.0, 293.66, -0.25), (0.75, 349.23, 0.20), (1.50, 440.00, -0.15), (2.25, 392.00, 0.25),
        (3.0, 293.66, -0.25), (3.75, 440.00, 0.20), (4.50, 523.25, -0.15), (5.25, 440.00, 0.25),
        (6.0, 349.23, -0.20), (6.75, 392.00, 0.15), (7.50, 440.00, -0.25), (8.25, 587.33, 0.20),
        (9.0, 523.25, -0.15), (9.75, 440.00, 0.25), (10.50, 392.00, -0.20), (11.25, 349.23, 0.15),
    ]
    for start, freq, pan in melody:
        add_stereo_event(left, right, n, start, make_marimba_note(freq, 0.72), pan=pan, gain=0.38)

    # Sparse breathy bone flute phrases
    flute_phrases = [(1.2, 587.33, 1.8, 0.15), (7.2, 440.0, 2.0, -0.18)]
    for start, freq, fdur, pan in flute_phrases:
        add_stereo_event(left, right, n, start, make_bone_flute(rng, freq, fdur), pan=pan, gain=0.28)

    return left, right


def gen_valley_night_hearth(seed: int) -> tuple[list[float], list[float]]:
    rng = random.Random(seed)
    dur_s = 12.0
    n = int(dur_s * SAMPLE_RATE)
    left = [0.0] * n
    right = [0.0] * n

    # Soft filtered pink-ish hearth ember bed (wrapped with 1.0 s overlap)
    raw = white_noise(rng, n + SAMPLE_RATE)
    ember_bed = bandpass(raw, 140.0, 950.0)
    d2 = round(73.42 * dur_s) / dur_s
    for i in range(n):
        t = i / SAMPLE_RATE
        # Wrap last second back in for seamless noise texture
        fade = i / SAMPLE_RATE if i < SAMPLE_RATE else 1.0
        bed = ember_bed[i] * fade + ember_bed[n + i] * (1.0 - fade) if i < SAMPLE_RATE else ember_bed[i]
        warm_drone = math.sin(2.0 * math.pi * d2 * t) * (0.09 + 0.03 * math.sin(2.0 * math.pi * (2.0 / dur_s) * t))
        left[i] += bed * 0.18 + warm_drone
        right[i] += bed * 0.16 + warm_drone

    # Hearth fire crackles & pops
    for _ in range(34):
        start_s = rng.uniform(0.0, dur_s)
        pop_len = int(0.045 * SAMPLE_RATE)
        pop_noise = bandpass(white_noise(rng, pop_len), 1400.0, 5800.0)
        pop = [pop_noise[k] * math.exp(-(k / SAMPLE_RATE) * 85.0) for k in range(pop_len)]
        add_stereo_event(left, right, n, start_s, pop, pan=rng.uniform(-0.45, 0.45), gain=rng.uniform(0.18, 0.42))

    # Gentle night cricket pulses (high soft rhythmic chirps, low volume)
    for pulse_idx in range(8):
        base_t = 0.6 + pulse_idx * 1.5
        chirp_len = int(0.12 * SAMPLE_RATE)
        chirp = [0.0] * chirp_len
        for k in range(chirp_len):
            kt = k / SAMPLE_RATE
            burst = 0.5 * (1.0 + math.sin(2.0 * math.pi * 24.0 * kt))
            chirp[k] = math.sin(2.0 * math.pi * 4150.0 * kt) * burst * math.sin(math.pi * kt / 0.12)
        pan = 0.55 if pulse_idx % 2 == 0 else -0.55
        add_stereo_event(left, right, n, base_t, chirp, pan=pan, gain=0.055)

    return left, right


def gen_tribal_combat_drums(seed: int) -> tuple[list[float], list[float]]:
    rng = random.Random(seed)
    dur_s = 8.0  # 16 beats at 120 BPM (0.5 s/beat)
    n = int(dur_s * SAMPLE_RATE)
    left = [0.0] * n
    right = [0.0] * n

    # Urgent primitive bass pulse (periodic to 8.0s)
    f_bass = round(55.0 * dur_s) / dur_s
    for i in range(n):
        t = i / SAMPLE_RATE
        pulse = 0.65 + 0.35 * math.sin(2.0 * math.pi * 2.0 * t)
        left[i] += math.sin(2.0 * math.pi * f_bass * t) * 0.15 * pulse
        right[i] += math.sin(2.0 * math.pi * f_bass * t) * 0.15 * pulse

    kick = make_hand_drum(0.28, 72.0, 0.72)
    tom = make_hand_drum(0.20, 128.0, 0.52)
    clack_noise = bandpass(white_noise(rng, int(0.06 * SAMPLE_RATE)), 1100.0, 4200.0)
    clack = [
        clack_noise[k] * math.exp(-(k / SAMPLE_RATE) * 65.0)
        + math.sin(2.0 * math.pi * 880.0 * (k / SAMPLE_RATE)) * math.exp(-(k / SAMPLE_RATE) * 55.0) * 0.45
        for k in range(len(clack_noise))
    ]

    beat = 0.5
    for b in range(16):
        tb = b * beat
        # Driving frame drum pattern: 1, 2+, 3, 4+
        add_stereo_event(left, right, n, tb, kick, pan=-0.08, gain=0.82 if b % 2 == 0 else 0.55)
        add_stereo_event(left, right, n, tb + 0.25, tom, pan=0.25 if b % 2 == 0 else -0.25, gain=0.65)
        if b % 4 in (1, 3):
            add_stereo_event(left, right, n, tb + 0.125, tom, pan=0.15, gain=0.42)
        add_stereo_event(left, right, n, tb + 0.375, clack, pan=0.35 if b % 2 == 0 else -0.35, gain=0.48)

    return left, right


def gen_arena_chant_drums(seed: int) -> tuple[list[float], list[float]]:
    rng = random.Random(seed)
    dur_s = 8.0  # 12 beats at 90 BPM
    n = int(dur_s * SAMPLE_RATE)
    left = [0.0] * n
    right = [0.0] * n

    # Heavy ceremonial pit drums
    pit_drum = make_hand_drum(0.45, 58.0, 0.90)
    mid_drum = make_hand_drum(0.26, 108.0, 0.58)
    shaker_raw = bandpass(white_noise(rng, int(0.10 * SAMPLE_RATE)), 2000.0, 5800.0)
    shaker = [shaker_raw[k] * math.sin(math.pi * k / len(shaker_raw)) for k in range(len(shaker_raw))]

    step = dur_s / 12.0
    for b in range(12):
        tb = b * step
        if b % 3 == 0:
            add_stereo_event(left, right, n, tb, pit_drum, pan=0.0, gain=0.90)
        elif b % 3 == 2:
            add_stereo_event(left, right, n, tb, pit_drum, pan=-0.12, gain=0.62)
        add_stereo_event(left, right, n, tb + step * 0.5, mid_drum, pan=0.22 if b % 2 == 0 else -0.22, gain=0.50)
        add_stereo_event(left, right, n, tb, shaker, pan=-0.35 if b % 2 == 0 else 0.35, gain=0.28)

    # Low ceremonial formant chant swells every 2.0s (periodic over 8.0s)
    f_chant = round(98.0 * dur_s) / dur_s
    for c_idx in range(4):
        c_dur = 1.6
        cn = int(c_dur * SAMPLE_RATE)
        chant = [0.0] * cn
        for k in range(cn):
            kt = k / SAMPLE_RATE
            env = math.sin(math.pi * kt / c_dur) ** 1.2
            val = (
                math.sin(2.0 * math.pi * f_chant * kt) * 0.55
                + math.sin(2.0 * math.pi * (f_chant * 2.0) * kt) * 0.30
                + math.sin(2.0 * math.pi * (f_chant * 3.0) * kt) * 0.15
                + math.sin(2.0 * math.pi * (f_chant * 1.5) * kt) * 0.18
            )
            chant[k] = val * env
        add_stereo_event(left, right, n, 0.2 + c_idx * 2.0, chant, pan=0.0, gain=0.30)

    return left, right


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    sfx_dir = root / "assets" / "audio" / "sfx"
    music_dir = root / "assets" / "audio" / "music"

    sfx_specs = [
        ("melee_swing.wav", gen_melee_swing, 101),
        ("melee_hit.wav", gen_melee_hit, 102),
        ("club_smash.wav", gen_club_smash, 103),
        ("bow_release.wav", gen_bow_release, 104),
        ("javelin_throw.wav", gen_javelin_throw, 105),
        ("shield_block.wav", gen_shield_block, 106),
        ("wood_chop.wav", gen_wood_chop, 107),
        ("stone_mine.wav", gen_stone_mine, 108),
        ("build_hammer.wav", gen_build_hammer, 109),
        ("building_complete.wav", gen_building_complete, 110),
        ("warhorn.wav", gen_warhorn, 111),
        ("blessing_cast.wav", gen_blessing_cast, 112),
        ("level_up.wav", gen_level_up, 113),
        ("ui_click.wav", gen_ui_click, 114),
        ("animal_roar.wav", gen_animal_roar, 115),
        ("footstep_grass.wav", gen_footstep_grass, 116),
    ]

    for filename, fn, seed in sfx_specs:
        out_path = sfx_dir / filename
        write_wav_mono(out_path, fn(seed))
        print(f"Generated SFX: {out_path.relative_to(root)}")

    music_specs = [
        ("valley_day_peace.wav", gen_valley_day_peace, 201),
        ("valley_night_hearth.wav", gen_valley_night_hearth, 202),
        ("tribal_combat_drums.wav", gen_tribal_combat_drums, 203),
        ("arena_chant_drums.wav", gen_arena_chant_drums, 204),
    ]

    for filename, fn, seed in music_specs:
        out_path = music_dir / filename
        left, right = fn(seed)
        write_wav_stereo(out_path, left, right)
        print(f"Generated Music: {out_path.relative_to(root)}")


if __name__ == "__main__":
    main()
