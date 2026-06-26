extends Node2D
## 게임 배경: 세로 그라데이션 + 입자(시차) + 바닥 발광 + 바닥 지형 실루엣.
## 바이옴별로 분위기가 다르고, 속성마다 변형(variant) 2종이 있어 깊이 들어갈수록 새 풍경이 나온다.
## set_biome(elem, variant)로 전환(스테이지마다 호출). CanvasLayer(-1)라 화면 흔들림 영향 없음.
## 홈 화면은 set_biome(elem)로 선택 캐릭터 속성 풍경을 보여준다.

const W := 720.0
const H := 1280.0
const BANDS := 48
const TOP := Color(0.05, 0.04, 0.09)
const BOT := Color(0.15, 0.12, 0.22)

# 속성 → 변형 목록(각 변형 = 한 풍경). 위쪽(적 스폰)은 가독성 위해 어둡게 유지.
#  top/bot=그라데이션, pcol=입자색, vx/vy=입자 기본속도(+우/하, -좌/상), sz=크기범위, count=수,
#  shape=rect|circle, glow=바닥 발광(a=0 없음), sil=지형 실루엣(pine|dune|jag|hill|reed|"").
const BIOMES := {
	"wood": [
		{"top": Color(0.04,0.10,0.06), "bot": Color(0.10,0.22,0.12), "pcol": Color(0.55,0.82,0.42), "vx": 9.0, "vy": 30.0, "sz": [2.5,5.0], "count": 44, "shape": "rect", "glow": Color(0.18,0.40,0.16,0.18), "sil": "pine"},   # 숲(나뭇잎)
		{"top": Color(0.03,0.08,0.05), "bot": Color(0.07,0.17,0.10), "pcol": Color(0.45,0.70,0.35), "vx": 12.0, "vy": 26.0, "sz": [2.5,5.5], "count": 52, "shape": "rect", "glow": Color(0.12,0.30,0.12,0.24), "sil": "pine"},  # 정글(짙고 빽빽)
	],
	"fire": [
		{"top": Color(0.10,0.03,0.02), "bot": Color(0.30,0.07,0.03), "pcol": Color(1.0,0.62,0.22), "vx": 7.0, "vy": -36.0, "sz": [1.5,3.5], "count": 54, "shape": "rect", "glow": Color(0.95,0.32,0.10,0.42), "sil": "jag"},   # 용암(불씨↑+발광)
		{"top": Color(0.09,0.06,0.06), "bot": Color(0.22,0.14,0.12), "pcol": Color(0.72,0.62,0.56), "vx": 10.0, "vy": 22.0, "sz": [1.5,3.5], "count": 58, "shape": "rect", "glow": Color(0.85,0.27,0.08,0.30), "sil": "jag"},   # 화산재(잿가루↓)
	],
	"earth": [
		{"top": Color(0.20,0.14,0.07), "bot": Color(0.42,0.31,0.16), "pcol": Color(0.88,0.74,0.46), "vx": 95.0, "vy": 12.0, "sz": [1.5,3.0], "count": 64, "shape": "rect", "glow": Color(0.55,0.42,0.20,0.16), "sil": "dune"},  # 사막(모래→)
		{"top": Color(0.16,0.08,0.05), "bot": Color(0.34,0.16,0.10), "pcol": Color(0.80,0.55,0.38), "vx": 70.0, "vy": 16.0, "sz": [1.5,3.0], "count": 56, "shape": "rect", "glow": Color(0.50,0.25,0.12,0.18), "sil": "jag"},   # 협곡(붉은 암반)
	],
	"metal": [
		{"top": Color(0.10,0.12,0.16), "bot": Color(0.22,0.26,0.33), "pcol": Color(0.92,0.95,1.0), "vx": 15.0, "vy": 27.0, "sz": [2.0,4.0], "count": 60, "shape": "circle", "glow": Color(0.50,0.60,0.75,0.14), "sil": "hill"}, # 설원(눈↓)
		{"top": Color(0.06,0.10,0.15), "bot": Color(0.14,0.22,0.32), "pcol": Color(0.70,0.88,1.0), "vx": 8.0, "vy": 16.0, "sz": [2.0,4.5], "count": 50, "shape": "circle", "glow": Color(0.35,0.55,0.80,0.20), "sil": "jag"},   # 빙동굴(결정)
	],
	"water": [
		{"top": Color(0.04,0.09,0.08), "bot": Color(0.10,0.17,0.13), "pcol": Color(0.50,0.66,0.45), "vx": 6.0, "vy": -16.0, "sz": [2.0,4.5], "count": 40, "shape": "circle", "glow": Color(0.20,0.36,0.22,0.30), "sil": "reed"}, # 늪(기포↑+안개)
		{"top": Color(0.02,0.05,0.10), "bot": Color(0.04,0.10,0.20), "pcol": Color(0.40,0.75,0.85), "vx": 4.0, "vy": -22.0, "sz": [2.0,5.0], "count": 46, "shape": "circle", "glow": Color(0.10,0.30,0.45,0.34), "sil": "reed"}, # 심해(발광 기포↑)
	],
}

var particles: Array = []
var _shape := "rect"
var _initialized := false
var _draw_every := 1
var _df := 0

var _top := TOP
var _bot := BOT
var _glow := Color(0, 0, 0, 0)
var _top_t := TOP
var _bot_t := BOT
var _glow_t := Color(0, 0, 0, 0)

var _sil_type := ""        # 지형 실루엣 종류
var _sil_col := Color(0, 0, 0, 0)
var _sil_poly := PackedVector2Array()  # 바닥 폴리곤(dune/jag/hill) 또는 평지 띠(pine/reed)
var _sil_items: Array = []  # 개별 형상(pine 삼각·reed 갈대)

func _ready() -> void:
	_apply_look({"top": TOP, "bot": BOT, "pcol": Color(0.82,0.84,1.0), "vx": 0.0, "vy": 18.0, "sz": [1.5,3.5], "count": 48, "shape": "rect", "glow": Color(0,0,0,0), "sil": ""})

## 인게임/홈: 속성(+변형)으로 바이옴 전환. 변형 없으면 0번.
func set_biome(elem: String, variant: int = 0) -> void:
	var looks: Array = BIOMES.get(elem, [])
	if looks.is_empty():
		return
	_apply_look(looks[variant % looks.size()])

## (호환 보존) 예전 속성색 틴트 — 현재는 set_biome을 권장. 밤하늘 룩에 색만 입힘.
func set_theme_color(c: Color) -> void:
	_apply_look({"top": Color(0.03,0.03,0.05).lerp(c,0.10), "bot": c.darkened(0.58), "pcol": Color(0.85,0.86,1.0).lerp(c,0.4),
		"vx": 0.0, "vy": 18.0, "sz": [1.5,3.5], "count": 48, "shape": "rect", "glow": Color(0,0,0,0), "sil": ""})

## 룩 적용: 목표색 + 입자 재생성 + 지형 실루엣 재구성. 첫 적용은 즉시 스냅.
func _apply_look(look: Dictionary) -> void:
	_top_t = look.top; _bot_t = look.bot; _glow_t = look.get("glow", Color(0,0,0,0))
	_shape = look.get("shape", "rect")
	var pcol: Color = look.pcol
	var sz: Array = look.get("sz", [1.5, 3.5])
	var n: int = mini(int(look.get("count", 48)), 72)
	var vx: float = look.get("vx", 0.0)
	var vy: float = look.get("vy", 18.0)
	particles.clear()
	for i in n:
		var f := randf_range(0.5, 1.35)  # 시차: 입자별 속도 편차
		particles.append({
			"x": randf() * W, "y": randf() * H,
			"vx": vx * f + randf_range(-4.0, 4.0),
			"vy": vy * f,
			"sz": randf_range(sz[0], sz[1]),
			"col": Color(pcol.r, pcol.g, pcol.b, randf_range(0.14, 0.55)),
		})
	_build_silhouette(look.get("sil", ""), look.bot)
	if not _initialized:
		_top = _top_t; _bot = _bot_t; _glow = _glow_t
		_initialized = true
	queue_redraw()

## 바닥 지형 실루엣 생성(랜덤은 여기서 1회 고정 — 매 프레임 흔들림 방지).
func _build_silhouette(type: String, bot: Color) -> void:
	_sil_type = type
	_sil_poly = PackedVector2Array()
	_sil_items = []
	if type == "":
		return
	_sil_col = bot.darkened(0.62)
	_sil_col.a = 0.92
	match type:
		"pine", "reed":  # 평지 띠 + 개별 형상
			var gy: float = H - (28.0 if type == "pine" else 22.0)
			_sil_poly = PackedVector2Array([Vector2(0, H), Vector2(0, gy), Vector2(W, gy), Vector2(W, H)])
			if type == "pine":
				var x := randf_range(10.0, 60.0)
				while x < W:
					_sil_items.append({"x": x, "w": randf_range(34.0, 58.0), "h": randf_range(54.0, 110.0)})
					x += randf_range(52.0, 92.0)
			else:  # reed(갈대)
				var rx := randf_range(6.0, 24.0)
				while rx < W:
					_sil_items.append({"x": rx, "h": randf_range(60.0, 128.0), "lean": randf_range(-12.0, 12.0), "w": randf_range(4.0, 8.0)})
					rx += randf_range(18.0, 34.0)
		"dune", "hill", "jag":  # 프로파일 폴리곤(바닥부터 능선까지)
			var base_y := H - (60.0 if type == "dune" else (66.0 if type == "hill" else 50.0))
			var ph1 := randf() * TAU
			var ph2 := randf() * TAU
			var pts: Array = [Vector2(0, H)]
			var steps := 36
			for i in steps + 1:
				var x := W * float(i) / float(steps)
				var y := base_y
				match type:
					"dune":  # 완만한 모래언덕
						y = base_y - 48.0 * (0.5 + 0.5 * sin(x * 0.011 + ph1)) - 18.0 * sin(x * 0.03 + ph2)
					"hill":  # 둥근 눈언덕(긴 파장)
						y = base_y - 58.0 * (0.5 + 0.5 * sin(x * 0.008 + ph1))
					"jag":   # 뾰족한 암릉
						y = base_y - 120.0 * abs(sin(x * 0.018 + ph1)) - 30.0 * abs(sin(x * 0.05 + ph2))
				pts.append(Vector2(x, y))
			pts.append(Vector2(W, H))
			_sil_poly = PackedVector2Array(pts)

func _process(delta: float) -> void:
	var k := clampf(delta * 2.5, 0.0, 1.0)
	_top = _top.lerp(_top_t, k); _bot = _bot.lerp(_bot_t, k); _glow = _glow.lerp(_glow_t, k)
	for p in particles:
		p.x += p.vx * delta; p.y += p.vy * delta
		if p.y > H + 8.0:
			p.y = -8.0; p.x = randf() * W
		elif p.y < -8.0:
			p.y = H + 8.0; p.x = randf() * W
		if p.x > W + 8.0:
			p.x = -8.0
		elif p.x < -8.0:
			p.x = W + 8.0
	_df += 1
	if _df >= _draw_every:
		_df = 0
		queue_redraw()

func set_perf(tier: int) -> void:
	_draw_every = tier + 1

func _draw() -> void:
	# 세로 그라데이션
	var bh := H / float(BANDS)
	for i in BANDS:
		var t := float(i) / float(BANDS - 1)
		draw_rect(Rect2(0.0, i * bh, W, bh + 1.0), _top.lerp(_bot, t))
	# 바닥 발광(용암·늪 등)
	if _glow.a > 0.004:
		var gh := 360.0
		var gb := 12
		for i in gb:
			var tt := float(i) / float(gb - 1)
			draw_rect(Rect2(0.0, H - gh + (gh / gb) * i, W, gh / gb + 1.0), Color(_glow.r, _glow.g, _glow.b, _glow.a * tt))
	# 바닥 지형 실루엣
	_draw_silhouette()
	# 입자(나뭇잎·불씨·잿가루·모래·눈·기포)
	if _shape == "circle":
		for p in particles:
			draw_circle(Vector2(p.x, p.y), p.sz * 0.5, p.col)
	else:
		for p in particles:
			draw_rect(Rect2(p.x, p.y, p.sz, p.sz), p.col)

func _draw_silhouette() -> void:
	if _sil_type == "":
		return
	if _sil_poly.size() >= 3:
		draw_colored_polygon(_sil_poly, _sil_col)
	match _sil_type:
		"pine":
			var gy := H - 28.0
			for it in _sil_items:
				var hw: float = it.w * 0.5
				draw_colored_polygon(PackedVector2Array([
					Vector2(it.x - hw, gy), Vector2(it.x + hw, gy), Vector2(it.x, gy - it.h)]), _sil_col)
		"reed":
			var gy2 := H - 22.0
			for it in _sil_items:
				var tip := Vector2(it.x + it.lean, gy2 - it.h)
				draw_line(Vector2(it.x, gy2), tip, _sil_col, it.w)
				draw_circle(tip, it.w * 0.7, _sil_col)
