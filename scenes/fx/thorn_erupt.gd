extends Node2D
## 가시밭 시전 순간 — 픽셀 나무 가시가 바닥에서 '펑' 솟구쳤다 사라진다.
## position 지정 후 setup(radius). 탄성 팝업(작게→크게)으로 솟는 느낌.

var _r := 110.0

func setup(r: float) -> void:
	_r = maxf(r, 60.0)
	queue_redraw()

func _ready() -> void:
	z_index = 4  # 장판 위, 적과 비슷한 높이(솟는 느낌)
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # 솟구침
	tw.tween_interval(0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _draw() -> void:
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n) + (0.0 if i % 2 == 0 else 0.22)
		var rr := _r * (0.42 + 0.5 * float((i * 7) % 5) / 5.0)  # 의사난수 흩뿌림(결정적)
		_thorn(Vector2(cos(a), sin(a)) * rr)

## 큰 픽셀 나무 가시 1개(아래 굵고 위로 좁게 + 끝 하이라이트)
func _thorn(p: Vector2) -> void:
	var u := 4.0
	for r in 4:
		var w := float(4 - r) * u
		var c := Color(0.66, 0.50, 0.28) if r == 3 else Color(0.46, 0.30, 0.15)
		draw_rect(Rect2(p.x - w * 0.5, p.y - float(r + 1) * u, w, u), c)
