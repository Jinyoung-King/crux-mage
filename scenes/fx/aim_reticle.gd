extends Node2D
## 저편 조준 레티클 — 두 가지 모드:
##  · area(범위형): 십자선 + AoE 미리보기 원 (조준점에 떨어뜨림)
##  · missile(발사형): 마법사→조준점 발사선 + 화살촉 (그 방향으로 쏨)
## main이 위치(global_position=조준점)·모드·반경·색·origin(마법사 좌표)을 갱신.

var missile: bool = false
var radius: float = 0.0
var col: Color = Color.WHITE
var origin: Vector2 = Vector2.ZERO  # missile 모드 발사 원점(마법사 전역좌표)

func setup(is_missile: bool, r: float, c: Color) -> void:
	missile = is_missile
	radius = r
	col = c
	queue_redraw()

func _draw() -> void:
	var c := Color(col.r, col.g, col.b, 0.95)
	if missile:
		var o := to_local(origin)  # 로컬 기준 마법사 위치(조준점이 원점)
		draw_line(o, Vector2.ZERO, Color(col.r, col.g, col.b, 0.45), 3.0)  # 발사선
		var dir := -o  # 마법사→조준점 방향
		if dir.length() > 1.0:
			dir = dir.normalized()
			var perp := dir.orthogonal()
			draw_line(Vector2.ZERO, -dir * 24 + perp * 13, c, 3.0)  # 화살촉
			draw_line(Vector2.ZERO, -dir * 24 - perp * 13, c, 3.0)
		draw_circle(Vector2.ZERO, 7.0, c)
	else:
		# 범위형 — 십자선만(AoE 원형 표시 제거). 착탄 크기는 시전 시 외부 FX로 표현.
		draw_line(Vector2(-24, 0), Vector2(24, 0), c, 3.0)
		draw_line(Vector2(0, -24), Vector2(0, 24), c, 3.0)
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, c, 2.0)
