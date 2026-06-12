extends Node2D
## 게임 배경: 세로 보랏빛 그라데이션 + 아래로 천천히 흐르는 별빛(시차 깊이감).
## CanvasLayer(-1) 안에 두어 월드 뒤에 고정 렌더(화면 흔들림 영향 없음).

const W := 720.0
const H := 1280.0
const TOP := Color(0.05, 0.04, 0.09)   # 위(적 스폰): 더 어둡게
const BOT := Color(0.15, 0.12, 0.22)   # 아래(마법사): 살짝 밝은 보라
const BANDS := 48                       # 그라데이션 밴드 수
const STAR_COUNT := 70

var stars: Array = []

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
	for s in stars:
		s.y += s.spd * delta
		if s.y > H:
			s.y -= H
			s.x = randf() * W
	queue_redraw()

func _draw() -> void:
	# 세로 그라데이션 (밴드로 근사)
	var bh := H / float(BANDS)
	for i in BANDS:
		var t := float(i) / float(BANDS - 1)
		draw_rect(Rect2(0.0, i * bh, W, bh + 1.0), TOP.lerp(BOT, t))
	# 별빛
	for s in stars:
		draw_rect(Rect2(s.x, s.y, s.sz, s.sz), Color(0.78, 0.8, 1.0, s.a))
