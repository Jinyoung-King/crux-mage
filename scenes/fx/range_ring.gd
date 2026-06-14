extends Node2D
## 스킬 사거리 표시 링. 스킬 쿨타임 아이콘을 누르고 있는 동안만 보인다.
## 마법사(원점)를 중심으로 사거리 반지름의 원을 옅게 채우고 속성색 테두리를 그린다.
## main이 show_range(반지름, 색) / hide_ring()으로 토글.

var radius: float = 0.0
var col: Color = Color.WHITE

func show_range(r: float, c: Color) -> void:
	radius = r
	col = c
	visible = true
	queue_redraw()

func hide_ring() -> void:
	visible = false

func _draw() -> void:
	if radius <= 0.0:
		return
	# 사거리 안쪽을 아주 옅게 채워 영역을 인지시키고, 경계는 속성색으로 또렷하게
	draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.06))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(col.r, col.g, col.b, 0.6), 3.0, true)
