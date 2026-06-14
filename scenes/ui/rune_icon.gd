extends Control
## 룬 아이콘: 돌판 위에 룬마다 고유 글리프(각진 선 획 — '새긴 룬' 느낌)를 그린다.
## setup(id, color, dimmed)로 문양·색 지정. 좌표는 0~1 정규화(획 = [x1,y1,x2,y2,...] 폴리라인).

const GLYPHS := {
	"execute": [[0.32, 0.18, 0.5, 0.82], [0.5, 0.82, 0.72, 0.5]],                    # 수확: 낫(세로획+갈고리)
	"chain":   [[0.3, 0.2, 0.55, 0.45, 0.35, 0.55, 0.62, 0.82]],                     # 연쇄: 지그재그 사슬
	"ignite":  [[0.5, 0.18, 0.34, 0.62], [0.5, 0.18, 0.66, 0.62], [0.34, 0.62, 0.66, 0.62]],  # 점화: 불꽃 삼각
	"regen":   [[0.5, 0.22, 0.5, 0.78], [0.28, 0.5, 0.72, 0.5]],                     # 재생: 십자(생명)
	"greed":   [[0.5, 0.2, 0.74, 0.5, 0.5, 0.8, 0.26, 0.5, 0.5, 0.2]],               # 황금: 마름모(보석)
	"berserk": [[0.28, 0.24, 0.72, 0.76], [0.72, 0.24, 0.28, 0.76]],                 # 격노: X
	"bulwark": [[0.5, 0.2, 0.28, 0.8], [0.5, 0.2, 0.72, 0.8], [0.36, 0.56, 0.64, 0.56]],  # 방벽: 방패 A
	"twin":    [[0.4, 0.24, 0.4, 0.76], [0.6, 0.24, 0.6, 0.76]],                     # 쌍둥이: 두 기둥
	"vamp":    [[0.3, 0.32, 0.5, 0.8], [0.7, 0.32, 0.5, 0.8], [0.3, 0.32, 0.7, 0.32]],    # 흡혈: 핏방울 삼각(아래)
	"swift":   [[0.26, 0.3, 0.5, 0.5, 0.26, 0.7], [0.5, 0.3, 0.74, 0.5, 0.5, 0.7]],  # 신속: 이중 화살
	"split":   [[0.5, 0.82, 0.5, 0.5], [0.5, 0.5, 0.3, 0.24], [0.5, 0.5, 0.7, 0.24]],    # 분열: Y 분기
	"giant":   [[0.24, 0.76, 0.5, 0.28, 0.76, 0.76]],                                # 거인: 상승(^)
}

var glyph_id: String = ""
var col: Color = Color.WHITE
var dim: bool = false

func setup(id: String, color: Color, dimmed: bool = false) -> void:
	glyph_id = id
	col = color
	dim = dimmed
	custom_minimum_size = Vector2(46, 46)
	queue_redraw()

func _draw() -> void:
	var sz: Vector2 = size
	var c: Color = Color(0.42, 0.42, 0.48) if dim else col
	# 룬 돌판
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.12, 0.11, 0.16, 0.95), true)
	draw_rect(Rect2(Vector2.ZERO, sz), c.darkened(0.25), false, 2.0)
	# 글리프(획)
	for st in GLYPHS.get(glyph_id, []):
		var pts := PackedVector2Array()
		for i in range(0, st.size(), 2):
			pts.append(Vector2(st[i] * sz.x, st[i + 1] * sz.y))
		if pts.size() >= 2:
			draw_polyline(pts, c, 2.5, true)
