extends Node2D
## 수호 비행체가 적탄을 막은 자리 — 청색 '보호막 링'이 팟 퍼지며 사라진다.
## 흩어지는 입자보다 '막혔다'가 한눈에 들어오는 직관적 차단 표시.

var _col := Color(0.55, 0.9, 1.0)

func _ready() -> void:
	z_index = 8  # 적·발사체 위
	scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.24).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _draw() -> void:
	# 이중 보호막 링 + 흰 코어
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 28, Color(_col.r, _col.g, _col.b, 0.9), 3.5, true)
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 22, Color(1, 1, 1, 0.75), 2.0, true)
	draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.85))
