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
# 로브 3색(진/주/음영)과 구슬색만 바꿔 캐릭터별 마법사 변형을 만든다.
def _wizard_pal(dark, main, shadow, orb):
    return {
        "H": dark + (255,),     # 모자/어깨 로브 (진)
        "R": main + (255,),     # 로브 본색
        "S": shadow + (255,),   # 로브 음영
        "B": (240, 200, 80, 255),   # 모자 띠 금색 (공통)
        "F": (245, 210, 170, 255),  # 얼굴
        "E": (40, 40, 60, 255),     # 눈
        "W": (235, 235, 235, 255),  # 수염
        "T": (140, 95, 50, 255),    # 지팡이
        "O": orb + (255,),          # 지팡이 구슬 (캐릭터 강조색)
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

# 유령 (10x10 → 30x30): 지그재그 회피형
GHOST = [
    "..CCCCCC..",
    ".CCCCCCCC.",
    "CCCCCCCCCC",
    "CCEECCEECC",
    "CCEECCEECC",
    "CCCCCCCCCC",
    "CCCCCCCCCC",
    "CCCCCCCCCC",
    "CC.CCCC.CC",
    "C...CC...C",
]
GHOST_PAL = {
    "C": (175, 225, 240, 255),  # 몸통 창백한 청록
    "E": (45, 65, 95, 255),     # 눈
}

# 분열 슬라임 (14x14 → 42x42)
SLIME_BIG = [
    ".....GGGG.....",
    "...GGGGGGGG...",
    "..GGGGGGGGGG..",
    ".GGWWGGGGWWGG.",
    ".GGWBGGGGWBGG.",
    "GGGGGGGGGGGGGG",
    "GGGGGGGGGGGGGG",
    "GGGDDDDDDDDGGG",
    "GGGGGGGGGGGGGG",
    "GGGGGGGGGGGGGG",
    ".GGGGGGGGGGGG.",
    ".GDGGDGGDGGDG.",
    "..D..D..D..D..",
    "..............",
]
SLIME_BIG_PAL = {
    "G": (95, 200, 95, 255),    # 몸통 초록
    "D": (45, 130, 60, 255),    # 음영
    "W": (255, 255, 255, 255),  # 눈 흰자
    "B": (30, 45, 35, 255),     # 눈동자
}

# 새끼 슬라임 (7x7 → 21x21)
SLIME_MINI = [
    ".GGGGG.",
    "GGWGWGG",
    "GGGGGGG",
    "GGGGGGG",
    "GGDDDGG",
    ".GGGGG.",
    ".G.G.G.",
]
SLIME_MINI_PAL = {
    "G": (130, 220, 110, 255),  # 연두 (대왕보다 밝게)
    "D": (55, 145, 70, 255),
    "W": (255, 255, 255, 255),
}

# 보스 마왕 (24x24 → 72x72): 뿔 + 붉은 눈 + 이빨
BOSS = [
    "...HH..............HH...",
    "..HHH..............HHH..",
    "..HH....KKKKKKKK....HH..",
    "......KKKKKKKKKKKK......",
    ".....KKKKKKKKKKKKKK.....",
    "....KKKKKKKKKKKKKKKK....",
    "....KKRRRKKKKKKRRRKK....",
    "....KKRRRKKKKKKRRRKK....",
    "....KKKKKKKKKKKKKKKK....",
    "...KKKKKKKKKKKKKKKKKK...",
    "...KKKKPPPPPPPPPPKKKK...",
    "...KKKPPPPPPPPPPPPKKK...",
    "...KKKPPMMMMMMMMPPKKK...",
    "...KKKPPMWMWMWMWPPKKK...",
    "...KKKPPMMMMMMMMPPKKK...",
    "...KKKKPPPPPPPPPPKKKK...",
    "....KKKKKKKKKKKKKKKK....",
    "....KKKKKKKKKKKKKKKK....",
    ".....KKKKKKKKKKKKKK.....",
    "....KKK..KKKKKK..KKK....",
    "....KK....KKKK....KK....",
    "...KKK....KKKK....KKK...",
    "...KK......KK......KK...",
    "........................",
]
BOSS_PAL = {
    "K": (60, 35, 75, 255),     # 몸통 암보라
    "P": (110, 60, 130, 255),   # 가슴 보라
    "R": (255, 60, 60, 255),    # 눈 빨강
    "H": (230, 220, 200, 255),  # 뿔
    "M": (135, 25, 45, 255),    # 입
    "W": (255, 250, 235, 255),  # 이빨
}

# 마술사 (12x12 → 36x36): 후드 로브 + 빛나는 눈, 원거리 공격형
CASTER = [
    "....KKKK....",
    "...KKKKKK...",
    "..KKKKKKKK..",
    "..KSSSSSSK..",
    "..KSESSESK..",
    "..KSSSSSSK..",
    "..KKKKKKKK..",
    ".KKKKKKKKKK.",
    ".KKKPKKPKKK.",
    "KKKKKKKKKKKK",
    "KKKKKKKKKKKK",
    ".KK.KKKK.KK.",
]
CASTER_PAL = {
    "K": (50, 40, 70, 255),     # 로브 암보라
    "S": (25, 20, 35, 255),     # 후드 그림자
    "E": (235, 80, 200, 255),   # 빛나는 눈 마젠타
    "P": (140, 60, 170, 255),   # 장식 띠
}

# 적 마탄 (5x5 → 15x15): 마젠타 구체
DARK_BOLT = [
    "..M..",
    ".MWM.",
    "MWWWM",
    ".MWM.",
    "..M..",
]
DARK_BOLT_PAL = {
    "M": (220, 70, 200, 255),
    "W": (255, 205, 250, 255),
}

# 마법탄 (5x5): 중심 흰빛 + 노란 광채 — 견습 마법사
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

# 화염구 (7x7) — 화염술사
FIREBALL = [
    "..OOO..",
    ".OYYYO.",
    "OYWWWYO",
    "OYWWWYO",
    "OYYYYYO",
    ".OYYYO.",
    "..OOO..",
]
FIREBALL_PAL = {
    "O": (200, 70, 30, 255),
    "Y": (250, 150, 50, 255),
    "W": (255, 240, 190, 255),
}

# 화살 (9x5, 오른쪽을 향함 → 발사 방향으로 회전됨) — 폭풍 궁사
ARROW = [
    ".....A...",
    "GGGGGAA..",
    "GGGGGGGAA",
    "GGGGGAA..",
    ".....A...",
]
ARROW_PAL = {
    "G": (90, 200, 110, 255),
    "A": (200, 255, 170, 255),
}

# 서리 파편 (5x5) — 서리 마도사
FROST = [
    "..C..",
    ".CWC.",
    "CWFWC",
    ".CWC.",
    "..C..",
]
FROST_PAL = {
    "C": (90, 200, 230, 255),
    "F": (170, 230, 255, 255),
    "W": (240, 252, 255, 255),
}

os.makedirs(OUT, exist_ok=True)
write_png("wizard.png", WIZARD, _wizard_pal((40, 70, 160), (60, 100, 200), (35, 60, 130), (255, 230, 120)))
write_png("mage_fire.png", WIZARD, _wizard_pal((150, 40, 40), (205, 75, 60), (115, 30, 35), (255, 180, 80)))
write_png("mage_storm.png", WIZARD, _wizard_pal((40, 115, 70), (70, 175, 95), (35, 95, 55), (190, 255, 150)))
write_png("mage_frost.png", WIZARD, _wizard_pal((50, 110, 150), (85, 175, 205), (40, 90, 130), (190, 240, 255)))
write_png("fireball.png", FIREBALL, FIREBALL_PAL)
write_png("arrow.png", ARROW, ARROW_PAL)
write_png("frost.png", FROST, FROST_PAL)
write_png("enemy_basic.png", BASIC, BASIC_PAL)
write_png("enemy_fast.png", FAST, FAST_PAL)
write_png("enemy_tank.png", TANK, TANK_PAL)
write_png("enemy_boss.png", BOSS, BOSS_PAL)
write_png("enemy_ghost.png", GHOST, GHOST_PAL)
write_png("enemy_slime_big.png", SLIME_BIG, SLIME_BIG_PAL)
write_png("enemy_slime_mini.png", SLIME_MINI, SLIME_MINI_PAL)
write_png("enemy_caster.png", CASTER, CASTER_PAL)
write_png("dark_bolt.png", DARK_BOLT, DARK_BOLT_PAL)
write_png("bolt.png", BOLT, BOLT_PAL)
print("OK:", sorted(os.listdir(OUT)))
