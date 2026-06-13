extends Control
## 기지 내구도 아이콘 — PNG 없이 방패 도형. '기지 내구도' 텍스트 대체.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	# 방패 본체
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.82, -r), c + Vector2(r * 0.82, -r),
		c + Vector2(r * 0.82, r * 0.15), c + Vector2(0, r), c + Vector2(-r * 0.82, r * 0.15)
	]), Color(0.42, 0.66, 0.95))
	# 안쪽 밝은 면
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.5, -r * 0.55), c + Vector2(r * 0.5, -r * 0.55),
		c + Vector2(r * 0.5, r * 0.02), c + Vector2(0, r * 0.5), c + Vector2(-r * 0.5, r * 0.02)
	]), Color(0.72, 0.86, 1.0))
