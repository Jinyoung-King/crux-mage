extends Node2D
## 명중·착탄 순간의 작은 별 섬광 — 절차적, 짧게 번쩍이고 사라진다(가독성: 작고 빠름).
## position 지정 후 setup(color, size). 8갈래 별(긴/짧은 교차) + 흰 코어.

var _col := Color.WHITE
var _size := 16.0

func setup(col: Color, size := 16.0) -> void:
	_col = col
	_size = size
	queue_redraw()

func _ready() -> void:
	z_index = 46  # 데미지 숫자 바로 아래, 적·이펙트 위
	rotation = randf() * TAU  # 매번 살짝 다른 각도
	scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.17).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _draw() -> void:
	var c := _col
	draw_circle(Vector2.ZERO, _size * 0.28, Color(1, 1, 1, 0.95))  # 흰 코어
	for i in 8:
		var a := TAU * float(i) / 8.0
		var long := i % 2 == 0  # 긴/짧은 갈래 교차 = 반짝이는 별
		_spike(a, _size * (1.0 if long else 0.45), _size * 0.1, Color(c.r, c.g, c.b, 0.85))

func _spike(a: float, length: float, hw: float, col: Color) -> void:
	var dir := Vector2(cos(a), sin(a))
	var perp := Vector2(-dir.y, dir.x) * hw
	draw_colored_polygon(PackedVector2Array([perp, -perp, dir * length]), col)
