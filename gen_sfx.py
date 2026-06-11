# 효과음 생성 스크립트 — 표준 라이브러리만 사용한 레트로 칩튠풍 단음.
# 사용: python3 gen_sfx.py  →  assets/audio/*.wav 재생성
import os
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "audio")


def write_wav(name, samples):
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            s = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(s * 32767))
        w.writeframes(bytes(frames))


def square_sweep(f0, f1, dur, vol):
    """f0→f1로 주파수가 이동하는 사각파 (선형 감쇠 엔벨로프)"""
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += f / SR
        v = 1.0 if (phase % 1.0) < 0.5 else -1.0
        out.append(v * vol * (1.0 - t))
    return out


os.makedirs(OUT, exist_ok=True)
write_wav("shoot.wav", square_sweep(1200, 700, 0.07, 0.18))
write_wav("enemy_die.wav", square_sweep(500, 120, 0.15, 0.3))
write_wav("player_hit.wav", square_sweep(160, 55, 0.22, 0.5))
write_wav("card_pick.wav",
          square_sweep(523, 523, 0.06, 0.25)
          + square_sweep(659, 659, 0.06, 0.25)
          + square_sweep(784, 784, 0.1, 0.25))
write_wav("game_over.wav", square_sweep(420, 70, 0.8, 0.35))
print("OK:", sorted(f for f in os.listdir(OUT) if f.endswith(".wav")))
