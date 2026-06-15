extends Node2D
## 게임 배경: 세로 보랏빛 그라데이션 + 아래로 천천히 흐르는 별빛(시차 깊이감).
## CanvasLayer(-1) 안에 두어 월드 뒤에 고정 렌더(화면 흔들림 영향 없음).

const W := 720.0
const H := 1280.0
const TOP := Color(0.05, 0.04, 0.09)   # 위(적 스폰): 더 어둡게
const BOT := Color(0.15, 0.12, 0.22)   # 아래(마법사): 살짝 밝은 보라
const BANDS := 48                       # 그라데이션 밴드 수
const STAR_COUNT := 48                   # 별 수(매 프레임 draw 비용 — 70에서 절감)

var stars: Array = []
var _draw_every := 1  # FPS 거버너: 1=매 프레임 재드로우, 2~3=N프레임마다(저전력 모드)
var _df := 0
# 오행 테마(홈 화면): set_theme_color로 속성색을 주입하면 그라데이션·별빛이 그 색을 띤다.
# 미적용 시(인게임)는 기존 보랏빛 그대로 — 인게임 룩 보존.
var themed := false
var accent := Color.WHITE   # 목표 테마색
var cur := Color.WHITE      # 현재 색(부드럽게 추종)

## 홈 화면에서 선택 캐릭터의 오행 속성색을 주입 (캐릭터 전환 시 부드럽게 전환)
func set_theme_color(c: Color) -> void:
	if not themed:
		cur = c  # 첫 적용은 즉시(깜빡임 방지)
	accent = c
	themed = true

func _ready() -> void:
	for i in STAR_COUNT:
		stars.append({
			"x": randf() * W,
			"y": randf() * H,
			"spd": randf_range(6.0, 26.0),   # 시차: 느린 별=멀리, 빠른 별=가까이
			"sz": randf_range(1.5, 3.5),
			"a": randf_range(0.12, 0.5),
		})

func _process(delta: float) -> void:
	if themed:
		cur = cur.lerp(accent, clampf(delta * 3.0, 0.0, 1.0))  # 속성색 부드럽게 추종
	for s in stars:
		s.y += s.spd * delta
		if s.y > H:
			s.y -= H
			s.x = randf() * W
	_df += 1
	if _df >= _draw_every:  # 거버너 단계에 따라 재드로우 빈도 절감(별 이동 로직은 유지)
		_df = 0
		queue_redraw()

## FPS 거버너 단계 적용 — 재드로우 간격(tier 0=매프레임, 1=2프레임, 2=3프레임마다)
func set_perf(tier: int) -> void:
	_draw_every = tier + 1

func _draw() -> void:
	# 테마 적용 시: 위는 거의 검정+살짝 틴트, 아래는 속성색을 어둡게(은은한 글로우)
	var top: Color = Color(0.03, 0.03, 0.05).lerp(cur, 0.10) if themed else TOP
	var bot: Color = cur.darkened(0.58) if themed else BOT
	var star_tint: Color = Color(0.85, 0.86, 1.0).lerp(cur, 0.4) if themed else Color(0.78, 0.8, 1.0)
	# 세로 그라데이션 (밴드로 근사)
	var bh := H / float(BANDS)
	for i in BANDS:
		var t := float(i) / float(BANDS - 1)
		draw_rect(Rect2(0.0, i * bh, W, bh + 1.0), top.lerp(bot, t))
	# 별빛(속성색 틴트)
	for s in stars:
		draw_rect(Rect2(s.x, s.y, s.sz, s.sz), Color(star_tint.r, star_tint.g, star_tint.b, s.a))
