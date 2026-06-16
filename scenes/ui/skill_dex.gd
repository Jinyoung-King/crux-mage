extends Control
## 스킬 도감(전용 탭): 전체 스킬의 속성·수치·진화 트리 + '▶ 이펙트' 미리보기. (도감에서 분리 — v3.6)

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const NAV_BAR := preload("res://scenes/ui/nav_bar.gd")

@onready var grid: GridContainer = $Center/Scroll/Grid

func _ready() -> void:
	Music.play_menu()
	$Center/Title.text = "스킬 도감"
	$Center/Summary.text = "스킬별 수치·진화 분기 · '▶ 이펙트'로 연출 미리보기"
	$Center/BackButton.hide()  # 하단 nav '홈'으로 복귀
	for id in SkillLib.DEFS:
		grid.add_child(_make_skill_entry(id, SkillLib.DEFS[id]))
	var nav := NAV_BAR.new()
	add_child(nav)
	nav.setup("skill")

## 스킬 1종 카드 — 속성색 프레임 + 이름·속성·기본 수치 + 진화 분기 + 이펙트 미리보기 버튼
func _make_skill_entry(id: String, def: Dictionary) -> Control:
	var elem: String = def.get("element", "")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 116)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.21, 0.92)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(2)
	sb.border_color = ElementLib.color(elem)
	panel.add_theme_stylebox_override("panel", sb)
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var ic := ColorRect.new()  # 스킬은 스프라이트가 없어 속성색 사각으로 표시
	ic.color = ElementLib.color(elem)
	ic.custom_minimum_size = Vector2(48, 48)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(info)
	info.add_child(_label(def.get("name", "스킬"), 19, Color(1, 1, 1)))
	info.add_child(_label("%s 속성" % ElementLib.display_name(elem), 13, ElementLib.color(elem)))
	var detail: String
	if id == "barrier_droid":
		detail = "지속형 · 비행체 %d기 · 적탄 소멸" % int(def.get("count", 2))
	else:
		detail = "피해 %d · 쿨 %.1f초" % [int(def.get("power", 0)), float(def.get("cooldown", 0.0))]
		if int(def.get("count", 0)) > 0:
			detail += " · %d발" % int(def.get("count", 0))
		elif float(def.get("radius", 0.0)) > 0.0:
			detail += " · 광역"
	info.add_child(_label(detail, 15, Color(0.86, 0.8, 0.6)))
	var branches: Array = SkillLib.EVOLVE_BRANCHES.get(id, [])
	if not branches.is_empty():
		var names := []
		for b in branches:
			names.append(str(b.get("name", "")))
		var evo := _label("진화 ▸ " + " · ".join(names), 13, Color(0.72, 0.8, 0.96))
		evo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		evo.custom_minimum_size = Vector2(250, 0)
		info.add_child(evo)
	# '▶ 이펙트' 버튼 — 탭 시 연출 미리보기 오버레이(버튼은 STOP이라 패널 IGNORE와 무관하게 탭, 스크롤 보존)
	var fxbtn := Button.new()
	fxbtn.text = "▶ 이펙트"
	fxbtn.add_theme_font_override("font", FONT)
	fxbtn.add_theme_font_size_override("font_size", 14)
	fxbtn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
