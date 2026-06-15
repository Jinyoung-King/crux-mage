extends Control
## 집(홈) 아이콘 — 지붕 삼각 + 본체 사각 + 문. 버튼 위에 올려 클릭은 버튼이 처리(마우스 무시).
## 폰트 글리프 의존 없이 절차적으로 그려 어떤 폰트에서도 일관.

var col := Color(0.92, 0.94, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var s := minf(size.x, size.y) * 0.6  # 아이콘 한 변(여백 둠)
	var ox := (size.x - s) * 0.5
	var oy := (size.y - s) * 0.5
	var cx := ox + s * 0.5
	# 지붕(삼각)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, oy),
		Vector2(ox - s * 0.06, oy + s * 0.44),
		Vector2(ox + s + s * 0.06, oy + s * 0.44),
	]), col)
	# 본체(사각)
	draw_rect(Rect2(ox + s * 0.16, oy + s * 0.44, s * 0.68, s * 0.5), col)
	# 문(본체에 어두운 구멍)
	draw_rect(Rect2(cx - s * 0.11, oy + s * 0.62, s * 0.22, s * 0.32), Color(0.12, 0.12, 0.18))
