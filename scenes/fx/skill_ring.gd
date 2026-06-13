extends Node2D
## 스킬 광역 범위 링 — 글로우 디스크 + 이중 링이 회전하며 확장, 천천히 사라진다.
## position 지정 후 setup(radius, color) 호출.
var radius := 80.0
var _col := Color.WHITE

func setup(r: float, c: Color) -> void:
	radius = maxf(r, 24.0)
	_col = c
	modulate = Color(1, 1, 1, 1)
	queue_redraw()

func _ready() -> void:
	z_index = 40  # 적·장판 위, 데미지 숫자(100) 아래
	scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", 0.5, 0.7).set_trans(Tween.TRANS_SINE)  # 룬이 도는 느낌
	tw.tween_property(self, "modulate:a", 0.0, 0.52).set_delay(0.18).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _draw() -> void:
	var c := _col
	draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.16))               # 안쪽 채움 글로우
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.9), 6.0, true)  # 바깥 굵은 링
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 56, Color(1, 1, 1, 0.5), 3.0, true)  # 안쪽 밝은 링
