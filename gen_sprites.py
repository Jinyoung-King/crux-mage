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
    # 흑백(중립) — 런타임에 enemy.gd가 속성색(오방색)으로 modulate해 졸개를 속성별로 구분
    "R": (235, 235, 240, 255), # 몸통(흰색 → 속성색 틴트)
    "D": (165, 163, 173, 255), # 음영(중간 회색 → 입체감 유지)
    "W": (255, 255, 255, 255), # 눈 흰자(가장 밝게)
    "B": (30, 26, 42, 255),    # 눈동자(어둡게 — 틴트돼도 어두운 점)
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
STORM_BOSS_PAL = {  # 폭풍 마왕 — 전기 청색 변형(BOSS 그리드 재사용)
    "K": (35, 45, 80, 255),     # 몸통 암청
    "P": (60, 110, 175, 255),   # 가슴 청
    "R": (255, 240, 120, 255),  # 눈 번개 노랑
    "H": (210, 225, 245, 255),  # 뿔 (창백)
    "M": (25, 35, 70, 255),     # 입
    "W": (235, 245, 255, 255),  # 이빨
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
SPARK_PAL = {  # 뇌전술사 연쇄 번개 탄 (보라/전기)
    "Y": (170, 130, 255, 255),
    "W": (240, 230, 255, 255),
}

# 마력탄(스킬) 전용 — 평타와 구분되는 '간지나는' 빛나는 마법 별(9x9). 흰-청 기반 → 시전 시 속성색으로 틴트.
SKILL_BOLT = [
    "....X....",
    "....#....",
    "..X.#.X..",
    "...###...",
    "X#######X",
    "...###...",
    "..X.#.X..",
    "....#....",
    "....X....",
]
SKILL_BOLT_PAL = {
    "#": (235, 245, 255, 255),  # 밝은 본체(흰-청)
    "X": (175, 215, 255, 210),  # 별빛 끝/스파클(반투명 글로우)
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

# 보물 (12x12 → 30px): 빛나는 금빛 보석 — 보너스 웨이브 전용, 무해·고코인
TREASURE = [
    "....DDDD....",
    "...DLLLLD...",
    "..DLLWWLLD..",
    ".DLLLWWLLLD.",
    "DLLLLLLLLLLD",
    "DDLLLLLLLLDD",
    ".DLLLLLLLLD.",
    ".DDLLLLLLDD.",
    "..DDLLLLDD..",
    "...DDLLDD...",
    "....DDDD....",
    ".....DD.....",
]
TREASURE_PAL = {
    "D": (200, 150, 30, 255),   # 테두리/음영 진금
    "L": (255, 215, 70, 255),   # 본체 금
    "W": (255, 250, 210, 255),  # 광채 흰빛
}

# 포탄 (7x7) — 포격술사: 작열하는 무쇠 구체
CANNONBALL = [
    ".OOOOO.",
    "OKKKKKO",
    "OKWWKKO",
    "OKWKKKO",
    "OKKKKKO",
    "OKKKKKO",
    ".OOOOO.",
]
CANNONBALL_PAL = {
    "O": (225, 120, 40, 255),   # 작열 주황 테두리
    "K": (45, 42, 52, 255),     # 어두운 금속 본체
    "W": (205, 210, 220, 255),  # 하이라이트
}

# 투척 단검 (12x5, 오른쪽=칼끝 → 발사 방향으로 회전) — 비도술사 평타
KNIFE = [
    "....BBB.....",
    "HHGBBBBBB...",
    "HHGBBBBBBBBP",
    "HHGBBBBBB...",
    "....BBB.....",
]
KNIFE_PAL = {
    "H": (95, 72, 52, 255),    # 손잡이 가죽
    "G": (190, 160, 90, 255),  # 가드 금
    "B": (208, 220, 236, 255), # 강철 칼날
    "P": (248, 252, 255, 255), # 칼끝 광
}

# 날카로운 화살 (12x7, 오른쪽=화살촉) — 가시 화살 스킬(목)
THORN_ARROW = [
    ".......A....",
    "......AA....",
    "SSSSSSAAA...",
    "SSSSSSAAAAAW",
    "SSSSSSAAA...",
    "......AA....",
    ".......A....",
]
THORN_ARROW_PAL = {
    "S": (85, 160, 75, 255),    # 자루(가시 덩굴 초록)
    "A": (180, 230, 150, 255),  # 화살촉(밝은 초록)
    "W": (248, 255, 235, 255),  # 촉끝 광(날카로움 강조)
}

os.makedirs(OUT, exist_ok=True)
write_png("wizard.png", WIZARD, _wizard_pal((40, 70, 160), (60, 100, 200), (35, 60, 130), (255, 230, 120)))
write_png("mage_wood.png", WIZARD, _wizard_pal((40, 115, 70), (75, 180, 95), (32, 90, 52), (190, 255, 150)))  # 목=초록 견습
write_png("mage_fire.png", WIZARD, _wizard_pal((150, 40, 40), (205, 75, 60), (115, 30, 35), (255, 180, 80)))
write_png("mage_storm.png", WIZARD, _wizard_pal((40, 115, 70), (70, 175, 95), (35, 95, 55), (190, 255, 150)))
write_png("mage_frost.png", WIZARD, _wizard_pal((50, 110, 150), (85, 175, 205), (40, 90, 130), (190, 240, 255)))
write_png("mage_arc.png", WIZARD, _wizard_pal((85, 92, 105), (150, 162, 184), (60, 66, 78), (228, 234, 246)))  # 금=강철(비도술사)
write_png("mage_bomb.png", WIZARD, _wizard_pal((70, 55, 40), (125, 95, 55), (50, 40, 28), (255, 150, 60)))
write_png("fireball.png", FIREBALL, FIREBALL_PAL)
write_png("arrow.png", ARROW, ARROW_PAL)
write_png("frost.png", FROST, FROST_PAL)
write_png("enemy_basic.png", BASIC, BASIC_PAL)
write_png("enemy_fast.png", FAST, FAST_PAL)
write_png("enemy_tank.png", TANK, TANK_PAL)
write_png("enemy_boss.png", BOSS, BOSS_PAL)
write_png("enemy_storm.png", BOSS, STORM_BOSS_PAL)
write_png("enemy_ghost.png", GHOST, GHOST_PAL)
write_png("enemy_slime_big.png", SLIME_BIG, SLIME_BIG_PAL)
write_png("enemy_slime_mini.png", SLIME_MINI, SLIME_MINI_PAL)
write_png("enemy_caster.png", CASTER, CASTER_PAL)
write_png("enemy_treasure.png", TREASURE, TREASURE_PAL)
write_png("dark_bolt.png", DARK_BOLT, DARK_BOLT_PAL)
write_png("bolt.png", BOLT, BOLT_PAL)
write_png("bolt_wood.png", BOLT, {"Y": (120, 205, 90, 255), "W": (230, 255, 215, 255)})  # 초록 마력탄(목)
write_png("bolt_skill.png", SKILL_BOLT, SKILL_BOLT_PAL)  # 마력탄 스킬 전용(별/마법구) — 시전 시 속성색 틴트
write_png("spark.png", BOLT, SPARK_PAL)
write_png("knife.png", KNIFE, KNIFE_PAL)            # 비도술사 평타(투척 단검)
write_png("thorn_arrow.png", THORN_ARROW, THORN_ARROW_PAL)  # 가시 화살 스킬

# === 추가 적 (v1.11): 중복 스프라이트 해소 — 잡몹은 신규 그리드, 보스류는 BOSS 그리드+속성색 ===
RUSHER = [
    "...AA...",
    "..AOOA..",
    ".AOOOOA.",
    "AOOWWOOA",
    ".AOOOOA.",
    "..AOOA..",
    "...AA...",
]
RUSHER_PAL = {"A": (200, 80, 30, 255), "O": (245, 135, 55, 255), "W": (255, 240, 200, 255)}

SNIPER = [
    "..GGGGGG..",
    ".GGGGGGGG.",
    "GGGSSSSGGG",
    "GGSWSSWSGG",
    "GGGGGGGGGG",
    ".GGGGGGGG.",
    ".GG.GG.GG.",
]
SNIPER_PAL = {"G": (90, 165, 90, 255), "S": (35, 65, 40, 255), "W": (235, 255, 220, 255)}

KNIGHT = [
    "...SSSSSS...",
    ".SSSSSSSSSS.",
    "SSSWWSSWWSSS",
    "SSSSSSSSSSSS",
    "SSCSSSSSSCSS",
    "SSSSSSSSSSSS",
    ".SSSSSSSSSS.",
    "..SS....SS..",
]
KNIGHT_PAL = {"S": (170, 180, 200, 255), "W": (255, 255, 255, 255), "C": (90, 100, 120, 255)}

CROSSBOW = [
    "..MMMMMM..",
    ".MMMMMMMM.",
    "MMMWWWWMMM",
    "MMMMMMMMMM",
    "C.MMMMMM.C",
    ".MMMMMMMM.",
    "..M.MM.M..",
]
CROSSBOW_PAL = {"M": (120, 130, 145, 255), "W": (235, 240, 200, 255), "C": (180, 150, 90, 255)}

EEL = [
    "EEE.........",
    ".EEEE.......",
    "..EEEW......",
    "...EEEE.....",
    "....EEEE....",
    ".....EEEE...",
    "......EEEE..",
    ".......EEE..",
]
EEL_PAL = {"E": (70, 150, 230, 255), "W": (255, 255, 255, 255)}

JELLY = [
    "..JJJJJJ..",
    ".JJJJJJJJ.",
    "JJJJJJJJJJ",
    "JJWWJJWWJJ",
    "JJJJJJJJJJ",
    ".JJJJJJJJ.",
    "J.J.J.J.J.",
    ".J.J.J.J.J",
]
JELLY_PAL = {"J": (110, 200, 210, 255), "W": (255, 255, 255, 255)}

GOLEM = [
    "..KKKKKKKKKK..",
    ".KKKKKKKKKKKK.",
    "KKKKKKKKKKKKKK",
    "KKKWWKKKKWWKKK",
    "KKKKKKKKKKKKKK",
    "KKKKKDDDDKKKKK",
    "KKKKKKKKKKKKKK",
    ".KKKKKKKKKKKK.",
    "..KK..KK..KK..",
]
GOLEM_PAL = {"K": (160, 120, 70, 255), "W": (245, 240, 200, 255), "D": (100, 70, 40, 255)}

SANDWORM = [
    "NNNW........",
    ".NNNN.......",
    "..NNNN......",
    "...NNNN.....",
    "....NNNN....",
    ".....NNNN...",
    "......NNNN..",
    ".......NNN..",
]
SANDWORM_PAL = {"N": (210, 180, 110, 255), "W": (80, 50, 30, 255)}

# 보스류 — BOSS 그리드 재사용 + 속성 색 팔레트
GUARDIAN_PAL = {"K": (30, 70, 80, 255), "P": (60, 130, 150, 255), "R": (220, 250, 255, 255), "H": (200, 225, 235, 255), "M": (20, 50, 60, 255), "W": (235, 250, 255, 255)}
MIDBOSS_PAL = {"K": (70, 40, 55, 255), "P": (120, 70, 90, 255), "R": (255, 80, 80, 255), "H": (220, 200, 180, 255), "M": (45, 25, 35, 255), "W": (255, 250, 235, 255)}
PLAGUE_PAL = {"K": (40, 70, 40, 255), "P": (80, 140, 70, 255), "R": (220, 255, 120, 255), "H": (210, 220, 180, 255), "M": (30, 50, 30, 255), "W": (235, 255, 225, 255)}
EARTHLORD_PAL = {"K": (80, 55, 35, 255), "P": (135, 95, 55, 255), "R": (255, 150, 60, 255), "H": (225, 205, 170, 255), "M": (50, 35, 25, 255), "W": (255, 245, 225, 255)}

write_png("enemy_rusher.png", RUSHER, RUSHER_PAL)
write_png("enemy_sniper.png", SNIPER, SNIPER_PAL)
write_png("enemy_knight.png", KNIGHT, KNIGHT_PAL)
write_png("enemy_crossbow.png", CROSSBOW, CROSSBOW_PAL)
write_png("enemy_eel.png", EEL, EEL_PAL)
write_png("enemy_jelly.png", JELLY, JELLY_PAL)
write_png("enemy_golem.png", GOLEM, GOLEM_PAL)
write_png("enemy_sandworm.png", SANDWORM, SANDWORM_PAL)
write_png("enemy_guardian.png", BOSS, GUARDIAN_PAL)
write_png("enemy_midboss.png", BOSS, MIDBOSS_PAL)
write_png("enemy_plague.png", BOSS, PLAGUE_PAL)
write_png("enemy_earthlord.png", BOSS, EARTHLORD_PAL)
write_png("cannonball.png", CANNONBALL, CANNONBALL_PAL)
print("OK:", sorted(os.listdir(OUT)))
