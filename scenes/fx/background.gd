extends Node2D
## 게임 배경: 세로 그라데이션 + 입자(시차 깊이감) + 선택적 바닥 발광.
## 바이옴별로 색·입자(방향·모양·색)·발광이 달라진다 — set_biome(elem)로 전환(스테이지 속성마다 호출).
## CanvasLayer(-1) 안에 두어 월드 뒤에 고정 렌더(화면 흔들림 영향 없음).
## 기본(미설정)은 보랏빛 밤하늘. 홈 화면은 set_theme_color로 속성색 틴트(기존 동작 보존).

const W := 720.0
const H := 1280.0
const BANDS := 48                       # 그라데이션 밴드 수
const TOP := Color(0.05, 0.04, 0.09)    # 기본(밤하늘) 위
const BOT := Color(0.15, 0.12, 0.22)    # 기본(밤하늘) 아래

# 바이옴 정의(스테이지 속성 → 분위기). top/bot=그라데이션, pcol=입자색,
# vx/vy=입자 기본 속도(+면 우/하, -면 좌/상), sz=크기 범위, count=입자 수,
# shape="rect"|"circle", glow=바닥 발광색(a=0이면 없음). 색은 readability 위해 위쪽을 어둡게 유지.
const BIOMES := {
	"wood":  {"top": Color(0.04, 0.10, 0.06), "bot": Color(0.10, 0.22, 0.12), "pcol": Color(0.55, 0.82, 0.42),
		"vx": 9.0, "vy": 30.0, "sz": [2.5, 5.0], "count": 44, "shape": "rect", "glow": Color(0.18, 0.40, 0.16, 0.18)},   # 숲: 떨어지는 나뭇잎
	"fire":  {"top": Color(0.10, 0.03, 0.02), "bot": Color(0.30, 0.07, 0.03), "pcol": Color(1.0, 0.62, 0.22),
		"vx": 7.0, "vy": -36.0, "sz": [1.5, 3.5], "count": 54, "shape": "rect", "glow": Color(0.95, 0.32, 0.10, 0.42)},  # 용암: 떠오르는 불씨 + 바닥 발광
	"earth": {"top": Color(0.20, 0.14, 0.07), "bot": Color(0.42, 0.31, 0.16), "pcol": Color(0.88, 0.74, 0.46),
		"vx": 95.0, "vy": 12.0, "sz": [1.5, 3.0], "count": 64, "shape": "rect", "glow": Color(0.55, 0.42, 0.20, 0.16)},   # 사막: 흩날리는 모래
	"metal": {"top": Color(0.10, 0.12, 0.16), "bot": Color(0.22, 0.26, 0.33), "pcol": Color(0.92, 0.95, 1.0),
		"vx": 15.0, "vy": 27.0, "sz": [2.0, 4.0], "count": 60, "shape": "circle", "glow": Color(0.5, 0.6, 0.75, 0.14)},   # 설원: 내리는 눈
	"water": {"top": Color(0.04, 0.09, 0.08), "bot": Color(0.10, 0.17, 0.13), "pcol": Color(0.5, 0.66, 0.45),
		"vx": 6.0, "vy": -16.0, "sz": [2.0, 4.5], "count": 40, "shape": "circle", "glow": Color(0.20, 0.36, 0.22, 0.30)},  # 늪: 떠오르는 기포 + 탁한 안개
}

var particles: Array = []
var _shape := "rect"
var _initialized := false
var _draw_every := 1  # FPS 거버너: 1=매 프레임, 2~3=N프레임마다(저전력)
var _df := 0

# 현재/목표 색(부드럽게 추종)
var _top := TOP
var _bot := BOT
var _glow := Color(0, 0, 0, 0)
var _top_t := TOP
var _bot_t := BOT
var _glow_t := Color(0, 0, 0, 0)

func _ready() -> void:
	# 기본 룩 = 보랏빛 밤하늘(아래로 흐르는 별빛)
	_apply_look(TOP, BOT, Color(0.82, 0.84, 1.0), 0.0, 18.0, 1.5, 3.5, 48, "rect", Color(0, 0, 0, 0))

## 스테이지 속성 → 바이옴 전환(인게임). 정의 없으면 무시(기본 룩 유지).
func set_biome(elem: String) -> void:
	var b: Dictionary = BIOMES.get(elem, {})
	if b.is_empty():
		return
	_apply_look(b.top, b.bot, b.pcol, b.vx, b.vy, b.sz[0], b.sz[1], b.count, b.shape, b.glow)

## 홈 화면: 선택 캐릭터 속성색 틴트(기존 보랏빛 밤하늘 룩 + 색만 추종)
func set_theme_color(c: Color) -> void:
	_apply_look(Color(0.03, 0.03, 0.05).lerp(c, 0.10), c.darkened(0.58),
		Color(0.85, 0.86, 1.0).lerp(c, 0.4), 0.0, 18.0, 1.5, 3.5, 48, "rect", Color(0, 0, 0, 0))

## 룩 적용: 목표색 설정 + 입자 재생성(방향·모양·색·수). 첫 적용은 즉시 스냅(깜빡임 방지).
func _apply_look(top: Color, bot: Color, pcol: Color, vx: float, vy: float, sz_min: float, sz_max: float, count: int, shape: String, glow: Color) -> void:
	_top_t = top; _bot_t = bot; _glow_t = glow
	_shape = shape
	var n := mini(count, 72)
	particles.clear()
	for i in n:
		var f := randf_range(0.5, 1.35)  # 시차: 입자마다 속도 편차(멀고 가까움)
		particles.append({
			"x": randf() * W, "y": randf() * H,
			"vx": vx * f + randf_range(-4.0, 4.0),
			"vy": vy * f,
			"sz": randf_range(sz_min, sz_max),
			"col": Color(pcol.r, pcol.g, pcol.b, randf_range(0.14, 0.55)),
		})
	if not _initialized:
		_top = _top_t; _bot = _bot_t; _glow = _glow_t
		_initialized = true
	queue_redraw()

func _process(delta: float) -> void:
	# 색 부드럽게 추종(바이옴 전환이 매끄럽게)
	var k := clampf(delta * 2.5, 0.0, 1.0)
	_top = _top.lerp(_top_t, k); _bot = _bot.lerp(_bot_t, k); _glow = _glow.lerp(_glow_t, k)
	# 입자 이동 + 화면 밖이면 반대편으로 순환(상/하/좌/우 모두 처리)
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
	if _df >= _draw_every:  # 거버너 단계에 따라 재드로우 빈도 절감(이동 로직은 유지)
		_df = 0
		queue_redraw()

## FPS 거버너 단계 — 재드로우 간격(tier 0=매프레임, 1=2프레임, 2=3프레임마다)
func set_perf(tier: int) -> void:
	_draw_every = tier + 1

func _draw() -> void:
	# 세로 그라데이션(밴드 근사)
	var bh := H / float(BANDS)
	for i in BANDS:
		var t := float(i) / float(BANDS - 1)
		draw_rect(Rect2(0.0, i * bh, W, bh + 1.0), _top.lerp(_bot, t))
	# 바닥 발광(용암·늪 등) — 아래로 갈수록 진해짐
	if _glow.a > 0.004:
		var gh := 360.0
		var gb := 12
		for i in gb:
			var tt := float(i) / float(gb - 1)
			draw_rect(Rect2(0.0, H - gh + (gh / gb) * i, W, gh / gb + 1.0), Color(_glow.r, _glow.g, _glow.b, _glow.a * tt))
	# 입자(나뭇잎·불씨·모래·눈·기포)
	if _shape == "circle":
		for p in particles:
			draw_circle(Vector2(p.x, p.y), p.sz * 0.5, p.col)
	else:
		for p in particles:
			draw_rect(Rect2(p.x, p.y, p.sz, p.sz), p.col)
