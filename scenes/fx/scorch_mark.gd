extends Node2D
## 메테오 착탄 그을음 자국 — 어두운 원과 방사 그을음이 잠깐 남았다 사라진다(순수 시각).
## position 지정 후 setup(radius).

var _r := 60.0

func setup(r: float) -> void:
	_r = maxf(r, 30.0)
	queue_redraw()

func _ready() -> void:
	z_index = -4  # 적 아래(장판과 비슷한 높이)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, _r, Color(0.12, 0.08, 0.06, 0.5))
	draw_circle(Vector2.ZERO, _r * 0.6, Color(0.04, 0.03, 0.02, 0.5))
	for i in 8:  # 방사 그을음 자국
		var a := TAU * float(i) / 8.0
		var tip := Vector2(cos(a), sin(a)) * _r * 1.15
		draw_line(Vector2.ZERO, tip, Color(0.1, 0.06, 0.04, 0.4), 3.0)
