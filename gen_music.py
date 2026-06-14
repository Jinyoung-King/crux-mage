# 배경음악 생성 스크립트 — 표준 라이브러리만 사용한 레트로 칩튠풍 루프.
# 사용: python3 gen_music.py  →  assets/audio/music_*.wav 재생성 (이후 godot --import 2회)
# 트랙: music_menu(차분) / music_battle(경쾌·구동감) / music_boss(긴장).
import os
import struct
import wave
import math

SR = 22050  # 음악은 22.05kHz로 충분(파일 크기↓). 모노 16비트.
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "audio")


def midi(n):
    return 440.0 * (2.0 ** ((n - 69) / 12.0))


def osc(phase, wave):
    p = phase % 1.0
    if wave == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    if wave == "saw":
        return 2.0 * p - 1.0
    # square (duty 0.5)
    return 1.0 if p < 0.5 else -1.0


def add_note(buf, start, dur, freq, vol, wave="square", pad=False):
    """buf(float 리스트)에 한 음을 가산. pad=True면 길게 유지, 아니면 플럭(감쇠)."""
    n = int(dur * SR)
    a = int(0.01 * SR)              # 어택
    rel = int((0.25 if pad else 0.05) * SR)
    ph = 0.0
    for i in range(n):
        idx = start + i
        if idx >= len(buf):
            break
        ph += freq / SR
        # 엔벨로프
        if i < a:
            e = i / max(a, 1)
        elif pad:
            e = 1.0 - 0.15 * (i / n)            # 패드: 거의 유지
            if i > n - rel:
                e *= (n - i) / rel
        else:
            e = math.exp(-3.5 * i / n)          # 플럭: 지수 감쇠
        buf[idx] += osc(ph, wave) * vol * e


def render(name, bpm, bars, prog, arp, bass_oct, lead=None, pad_vol=0.10, arp_vol=0.14, bass_vol=0.16, wv="square"):
    beat = 60.0 / bpm
    bar = beat * 4.0
    total = int(bar * bars * SR)
    buf = [0.0] * total
    for b in range(bars):
        chord = prog[b % len(prog)]           # [root_midi, [chord tone offsets]]
        root, tones = chord[0], chord[1]
        bstart = b * bar
        # 패드(코드 3음 길게)
        for off in tones:
            add_note(buf, int(bstart * SR), bar, midi(root + 12 + off), pad_vol, "tri", pad=True)
        # 베이스(박마다 루트)
        for be in range(4):
            add_note(buf, int((bstart + be * beat) * SR), beat * 0.9, midi(root - 12 + bass_oct), bass_vol, wv)
        # 아르페지오(arp = 박당 분할 수)
        steps = arp
        sdur = bar / steps
        seq = [tones[i % len(tones)] for i in range(steps)]
        for s in range(steps):
            add_note(buf, int((bstart + s * sdur) * SR), sdur * 0.9, midi(root + 12 + seq[s]), arp_vol, wv)
        # 리드 멜로디(옵션): bar별 음 하나
        if lead is not None:
            ln = lead[b % len(lead)]
            if ln is not None:
                add_note(buf, int(bstart * SR), bar * 0.5, midi(root + 24 + ln), arp_vol * 0.9, "tri")
    # 정규화 + 소프트 클립
    peak = max(0.0001, max(abs(x) for x in buf))
    g = 0.72 / peak
    samples = [math.tanh(x * g) for x in buf]
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
        w.writeframes(bytes(frames))
    print("wrote", name, "%.1fs" % (total / SR))


os.makedirs(OUT, exist_ok=True)
# A단조 계열. 코드 = [루트 midi, [코드음 반음 오프셋]]
Am = [57, [0, 3, 7]]; F = [53, [0, 4, 7]]; C = [60, [0, 4, 7]]; G = [55, [0, 4, 7]]
Dm = [50, [0, 3, 7]]; E = [52, [0, 4, 7]]

# 메뉴: 차분한 8바, 느린 아르페지오(삼각), 부드러움
render("music_menu.wav", 84, 8, [Am, F, C, G, Am, F, Dm, E], arp=8, bass_oct=0,
       pad_vol=0.13, arp_vol=0.10, bass_vol=0.12, wv="tri")
# 전투: 경쾌·구동감, 16분 아르페지오(사각), 베이스 펄스
render("music_battle.wav", 140, 8, [Am, Am, F, G, C, G, Dm, E], arp=16, bass_oct=0,
       lead=[0, None, 7, None, 4, None, 3, 5], pad_vol=0.08, arp_vol=0.13, bass_vol=0.17, wv="square")
# 보스: 긴장, 어두운 진행, 빠른 베이스
render("music_boss.wav", 152, 8, [Am, Am, Dm, E, Am, F, E, E], arp=16, bass_oct=-12,
       lead=[0, 3, None, 7, 5, 3, None, 2], pad_vol=0.09, arp_vol=0.12, bass_vol=0.2, wv="saw")
