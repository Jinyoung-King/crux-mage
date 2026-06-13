extends Control
## 동전(금화) 아이콘 — '코인' 텍스트 대체. PNG 없이 단색 도형으로 그림.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, Color(0.66, 0.48, 0.10))        # 테두리(어두운 금)
	draw_circle(c, r * 0.80, Color(1.0, 0.80, 0.26))  # 본체(금)
	draw_circle(c, r * 0.46, Color(1.0, 0.92, 0.55))  # 안쪽 하이라이트
