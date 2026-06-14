extends Control
## 강화 화면의 장비 슬롯 한 칸 — 등급 프레임 + 장비 도형을 절차적으로 그린다(단색 도형 placeholder).
## 탭하면 tapped(equip_id)를 발화. 강화 레벨이 오르면 등급 색·등급점이 상승.

signal tapped(equip_id: String)

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
# 등급(tier) 단계별 프레임 색 — 0:미강화 회색 → 5:금색
const TIER_COLORS := [
	Color(0.34, 0.34, 0.4),
	Color(0.55, 0.78, 0.55),
	Color(0.38, 0.66, 0.96),
	Color(0.72, 0.46, 0.96),
	Color(0.96, 0.5, 0.82),
	Color(0.98, 0.8, 0.32),
]

# 장비 도트 픽셀 도안 — '#'=기본색, 'o'=밝은색(보석/광택), '.'=빈칸. 모든 행은 같은 길이.
const PIXELS := {
	"staff": [
		"...ooo...",
		"..ooooo..",
		"...ooo...",
		"....#....",
		"....#....",
		"....#....",
		"....#....",
		"....#....",
		"....#....",
		"...###...",
	],
	"robe": [
		"...###...",
		"...###...",
		"..#####..",
		"..#####..",
		".#######.",
		".#######.",
		"#########",
		"#########",
		".#######.",
		"..#####..",
	],
	"boots": [
		".##......",
		".##......",
		".##......",
		".##......",
		".##......",
		".##......",
		".##......",
		".#####...",
		".######..",
		".######..",
	],
	"ring": [
		"...ooo...",
		"..##.##..",
		".##...##.",
		".#.....#.",
		".#.....#.",
		".##...##.",
		"..##.##..",
		"...###...",
	],
	"amulet": [
		"....#....",
		"....#....",
		"...ooo...",
		"..#####..",
		".#######.",
		"#########",
		".#######.",
		"..#####..",
		"...###...",
	],
}

var equip_id: String = ""
var shape_kind: String = ""
var base_color: Color = Color.WHITE
var level: int = 0
var tier: int = 0
var is_selected: bool = false
var can_up: bool = false

func setup(id: String, kind: String, color: Color) -> void:
	equip_id = id
	shape_kind = kind
	base_color = color
	custom_minimum_size = Vector2(96, 96)
	size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_state(lv: int, t: int, sel: bool, upgradable: bool) -> void:
	level = lv
	tier = t
	is_selected = sel
	can_up = upgradable
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(equip_id)

func _draw() -> void:
	var sz: Vector2 = size
	var frame: Color = TIER_COLORS[clampi(tier, 0, TIER_COLORS.size() - 1)]
	# 슬롯 배경
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.09, 0.09, 0.13, 0.95), true)
	# 장비 도형(중앙)
	_draw_equip(sz)
	# 등급 테두리(선택 시 굵고 밝게)
	var bw: float = 5.0 if is_selected else 3.0
	var fcol: Color = frame.lightened(0.25) if is_selected else frame
	draw_rect(Rect2(Vector2.ZERO, sz), fcol, false, bw)
	# 등급 점(tier개) — 상단 중앙. 폰트 비의존으로 등급을 표현
	for i in tier:
		draw_circle(Vector2(sz.x * 0.5 + (i - (tier - 1) * 0.5) * 11.0, 11.0), 3.5, frame.lightened(0.35))
	# 레벨(좌하)
	draw_string(FONT, Vector2(7, sz.y - 8), "Lv %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.92, 0.98))
	# 강화 가능 표시(우하 상향 삼각형)
	if can_up:
		var p: Vector2 = Vector2(sz.x - 14, sz.y - 13)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(-6, 4), p + Vector2(6, 4)]), Color(0.4, 0.95, 0.5))

## 장비 종류별 대표 도형 (placeholder 수준 — 알아볼 정도)
func _draw_equip(sz: Vector2) -> void:
	var rows: Array = PIXELS.get(shape_kind, [])
	if rows.is_empty():
		return
	var h: int = rows.size()
	var w: int = (rows[0] as String).length()
	var cell: float = minf(sz.x, sz.y) * 0.62 / float(maxi(w, h))  # 슬롯의 ~62%를 차지
	var ox: float = (sz.x - w * cell) * 0.5
	var oy: float = (sz.y - h * cell) * 0.5 - sz.y * 0.05  # 살짝 위로(하단 레벨 텍스트 공간)
	var light: Color = base_color.lightened(0.35)
	for r in h:
		var line: String = rows[r]
		for col in line.length():
			var ch: String = line[col]
			if ch == ".":
				continue
			var cc: Color = light if ch == "o" else base_color
			draw_rect(Rect2(ox + col * cell, oy + r * cell, cell + 0.6, cell + 0.6), cc)  # +0.6: 셀 사이 틈 방지
