extends Node2D
## 저편 조준 레티클 — 조준점에 십자선 + (범위형 스킬이면) AoE 미리보기 원. main이 위치·반경·색을 갱신.

var radius: float = 0.0
var col: Color = Color.WHITE

func setup(r: float, c: Color) -> void:
	radius = r
	col = c
	queue_redraw()

func _draw() -> void:
	var c := Color(col.r, col.g, col.b, 0.95)
	# 십자선 + 중심 고리
	draw_line(Vector2(-24, 0), Vector2(24, 0), c, 3.0)
	draw_line(Vector2(0, -24), Vector2(0, 24), c, 3.0)
	draw_arc(Vector2.ZERO, 13, 0.0, TAU, 24, c, 2.0)
	# AoE 미리보기(범위형 스킬만)
	if radius > 1.0:
		draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.12))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.7), 2.5)
