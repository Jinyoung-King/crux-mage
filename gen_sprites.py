# 픽셀아트 스프라이트 생성 — 표준 라이브러리만 사용 (ASCII 그리드 → PNG).
# 사용: python3 gen_sprites.py  →  assets/sprites/*.png 재생성
# 게임에서 ×3 스케일로 표시되므로 논리 크기/3 픽셀 그리드로 그린다.
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "sprites")


def _chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(name, grid, palette):
    h = len(grid)
    w = len(grid[0])
    raw = b""
    for row in grid:
        assert len(row) == w, name
        raw += b"\x00"
        for ch in row:
            raw += bytes(palette.get(ch, (0, 0, 0, 0)))
    png = (b"\x89PNG\r\n\x1a\n"
           + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + _chunk(b"IDAT", zlib.compress(raw))
           + _chunk(b"IEND", b""))
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(png)


# 마법사 (14x20 → 42x60): 뾰족 모자 + 수염 + 로브 + 지팡이
WIZARD = [
    "......OO......",
    ".....TOOT.....",
    "......HH......",
    ".....HHHH.....",
    ".....HHHH.....",
    "....HHHHHH....",
    "....HHHHHH....",
    "...HHHHHHHH...",
    "..BBBBBBBBBB..",
    "...FFFFFF.T...",
    "...FEFFEF.T...",
    "...WWWWWW.T...",
    "..WWWWWWWW.T..",
    "...RRRRRR..T..",
    "..RRRRRRRR.T..",
    "..RRRRRRRR.T..",
    ".RRRRRRRRRRT..",
    ".RRRSRRSRRR...",
    ".RRRSRRSRRR...",
    ".SSSSSSSSSS...",
]
WIZARD_PAL = {
    "H": (40, 70, 160, 255),    # 모자/로브 진파랑
    "B": (240, 200, 80, 255),   # 모자 띠 금색
    "F": (245, 210, 170, 255),  # 얼굴
    "E": (40, 40, 60, 255),     # 눈
    "W": (235, 235, 235, 255),  # 수염
    "R": (60, 100, 200, 255),   # 로브 파랑
    "S": (35, 60, 130, 255),    # 로브 음영
    "T": (140, 95, 50, 255),    # 지팡이
    "O": (255, 230, 120, 255),  # 지팡이 구슬
}

# 기본병 슬라임 (12x12 → 36x36)
BASIC = [
    "....RRRR....",
    "..RRRRRRRR..",
    ".RRRRRRRRRR.",
    ".RRWWRRWWRR.",
    "RRRWBRRWBRRR",
    "RRRRRRRRRRRR",
    "RRRRRRRRRRRR",
    "RRRDDDDDDRRR",
    "RRRRRRRRRRRR",
    ".RRRRRRRRRR.",
    ".RDRRDRRDRR.",
    "..D..D..D...",
]
BASIC_PAL = {
    "R": (215, 70, 70, 255),   # 몸통 빨강
    "D": (150, 35, 45, 255),   # 음영
    "W": (255, 255, 255, 255), # 눈 흰자
    "B": (35, 25, 40, 255),    # 눈동자
}

# 돌격병 (9x9 → 27x27): 아래로 쏘아지는 화살촉 모양
FAST = [
    "OOO...OOO",
    "OYYO.OYYO",
    ".OYYOYYO.",
    ".OYWYWYO.",
    "..OYYYO..",
    "..OYYYO..",
    "...OYO...",
    "...OYO...",
    "....O....",
]
FAST_PAL = {
    "O": (200, 95, 25, 255),   # 외곽 주황(진)
    "Y": (250, 150, 50, 255),  # 몸통 주황
    "W": (255, 240, 200, 255), # 눈
}

# 철갑병 골렘 (16x16 → 48x48)
TANK = [
    "..PPPPPPPPPPPP..",
    ".PPDDPPPPPPDDPP.",
    "PPDDPPPPPPPPDDPP",
    "PPPPPPPPPPPPPPPP",
    "PPPWWPPPPPPWWPPP",
    "PPPWRPPPPPPRWPPP",
    "PPPPPPPPPPPPPPPP",
    "PPPPPPDDDDPPPPPP",
    "PPPPPDPPPPDPPPPP",
    "PPPPPPPPPPPPPPPP",
    "PDDPPPPPPPPPPDDP",
    "PPDDPPPPPPPPDDPP",
    "PPPPPPPPPPPPPPPP",
    ".PPPPPDPPDPPPPP.",
    ".PPPPDPPPPDPPPP.",
    "..PPPPPPPPPPPP..",
]
TANK_PAL = {
    "P": (135, 75, 160, 255),  # 몸통 보라
    "D": (85, 40, 105, 255),   # 균열/음영
    "W": (255, 255, 255, 255), # 눈 흰자
    "R": (255, 80, 80, 255),   # 눈동자(성난 빨강)
}

# 마법탄 (5x5 → 15x15): 중심 흰빛 + 노란 광채
BOLT = [
    "..Y..",
    ".YWY.",
    "YWWWY",
    ".YWY.",
    "..Y..",
]
BOLT_PAL = {
    "Y": (255, 210, 80, 255),
    "W": (255, 255, 235, 255),
}

os.makedirs(OUT, exist_ok=True)
write_png("wizard.png", WIZARD, WIZARD_PAL)
write_png("enemy_basic.png", BASIC, BASIC_PAL)
write_png("enemy_fast.png", FAST, FAST_PAL)
write_png("enemy_tank.png", TANK, TANK_PAL)
write_png("bolt.png", BOLT, BOLT_PAL)
print("OK:", sorted(os.listdir(OUT)))
