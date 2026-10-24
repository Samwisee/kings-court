import numpy as np
from scipy.io import wavfile

SR = 22050

def note_freq(name):
    names = {'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,'G':7,'G#':8,'A':9,'A#':10,'B':11}
    n, octave = name[:-1], int(name[-1])
    semis = names[n] + 12 * (octave - 4) - 9  # relative to A4
    return 440.0 * 2 ** (semis / 12)

def brass(freq, dur, vel=1.0, bend=0.0, muted=False):
    """Additive brass: brightness follows the envelope, light vibrato."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    att, rel = min(0.035, dur * 0.3), min(0.08, dur * 0.4)
    env = np.ones(n)
    a = int(att * SR); r = int(rel * SR)
    env[:a] = np.linspace(0, 1, a) ** 0.7
    env[-r:] *= np.linspace(1, 0, r) ** 1.5
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.15, 0, 1)
    f = freq * vib * (1 + bend * t / dur)
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros(n)
    for h in range(1, 14):
        # Higher harmonics swell as the note gets louder ("blat").
        amp = (1 / h ** 1.1) * env ** (1 + 0.35 * (h - 1))
        if muted:
            amp *= np.exp(-0.45 * (h - 1)) * (0.6 + 0.4 * np.sin(2 * np.pi * 3 * t + h))
        out += amp * np.sin(h * phase)
    # A touch of breath noise in the attack.
    noise = np.random.default_rng(0).normal(0, 0.04, n) * np.exp(-t / 0.03)
    return (out + noise) * vel

def sequence(notes, gap=0.015):
    parts = []
    for spec in notes:
        name, dur = spec[0], spec[1]
        kw = spec[2] if len(spec) > 2 else {}
        tone = brass(note_freq(name), dur, **kw)
        parts.append(tone)
        parts.append(np.zeros(int(gap * SR)))
    return np.concatenate(parts)

def mix(*voices):
    n = max(len(v) for v in voices)
    out = np.zeros(n)
    for v in voices:
        out[:len(v)] += v
    return out

def reverb(x, decay=0.35):
    # A simple hall: a few delayed, softened echoes.
    out = x.copy()
    for d, g in [(0.045, 0.30), (0.083, 0.22), (0.127, 0.16), (0.19, 0.10)]:
        k = int(d * SR)
        out[k:] += x[:-k] * g * decay / 0.35
    return out

def save(name, x, level=0.8):
    x = reverb(x)
    x = x / np.max(np.abs(x)) * level
    fade = int(0.05 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(name, SR, (x * 32767).astype(np.int16))
    print(name, f'{len(x)/SR:.2f}s')

# Crowning fanfare with a harmony a third below.
# Bum bum bum BAH!
lead = sequence([('G4', .12), ('G4', .12), ('G4', .12), ('C5', .62)])
harm = sequence([('E4', .12), ('E4', .12), ('E4', .12), ('G4', .62)])
save('fanfare.wav', mix(lead, 0.55 * harm))

# Win: a rising royal flourish ending on a held major chord.
win_lead = sequence([('C5', .10), ('E5', .10), ('G5', .10), ('C6', .62)])
win_mid = np.concatenate([np.zeros(int(.345 * SR)), brass(note_freq('G5'), .62, .6)])
win_low = np.concatenate([np.zeros(int(.345 * SR)), brass(note_freq('E5'), .62, .55)])
save('win.wav', mix(win_lead, win_mid, win_low))

# Lose: the deflating muted "wah wah wah waaah".
lose = sequence([('G4', .30, {'muted': True}), ('F#4', .30, {'muted': True}),
                 ('F4', .30, {'muted': True}),
                 ('E4', .95, {'muted': True, 'bend': -0.03})], gap=0.05)
save('lose.wav', lose, level=0.7)
