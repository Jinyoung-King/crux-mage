# 앱(PWA) 아이콘 생성 — 표준 라이브러리만 사용.
# 기존 위저드 스프라이트(14x20)를 디코드해 게임 배경색 위에 크게 얹어 512x512 아이콘 생성.
# 사용: python3 gen_icon.py  →  icon.png
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.abspath(__file__))


def decode_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, width, height, idat = 8, 0, 0, b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        if tag == b"IHDR":
            width, height, bd, ct = struct.unpack(">IIBB", chunk[:10])
            assert bd == 8 and ct == 6, (bd, ct)  # 8비트 RGBA
        elif tag == b"IDAT":
            idat += chunk
        pos += 12 + ln
    raw = zlib.decompress(idat)
    px = [[(0, 0, 0, 0)] * width for _ in range(height)]
    i = 0
    for y in range(height):
        assert raw[i] == 0, raw[i]  # gen_sprites는 필터 0(None)만 사용
        i += 1
        for x in range(width):
            px[y][x] = tuple(raw[i:i + 4])
            i += 4
    return width, height, px


def _chunk(tag, d):
    return struct.pack(">I", len(d)) + tag + d + struct.pack(">I", zlib.crc32(tag + d) & 0xFFFFFFFF)


def write_png(path, w, h, px):
    raw = b""
    for y in range(h):
        raw += b"\x00"
        for x in range(w):
            raw += bytes(px[y][x])
    png = (b"\x89PNG\r\n\x1a\n"
           + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + _chunk(b"IDAT", zlib.compress(raw, 9))
           + _chunk(b"IEND", b""))
    open(path, "wb").write(png)


ww, wh, wpx = decode_png(os.path.join(ROOT, "assets", "sprites", "wizard.png"))
SIZE = 512
BG = (28, 26, 36, 255)  # 게임 배경색 #1c1a24
scale = 16  # 14x20 → 224x320 (약 62% 높이)
ox = (SIZE - ww * scale) // 2
oy = (SIZE - wh * scale) // 2
icon = [[BG] * SIZE for _ in range(SIZE)]
for sy in range(wh):
    for sx in range(ww):
        r, g, b, a = wpx[sy][sx]
        if a == 0:
            continue
        for dy in range(scale):
            row = icon[oy + sy * scale + dy]
            for dx in range(scale):
                row[ox + sx * scale + dx] = (r, g, b, 255)
write_png(os.path.join(ROOT, "icon.png"), SIZE, SIZE, icon)
print("icon.png %dx%d 생성 완료 (위저드 %dx%d ×%d)" % (SIZE, SIZE, ww, wh, scale))
