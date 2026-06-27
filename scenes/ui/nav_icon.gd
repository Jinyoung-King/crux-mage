extends Control
## 하단 네비 탭 아이콘 — 탭 종류별 단색 글리프(집·강화·도감·스킬·특성·룬·패치).
## kind 설정 후 부모 레이아웃에 넣으면 _draw가 영역(size)에 맞춰 그린다. 삼각분할 안전한 도형만 사용.

var kind := ""
var col := Color(0.9, 0.92, 1.0)

func set_icon(k: String, c: Color) -> void:
	kind = k; col = c; queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var cy := h * 0.5
	var r := minf(w, h) * 0.42
	match kind:
		"home":  # 집 — 지붕 삼각 + 본체
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - r, cy - r * 0.1), Vector2(cx, cy - r), Vector2(cx + r, cy - r * 0.1)]), col)
			draw_rect(Rect2(cx - r * 0.7, cy - r * 0.1, r * 1.4, r * 1.05), col)
			draw_rect(Rect2(cx - r * 0.22, cy + r * 0.35, r * 0.44, r * 0.6), Color(0.1, 0.1, 0.14))  # 문
		"upgrade":  # 강화 — 위로 향한 이중 갈매기(▲)
			var lw := r * 0.32
			for yo in [-r * 0.25, r * 0.4]:
				draw_polyline(PackedVector2Array([
					Vector2(cx - r * 0.8, cy + r * 0.35 + yo), Vector2(cx, cy - r * 0.45 + yo),
					Vector2(cx + r * 0.8, cy + r * 0.35 + yo)]), col, lw)
		"trait":  # 특성 — 굵은 플러스(스탯 강화)
			draw_rect(Rect2(cx - r * 0.22, cy - r, r * 0.44, r * 2.0), col)
			draw_rect(Rect2(cx - r, cy - r * 0.22, r * 2.0, r * 0.44), col)
		"bestiary":  # 도감 — 펼친 책(두 면 + 책등 틈)
			draw_rect(Rect2(cx - r * 0.92, cy - r * 0.75, r * 0.82, r * 1.5), col)
			draw_rect(Rect2(cx + r * 0.1, cy - r * 0.75, r * 0.82, r * 1.5), col)
			draw_rect(Rect2(cx - r * 0.06, cy - r * 0.75, r * 0.12, r * 1.5), Color(0.1, 0.1, 0.14))  # 책등
		"skill":  # 스킬 — 반짝임(세로·가로 얇은 마름모 교차)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, cy - r), Vector2(cx + r * 0.3, cy), Vector2(cx, cy + r), Vector2(cx - r * 0.3, cy)]), col)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - r, cy), Vector2(cx, cy - r * 0.3), Vector2(cx + r, cy), Vector2(cx, cy + r * 0.3)]), col)
		"relic":  # 룬/유물 — 보석(육각) + 가로 패싯선
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, cy - r), Vector2(cx + r * 0.85, cy - r * 0.35), Vector2(cx + r * 0.85, cy + r * 0.35),
				Vector2(cx, cy + r), Vector2(cx - r * 0.85, cy + r * 0.35), Vector2(cx - r * 0.85, cy - r * 0.35)]), col)
			draw_line(Vector2(cx - r * 0.85, cy - r * 0.35), Vector2(cx + r * 0.85, cy - r * 0.35), Color(0.1, 0.1, 0.14, 0.6), 2.0)
		"patch":  # 패치 — 문서(사각 + 텍스트 줄)
			draw_rect(Rect2(cx - r * 0.7, cy - r * 0.95, r * 1.4, r * 1.9), col)
			for i in 3:
				draw_rect(Rect2(cx - r * 0.45, cy - r * 0.5 + i * r * 0.5, r * 0.9, r * 0.14), Color(0.1, 0.1, 0.14))
		_:
			draw_circle(Vector2(cx, cy), r * 0.7, col)
