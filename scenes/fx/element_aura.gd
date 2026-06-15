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
	rotation = _t * 0.5  # 천천히 회전(transform — 재그리기 없음)
	var pulse := 1.0 + 0.07 * sin(_t * 3.0)
	scale = Vector2(pulse, pulse)  # 맥동도 transform(scale)으로 — queue_redraw 제거(적 50마리 ×매프레임 _draw 부하 제거)

func _draw() -> void:
	var r := _radius  # 맥동은 scale, 회전은 rotation이 처리 → _draw는 1회만(setup) 실행
	# 반투명 글로우 원 제거(모바일 fill-rate 절감 — 적 다수 시 오버드로우가 렉 주범) → 외곽선만으로 속성 표시
	var line_col := Color(_col.r, _col.g, _col.b, 0.9)
	if _sides <= 0:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, line_col, 3.0, true)
	else:
		var pts := PackedVector2Array()
		for i in _sides + 1:
			var a := TAU * float(i) / float(_sides) - PI / 2.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, line_col, 3.0, true)
