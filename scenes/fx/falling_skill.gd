extends Node2D
## 하늘에서 떨어지는 광역 스킬 비주얼(불덩이 머리 + 위로 향한 꼬리 잔상).
## setup(색, 반경) 후 호출 측에서 트윈으로 낙하시키고, 도달 시 폭발 처리 + queue_free.

var _col := Color.WHITE
var _r := 24.0

func setup(col: Color, r: float) -> void:
	_col = col
	_r = r
	z_index = 60  # 적 위로 떨어지는 게 보이도록
	queue_redraw()

func _draw() -> void:
	# 위로 향한 꼬리(낙하 잔상)
	for i in range(1, 6):
		var y := -float(i) * _r * 0.8
		var rr := _r * (1.0 - float(i) * 0.16)
		if rr > 0.0:
			draw_circle(Vector2(0, y), rr, Color(_col.r, _col.g, _col.b, 0.45 - float(i) * 0.07))
	# 머리(속성 색 + 밝은 코어)
	draw_circle(Vector2.ZERO, _r, _col)
	draw_circle(Vector2.ZERO, _r * 0.55, Color(1, 1, 1, 0.85))
