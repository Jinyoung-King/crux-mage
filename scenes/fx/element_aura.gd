extends Node2D
## 적 속성 표시 — 속성 색 글로우 + 속성별 다각형 외곽선이 천천히 회전·맥동.
## 모양으로 오행 구분: fire=3(불꽃 삼각)·water=0(원/물방울)·wood=5(잎/오각)·metal=4(금속 마름모)·earth=6(흙 육각).
## setup(색, 변 수, 반경) 후 적의 본체 뒤에 배치.

var _col := Color.WHITE
var _sides := 0
var _radius := 30.0
var _t := 0.0

func setup(col: Color, sides: int, radius: float) -> void:
	_col = col
	_sides = sides
	_radius = maxf(radius, 14.0)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	rotation = _t * 0.5  # 천천히 회전(룬이 도는 느낌)
	queue_redraw()       # 맥동 반영

func _draw() -> void:
	var pulse := 1.0 + 0.07 * sin(_t * 3.0)
	var r := _radius * pulse
	# 부드러운 글로우(여러 겹 반투명 원) — 네모 대신 은은한 후광
	draw_circle(Vector2.ZERO, r * 1.05, Color(_col.r, _col.g, _col.b, 0.10))
	draw_circle(Vector2.ZERO, r * 0.82, Color(_col.r, _col.g, _col.b, 0.10))
	# 속성별 외곽선(원 또는 정다각형)
	var line_col := Color(_col.r, _col.g, _col.b, 0.82)
	if _sides <= 0:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, line_col, 3.0, true)
	else:
		var pts := PackedVector2Array()
		for i in _sides + 1:
			var a := TAU * float(i) / float(_sides) - PI / 2.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, line_col, 3.0, true)
