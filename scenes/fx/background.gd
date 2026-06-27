extends Node2D
## 게임 배경: 지평선 위 하늘 + 그 아래로 펼쳐진 '땅'(원근으로 멀어짐) + 바닥 발광 + 먼 지형 실루엣.
## 적이 위(지평선=멀리)에서 땅을 가로질러 성(아래)으로 다가오는 구도. set_biome(elem, variant)로 바이옴 전환.
## CanvasLayer(-1)라 화면 흔들림 영향 없음. 홈은 set_biome(elem)로 선택 캐릭터 풍경.

const W := 720.0
const H := 1280.0
const HORIZON := 232.0  # 이 위=하늘, 아래=땅
const SKY_BANDS := 18
const GROUND_BANDS := 40
const TOP := Color(0.05, 0.04, 0.09)
const BOT := Color(0.15, 0.12, 0.22)

# 속성 → 변형 목록. top=하늘 위, bot=땅 기본색, pcol=입자, vx/vy=입자속도, sz=크기, count=수,
# shape=rect|circle, glow=바닥 발광, sil=먼 지형 실루엣(pine|dune|jag|hill|reed|"").
const BIOMES := {
	"wood": [
		{"top": Color(0.05,0.13,0.10), "bot": Color(0.13,0.26,0.13), "pcol": Color(0.55,0.82,0.42), "vx": 9.0, "vy": 30.0, "sz": [2.5,5.0], "count": 40, "shape": "rect", "glow": Color(0.18,0.40,0.16,0.16), "sil": "pine"},
		{"top": Color(0.04,0.10,0.08), "bot": Color(0.09,0.20,0.11), "pcol": Color(0.45,0.70,0.35), "vx": 12.0, "vy": 26.0, "sz": [2.5,5.5], "count": 48, "shape": "rect", "glow": Color(0.12,0.30,0.12,0.20), "sil": "pine"},
	],
	"fire": [
		{"top": Color(0.12,0.05,0.05), "bot": Color(0.32,0.10,0.05), "pcol": Color(1.0,0.62,0.22), "vx": 7.0, "vy": -36.0, "sz": [1.5,3.5], "count": 50, "shape": "rect", "glow": Color(0.95,0.32,0.10,0.42), "sil": "jag"},
		{"top": Color(0.11,0.08,0.08), "bot": Color(0.24,0.16,0.14), "pcol": Color(0.72,0.62,0.56), "vx": 10.0, "vy": 22.0, "sz": [1.5,3.5], "count": 54, "shape": "rect", "glow": Color(0.85,0.27,0.08,0.32), "sil": "jag"},
	],
	"earth": [
		{"top": Color(0.22,0.16,0.10), "bot": Color(0.44,0.33,0.18), "pcol": Color(0.90,0.76,0.48), "vx": 95.0, "vy": 12.0, "sz": [1.5,3.0], "count": 60, "shape": "rect", "glow": Color(0.55,0.42,0.20,0.14), "sil": "dune"},
		{"top": Color(0.18,0.10,0.07), "bot": Color(0.36,0.18,0.12), "pcol": Color(0.80,0.55,0.38), "vx": 70.0, "vy": 16.0, "sz": [1.5,3.0], "count": 52, "shape": "rect", "glow": Color(0.50,0.25,0.12,0.16), "sil": "jag"},
	],
	"metal": [
		{"top": Color(0.12,0.15,0.20), "bot": Color(0.26,0.30,0.37), "pcol": Color(0.92,0.95,1.0), "vx": 15.0, "vy": 27.0, "sz": [2.0,4.0], "count": 56, "shape": "circle", "glow": Color(0.50,0.60,0.75,0.14), "sil": "hill"},
		{"top": Color(0.08,0.12,0.18), "bot": Color(0.18,0.26,0.36), "pcol": Color(0.70,0.88,1.0), "vx": 8.0, "vy": 16.0, "sz": [2.0,4.5], "count": 48, "shape": "circle", "glow": Color(0.35,0.55,0.80,0.20), "sil": "jag"},
	],
	"water": [
		{"top": Color(0.05,0.11,0.10), "bot": Color(0.12,0.20,0.15), "pcol": Color(0.50,0.66,0.45), "vx": 6.0, "vy": -16.0, "sz": [2.0,4.5], "count": 38, "shape": "circle", "glow": Color(0.20,0.36,0.22,0.28), "sil": "reed"},
		{"top": Color(0.03,0.07,0.13), "bot": Color(0.06,0.13,0.24), "pcol": Color(0.40,0.75,0.85), "vx": 4.0, "vy": -22.0, "sz": [2.0,5.0], "count": 44, "shape": "circle", "glow": Color(0.10,0.30,0.45,0.32), "sil": "reed"},
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

var _sil_type := ""
var _sil_col := Color(0, 0, 0, 0)
var _sil_poly := PackedVector2Array()
var _sil_items: Array = []

func _ready() -> void:
	_apply_look({"top": TOP, "bot": BOT, "pcol": Color(0.82,0.84,1.0), "vx": 0.0, "vy": 18.0, "sz": [1.5,3.5], "count": 40, "shape": "rect", "glow": Color(0,0,0,0), "sil": ""})

func set_biome(elem: String, variant: int = 0) -> void:
	var looks: Array = BIOMES.get(elem, [])
	if looks.is_empty():
		return
	_apply_look(looks[variant % looks.size()])

## (호환) 예전 속성색 틴트 — 현재는 set_biome 권장.
func set_theme_color(c: Color) -> void:
	_apply_look({"top": Color(0.04,0.06,0.05).lerp(c,0.12), "bot": c.darkened(0.5), "pcol": Color(0.85,0.86,1.0).lerp(c,0.4),
		"vx": 0.0, "vy": 18.0, "sz": [1.5,3.5], "count": 40, "shape": "rect", "glow": Color(0,0,0,0), "sil": ""})

func _apply_look(look: Dictionary) -> void:
	_top_t = look.top; _bot_t = look.bot; _glow_t = look.get("glow", Color(0,0,0,0))
	_shape = look.get("shape", "rect")
	var pcol: Color = look.pcol
	var sz: Array = look.get("sz", [1.5, 3.5])
	var n: int = mini(int(look.get("count", 40)), 72)
	var vx: float = look.get("vx", 0.0)
	var vy: float = look.get("vy", 18.0)
	particles.clear()
	for i in n:
		var f := randf_range(0.5, 1.35)
		particles.append({
			"x": randf() * W, "y": randf() * H,
			"vx": vx * f + randf_range(-4.0, 4.0),
			"vy": vy * f,
			"sz": randf_range(sz[0], sz[1]),
			"col": Color(pcol.r, pcol.g, pcol.b, randf_range(0.14, 0.5)),
		})
	_build_silhouette(look.get("sil", ""), look.bot)
	if not _initialized:
		_top = _top_t; _bot = _bot_t; _glow = _glow_t
		_initialized = true
	queue_redraw()

## 먼 지형 실루엣 — 지평선(HORIZON) 위로 솟은 원경(산·나무·언덕·갈대). 랜덤은 1회 고정.
func _build_silhouette(type: String, bot: Color) -> void:
	_sil_type = type
	_sil_poly = PackedVector2Array()
	_sil_items = []
	if type == "":
		return
	_sil_col = bot.darkened(0.72)  # 원경=짙은 그림자(하늘과 대비)
	_sil_col.a = 1.0
	match type:
		"pine":  # 먼 나무 능선(빽빽한 삼각들 — 대비 위해 더 크고 촘촘)
			var x := randf_range(6.0, 24.0)
			while x < W:
				_sil_items.append({"x": x, "w": randf_range(26.0, 44.0), "h": randf_range(34.0, 74.0)})
				x += randf_range(20.0, 34.0)
		"reed":  # 먼 갈대
			var rx := randf_range(6.0, 20.0)
			while rx < W:
				_sil_items.append({"x": rx, "h": randf_range(20.0, 46.0), "lean": randf_range(-8.0, 8.0), "w": randf_range(3.0, 6.0)})
				rx += randf_range(14.0, 26.0)
		"dune", "hill", "jag":  # 지평선 위 능선 — 폴리곤 대신 세로 기둥(rect)으로 채워 삼각분할 실패 회피
			var ph1 := randf() * TAU
			var ph2 := randf() * TAU
			var amp := 84.0 if type == "jag" else (44.0 if type == "hill" else 34.0)
			var cols := 90
			var cw := W / float(cols) + 1.0
			for i in cols:
				var x := W * float(i) / float(cols)
				var up := amp
				match type:
					"dune":
						up = amp * (0.5 + 0.5 * sin(x * 0.011 + ph1)) + 12.0 * sin(x * 0.03 + ph2)
					"hill":
						up = amp * (0.5 + 0.5 * sin(x * 0.008 + ph1))
					"jag":
						up = amp * abs(sin(x * 0.018 + ph1)) + 22.0 * abs(sin(x * 0.05 + ph2))
				_sil_items.append({"x": x, "w": cw, "h": maxf(up, 2.0)})

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
	# ① 하늘(0~HORIZON): 위는 어둡게 → 지평선은 옅은 노을빛
	var horizon_col: Color = _bot.lerp(Color(1, 1, 1), 0.24)
	var sbh := HORIZON / float(SKY_BANDS)
	for i in SKY_BANDS:
		var t := float(i) / float(SKY_BANDS - 1)
		draw_rect(Rect2(0.0, i * sbh, W, sbh + 1.0), _top.lerp(horizon_col, t))
	# ② 땅(HORIZON~H): 멀리(위)는 살짝 어둡게 → 가까이(아래)는 밝게(원근 깊이). 땅 색이 또렷이 보이게.
	var ground_far: Color = _bot.darkened(0.28)
	var ground_near: Color = _bot.lightened(0.12)
	var gh := (H - HORIZON) / float(GROUND_BANDS)
	for i in GROUND_BANDS:
		var t := float(i) / float(GROUND_BANDS - 1)
		draw_rect(Rect2(0.0, HORIZON + i * gh, W, gh + 1.0), ground_far.lerp(ground_near, t))
	# ③ 먼 지형 실루엣(지평선 위)
	_draw_silhouette()
	# ④ 지평선 빛 띠
	draw_rect(Rect2(0.0, HORIZON - 2.0, W, 3.0), Color(horizon_col.r, horizon_col.g, horizon_col.b, 0.5))
	# ⑥ 바닥 발광(용암·늪 등)
	if _glow.a > 0.004:
		var ggh := 320.0
		var gb := 12
		for i in gb:
			var tt := float(i) / float(gb - 1)
			draw_rect(Rect2(0.0, H - ggh + (ggh / gb) * i, W, ggh / gb + 1.0), Color(_glow.r, _glow.g, _glow.b, _glow.a * tt))
	# ⑦ 입자(나뭇잎·불씨·잿가루·모래·눈·기포)
	if _shape == "circle":
		for p in particles:
			draw_circle(Vector2(p.x, p.y), p.sz * 0.5, p.col)
	else:
		for p in particles:
			draw_rect(Rect2(p.x, p.y, p.sz, p.sz), p.col)

func _draw_silhouette() -> void:
	match _sil_type:
		"pine":
			for it in _sil_items:
				var hw: float = it.w * 0.5
				draw_colored_polygon(PackedVector2Array([
					Vector2(it.x - hw, HORIZON), Vector2(it.x + hw, HORIZON), Vector2(it.x, HORIZON - it.h)]), _sil_col)
		"reed":
			for it in _sil_items:
				var tip := Vector2(it.x + it.lean, HORIZON - it.h)
				draw_line(Vector2(it.x, HORIZON), tip, _sil_col, it.w)
		"dune", "hill", "jag":  # 세로 기둥으로 능선 채움(기준선=지평선까지)
			for it in _sil_items:
				draw_rect(Rect2(it.x, HORIZON - it.h, it.w, it.h), _sil_col)
