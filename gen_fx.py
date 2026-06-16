# 픽셀 FX 스프라이트시트 생성 — 표준 라이브러리만(struct+zlib). 수학으로 프레임을 계산해 가로 시트로 출력.
# 사용: python3 gen_fx.py  →  assets/sprites/fx_*.png 재생성 (이후 godot --headless --import 필요)
# 스킬 이펙트를 절차적 _draw 대신 '미리 구운 픽셀 프레임'으로 — GPU엔 텍스처 사각형 1장이라 더 화려하고 더 쌈.
import os, struct, zlib, math

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "sprites")


def _chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png_rgba(name, rows):
    h = len(rows); w = len(rows[0])
    raw = b""
    for row in rows:
        raw += b"\x00"
        for px in row:
            raw += bytes(px)
    png = (b"\x89PNG\r\n\x1a\n"
           + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + _chunk(b"IDAT", zlib.compress(raw))
           + _chunk(b"IEND", b""))
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(png)


# 열 단계(heat 1=가장 뜨거운 코어 → 0=식은 가장자리)별 색 램프
def _ramp_fire(h):
    if h > 0.85: return (255, 255, 230)
    if h > 0.62: return (255, 214, 120)
    if h > 0.40: return (255, 140, 52)
    if h > 0.20: return (214, 74, 34)
    return (120, 46, 36)


# 폭발 스프라이트시트: N프레임, 각 FR×FR. 확장하는 불덩이 + 밝은 선두 링 + 초반 방사 스파크. p로 페이드.
# blk=픽셀 청크(도트 느낌). ramp=heat→RGB 함수. 결정적(랜덤 없음) → 재생성 일관.
def explosion_sheet(name, ramp, FR=48, N=9, blk=2):
    cx = cy = (FR - 1) / 2.0
    sheet = [[(0, 0, 0, 0) for _ in range(FR * N)] for _ in range(FR)]
    for i in range(N):
        p = i / float(N - 1)            # 0..1 진행
        R = 3.0 + p * (FR / 2.0 - 3.0)  # 반경 확장
        spark = max(0.0, 1.0 - p / 0.5) # 스파크는 초반에만
        ox = i * FR
        for by in range(0, FR, blk):
            for bx in range(0, FR, blk):
                # 청크 중심으로 샘플(도트 블록)
                sx = bx + blk / 2.0 - 0.5
                sy = by + blk / 2.0 - 0.5
                d = math.hypot(sx - cx, sy - cy)
                col = None; a = 0.0
                if d <= R:
                    norm = d / R if R > 0 else 0.0          # 0코어..1가장자리
                    edge = max(0.0, 1.0 - abs(norm - 0.82) / 0.22)  # 선두 링 글로우
                    heat = max((1.0 - norm) * 0.75, edge)
                    col = ramp(heat)
                    a = (1.0 - p * 0.45) * (0.45 + 0.55 * heat)      # 코어가 더 진하고, 프레임 갈수록 옅게
                    if norm > 0.9:
                        a *= (1.0 - (norm - 0.9) / 0.1)              # 가장자리 부드럽게
                else:
                    # 방사 스파크 스포크(초반): 8방향으로 R보다 살짝 길게
                    if spark > 0.0 and d <= R * 1.35:
                        ang = math.atan2(sy - cy, sx - cx)
                        k = (ang / (math.pi / 4.0))
                        if abs(k - round(k)) < 0.12:                 # 8방향 근처
                            col = ramp(0.95)
                            a = spark * 0.9 * max(0.0, 1.0 - (d - R) / (R * 0.35))
                if col is not None and a > 0.02:
                    rgba = (col[0], col[1], col[2], int(max(0.0, min(1.0, a)) * 255))
                    for yy in range(by, min(by + blk, FR)):
                        for xx in range(bx, min(bx + blk, FR)):
                            sheet[yy][ox + xx] = rgba
    write_png_rgba(name, sheet)
    print("wrote %s (%dx%d, %d frames)" % (name, FR * N, FR, N))


# --- 슬라이스: 유성(불) 폭발 ---
explosion_sheet("fx_explosion_fire.png", _ramp_fire)
