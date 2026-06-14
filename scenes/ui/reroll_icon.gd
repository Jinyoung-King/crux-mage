extends Button
## 카드별 새로고침(리롤) 아이콘 버튼 — 원형 화살표를 직접 그린다(폰트 글리프 비의존).
## card_select가 카드 우상단에 얹고, 누르면 그 카드 한 장만 다시 뽑는다.

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var c := size / 2.0
	var rr := minf(size.x, size.y)
	var hot := get_global_rect().has_point(get_global_mouse_position())
	# 칩 배경(원형)
	draw_circle(c, rr * 0.46, Color(0.12, 0.12, 0.17, 0.92))
	draw_arc(c, rr * 0.46, 0.0, TAU, 32, Color(1, 1, 1, 0.35 if hot else 0.22), 1.5, true)
	# 새로고침 화살표(가운데가 트인 원형 호 + 화살촉)
	var col := Color(1, 1, 1, 1) if hot else Color(0.9, 0.92, 1.0)
	var r := rr * 0.26
	var a1 := deg_to_rad(380.0)
	draw_arc(c, r, deg_to_rad(125.0), a1, 28, col, 2.4, true)
	var end := c + Vector2(cos(a1), sin(a1)) * r
	var tang := Vector2(-sin(a1), cos(a1))   # 진행(접선) 방향
	var radial := Vector2(cos(a1), sin(a1))  # 바깥 방향
	draw_colored_polygon(PackedVector2Array([end + tang * 6.0, end + radial * 4.5, end - radial * 4.5]), col)
