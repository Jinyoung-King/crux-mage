extends Node2D
## 하늘에서 떨어지는 광역 스킬 비주얼(불덩이 머리 + 위로 향한 꼬리 잔상).
## setup(색, 반경) 후 호출 측에서 트윈으로 낙하시키고, 도달 시 폭발 처리 + queue_free.

var _col := Color.WHITE
var _r := 24.0
var _elem := "fire"

func setup(col: Color, r: float, elem := "fire") -> void:
	_col = col
	_r = r
	_elem = elem
	z_index = 60  # 적 위로 떨어지는 게 보이도록
	queue_redraw()

func _draw() -> void:
	# 위로 향한 꼬리(낙하 잔상) — 공통
	for i in range(1, 6):
		var y := -float(i) * _r * 0.8
		var rr := _r * (1.0 - float(i) * 0.16)
		if rr > 0.0:
			draw_circle(Vector2(0, y), rr, Color(_col.r, _col.g, _col.b, 0.45 - float(i) * 0.07))
	if _elem == "earth":
		_draw_boulder()  # 융단폭격: 픽셀 바위 덩어리
	else:
		_draw_meteor()   # 유성: 운석 + 불꽃 혀

## 운석 머리 — 둥근 본체 둘레로 픽셀 불꽃 혀가 삐죽, 가운데 밝은 코어
func _draw_meteor() -> void:
	var u := _r * 0.34
	draw_circle(Vector2.ZERO, _r, _col)
	for d in [Vector2(-1, -0.2), Vector2(1, -0.1), Vector2(-0.3, 0.9), Vector2(0.7, 0.6)]:
		var b: Vector2 = d.normalized() * _r * 0.7
		draw_rect(Rect2(b.x - u * 0.5, b.y - u * 0.5, u, u), Color(0.98, 0.55, 0.2))
	draw_circle(Vector2.ZERO, _r * 0.5, Color(1, 0.95, 0.7, 0.95))

## 바위 머리 — 픽셀 블록 덩어리(좌상 하이라이트 + 우하 그늘 + 삐죽 모서리)
func _draw_boulder() -> void:
	var u := _r * 0.5
	var hi := Color(minf(_col.r + 0.2, 1), minf(_col.g + 0.18, 1), minf(_col.b + 0.12, 1))
	var dk := Color(_col.r * 0.55, _col.g * 0.55, _col.b * 0.55)
	draw_rect(Rect2(-u * 1.4, -u * 0.3, u * 0.5, u * 0.7), _col)  # 좌측 삐죽 모서리
	draw_rect(Rect2(u * 0.9, -u * 0.2, u * 0.5, u * 0.6), _col)   # 우측 삐죽 모서리
	draw_rect(Rect2(-u, -u, 2.0 * u, 2.0 * u), _col)              # 본체
	draw_rect(Rect2(-u, -u, u, u), hi)                            # 좌상 하이라이트
	draw_rect(Rect2(0, 0, u, u), dk)                              # 우하 그늘
