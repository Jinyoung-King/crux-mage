extends Node2D
## 스킬 광역 범위를 잠깐 보여주는 확장 링. position 지정 후 setup(radius, color) 호출.
var radius := 80.0

func setup(r: float, c: Color) -> void:
	radius = maxf(r, 24.0)
	modulate = Color(c.r, c.g, c.b, 0.9)
	queue_redraw()

func _ready() -> void:
	scale = Vector2(0.45, 0.45)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(1, 1, 1, 0.95), 5.0, true)
