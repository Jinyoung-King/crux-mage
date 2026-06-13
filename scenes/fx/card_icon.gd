extends Control
## 카드 종류 아이콘 — PNG 없이 단색 도형. set_kind(종류)로 모양·색 결정.

var kind := ""

func set_kind(k: String) -> void:
	kind = k
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.44
	match kind:
		"attack":  _tri(c, r, Color(1.0, 0.42, 0.36))        # 공격력 — 빨강 위삼각
		"power":   _diamond(c, r, Color(1.0, 0.62, 0.22))    # 스킬 위력 — 주황 다이아
		"speed":   _bolt(c, r, Color(1.0, 0.86, 0.32))       # 연사/쿨 — 노랑 번개
		"defense": _plus(c, r, Color(0.5, 0.86, 0.5))        # 방어·체력·회복 — 초록 +
		"explode": _burst(c, r, Color(1.0, 0.55, 0.2))       # 폭발 — 주황 폭발선
		"multi":   _dots(c, r, Color(0.95, 0.95, 1.0))       # 다발 — 흰 점 3개
		"fire":    _tri(c, r, Color(1.0, 0.45, 0.2))         # 화염 — 빨강 불꽃
		"frost":   _diamond(c, r, Color(0.5, 0.85, 1.0))     # 서리 — 청록 다이아
		# 속성 스킬 아이콘 (오행 색 + 상징 도형)
		"skill_fire":  _tri(c, r, ElementLib.color("fire"))          # 불 — 빨강 불꽃
		"skill_water": _diamond(c, r, ElementLib.color("water"))     # 물 — 파랑 물방울
		"skill_wood":  _leaf(c, r, ElementLib.color("wood"))         # 나무 — 초록 잎
		"skill_metal": _bolt(c, r, ElementLib.color("metal"))        # 쇠 — 은빛 번개
		"skill_earth": _square(c, r, ElementLib.color("earth"))      # 흙 — 황토 블록
		"skill":   draw_arc(c, r, 0.0, TAU, 32, Color(0.82, 0.56, 1.0), 4.0, true)  # 스킬(속성 없음) — 보라 고리
		_:         draw_circle(c, r * 0.5, Color(0.7, 0.7, 0.75))

func _tri(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.92, r * 0.7), c + Vector2(-r * 0.92, r * 0.7)]), col)

func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), col)

func _plus(c: Vector2, r: float, col: Color) -> void:
	var w := r * 0.42
	draw_rect(Rect2(c.x - w, c.y - r, w * 2.0, r * 2.0), col)
	draw_rect(Rect2(c.x - r, c.y - w, r * 2.0, w * 2.0), col)

func _bolt(c: Vector2, r: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(r * 0.3, -r), c + Vector2(-r * 0.2, 0), c + Vector2(r * 0.2, 0), c + Vector2(-r * 0.3, r)]), col, 4.0, true)

func _burst(c: Vector2, r: float, col: Color) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * r, col, 3.0)

func _dots(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.62, 0), r * 0.3, col)
	draw_circle(c, r * 0.3, col)
	draw_circle(c + Vector2(r * 0.62, 0), r * 0.3, col)

func _leaf(c: Vector2, r: float, col: Color) -> void:  # 세로로 긴 잎(나무)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, 0), c + Vector2(0, r), c + Vector2(-r * 0.55, 0)]), col)

func _square(c: Vector2, r: float, col: Color) -> void:  # 흙 블록
	draw_rect(Rect2(c.x - r * 0.8, c.y - r * 0.8, r * 1.6, r * 1.6), col)
