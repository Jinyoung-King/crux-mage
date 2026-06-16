extends Control
## 스킬 도감(전용 탭): 속성별로 분류한 스킬 카드 그리드 + '▶ 이펙트' 미리보기. (도감에서 분리 — v3.6)
## 카드 형식 — 속성 헤더 아래 그 속성 스킬 2장을 가로로(EXPAND_FILL 50:50) 배치해 화면 폭을 넘지 않음.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const NAV_BAR := preload("res://scenes/ui/nav_bar.gd")
const ELEM_ORDER := ["wood", "fire", "earth", "metal", "water"]  # 오행 표시 순서

@onready var grid: VBoxContainer = $Center/Scroll/Grid

func _ready() -> void:
	Music.play_menu()
	$Center/Title.text = "스킬 도감"
	$Center/Summary.text = "속성별 스킬 · '▶ 이펙트'로 연출 미리보기"
	$Center/BackButton.hide()  # 하단 nav '홈'으로 복귀
	# 속성 → 스킬 id 목록 (DEFS 정의 순서 유지)
	var by_elem := {}
	for id in SkillLib.DEFS:
		var e: String = str(SkillLib.DEFS[id].get("element", ""))
		if not by_elem.has(e):
			by_elem[e] = []
		by_elem[e].append(id)
	for elem in ELEM_ORDER:
		if not by_elem.has(elem):
			continue
		grid.add_child(_elem_header(elem))
		var row := HBoxContainer.new()  # 속성별 스킬 카드들을 가로로 — EXPAND_FILL이라 폭을 균등 분할
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id in by_elem[elem]:
			row.add_child(_make_skill_card(id, SkillLib.DEFS[id]))
		grid.add_child(row)
	var nav := NAV_BAR.new()
	add_child(nav)
	nav.setup("skill")

## 속성 구분 헤더 — 속성색 점 + "○ 속성"
func _elem_header(elem: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := ColorRect.new()
	dot.color = ElementLib.color(elem)
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dot)
	box.add_child(_label("%s 속성" % ElementLib.display_name(elem), 22, ElementLib.color(elem)))
	return box

## 스킬 1종 카드(세로형) — 속성색 프레임 + 이름·속성 + 기본 수치 + 진화 분기 + 이펙트 버튼.
## 패널/컨테이너는 IGNORE(스크롤 드래그 보존), 버튼만 STOP(탭 가능).
func _make_skill_card(id: String, def: Dictionary) -> Control:
	var elem: String = str(def.get("element", ""))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 한 행의 카드들이 폭을 균등 분할
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL     # 같은 행은 가장 큰 카드 높이에 맞춤
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.21, 0.92)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(11)
	sb.set_border_width_all(2)
	sb.border_color = ElementLib.color(elem)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	# 헤더: 속성색 아이콘 + 이름
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 9)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var ic := ColorRect.new()  # 스킬은 스프라이트가 없어 속성색 사각으로 표시
	ic.color = ElementLib.color(elem)
	ic.custom_minimum_size = Vector2(38, 38)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ic)
	var nm := _label(str(def.get("name", "스킬")), 19, Color(1, 1, 1))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(nm)
	# 기본 수치
	var detail: String
	if id == "barrier_droid":
		detail = "지속형 · 비행체 %d기 · 적탄 소멸" % int(def.get("count", 2))
	else:
		detail = "피해 %d · 쿨 %.1f초" % [int(def.get("power", 0)), float(def.get("cooldown", 0.0))]
		if int(def.get("count", 0)) > 0:
			detail += " · %d발" % int(def.get("count", 0))
		elif float(def.get("radius", 0.0)) > 0.0:
			detail += " · 광역"
	var dl := _label(detail, 14, Color(0.86, 0.8, 0.6))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(dl)
	# 진화 분기
	var branches: Array = SkillLib.EVOLVE_BRANCHES.get(id, [])
	if not branches.is_empty():
		var names := []
		for b in branches:
			names.append(str(b.get("name", "")))
		var evo := _label("진화 ▸ " + " · ".join(names), 12, Color(0.72, 0.8, 0.96))
		evo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(evo)
	# '▶ 이펙트' 버튼 — 탭 시 연출 미리보기 오버레이(버튼은 STOP이라 패널 IGNORE와 무관하게 탭, 스크롤 보존)
	var fxbtn := Button.new()
	fxbtn.text = "▶ 이펙트"
	fxbtn.add_theme_font_override("font", FONT)
	fxbtn.add_theme_font_size_override("font_size", 14)
	fxbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fxbtn.pressed.connect(_open_skill_preview.bind(id, def))
	box.add_child(fxbtn)
	return panel

## 스킬 연출 미리보기 오버레이 — 중앙에서 반복 재생 + 닫기.
func _open_skill_preview(id: String, def: Dictionary) -> void:
	var elem: String = str(def.get("element", ""))
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.add_child(dim)
	var title := _label("%s  ·  %s 속성" % [def.get("name", "스킬"), ElementLib.display_name(elem)], 26, ElementLib.color(elem))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 150.0
	title.offset_bottom = 198.0
	ov.add_child(title)
	var hint := _label("효과 미리보기 — 반복 재생", 15, Color(0.7, 0.72, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_right = 1.0
	hint.offset_top = 204.0
	hint.offset_bottom = 230.0
	ov.add_child(hint)
	var fx = preload("res://scenes/ui/skill_fx_preview.gd").new()
	fx.position = Vector2(360, 620)
	fx.z_index = 5
	ov.add_child(fx)
	fx.setup(id, def)
	var close := Button.new()
	close.text = "닫기"
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 22)
	close.anchor_left = 0.5; close.anchor_right = 0.5
	close.anchor_top = 1.0; close.anchor_bottom = 1.0
	close.offset_left = -90.0; close.offset_right = 90.0
	close.offset_top = -150.0; close.offset_bottom = -98.0
	close.pressed.connect(ov.queue_free)
	ov.add_child(close)
	add_child(ov)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
