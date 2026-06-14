extends Control
## 몹 도감: 적 종류별 처치 수를 보여주고, 누적 처치 업적(영구 공격력·체력 보너스)을 표시한다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

@onready var grid: GridContainer = $Center/Scroll/Grid
@onready var summary: Label = $Center/Summary

func _ready() -> void:
	Music.play_menu()
	$Center/Title.text = "도감"
	$Center/BackButton.pressed.connect(_on_back)
	_refresh_summary()
	for ed in GameState.enemies:
		grid.add_child(_make_entry(ed))
	# 스킬 도감 섹션 (2열 그리드 → 헤더 + 빈 셀로 새 줄 시작)
	grid.add_child(_section_header("★ 스킬 도감"))
	grid.add_child(Control.new())
	for id in SkillLib.DEFS:
		grid.add_child(_make_skill_entry(id, SkillLib.DEFS[id]))

## 상단 요약: 총 처치 + 현재 업적 보너스 + 다음 마일스톤까지
func _refresh_summary() -> void:
	var total := GameState.total_kills()
	var dmg := int(GameState.kill_bonus_damage())
	var hp := int(GameState.kill_bonus_hp())
	summary.text = "총 처치 %d   ·   업적 보너스 공격력 +%d · 체력 +%d\n몹 종류마다 개별 집계 — 종류별로 많이 잡을수록 단계가 오릅니다" % [total, dmg, hp]

## 적 1종 도감 카드 (처치 0이면 미발견 실루엣 + ???)
func _make_entry(ed) -> Control:
	var key: String = ed.resource_path.get_file().get_basename()
	var n: int = int(GameState.kills.get(key, 0))
	var seen := n > 0

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 92)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 항목이 터치 드래그를 가로채지 않게 → ScrollContainer가 스크롤(웹·모바일)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.21, 0.92) if seen else Color(0.12, 0.11, 0.15, 0.92)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var icon := TextureRect.new()
	icon.texture = ed.sprite
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(60, 60)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not seen:
		icon.modulate = Color(0, 0, 0, 0.85)  # 미발견 실루엣
	box.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(info)
	info.add_child(_label(ed.display_name if seen else "???", 19, Color(1, 1, 1) if seen else Color(0.55, 0.55, 0.55)))
	if seen and ed.element != "":
		info.add_child(_label("%s 속성 · %s에 강함" % [ElementLib.display_name(ed.element), ElementLib.strong_against(ed.element)], 13, ElementLib.color(ed.element)))
	if seen:
		var tier := GameState.kill_tier_for(n)
		var nextm := GameState.next_kill_milestone_for(n)
		var prog: String = ("다음 %d마리" % (nextm - n)) if nextm > 0 else "최대"
		info.add_child(_label("처치 %d  ·  단계 ★%d (%s)" % [n, tier, prog], 15, Color(0.86, 0.8, 0.6)))
	else:
		info.add_child(_label("미발견", 15, Color(0.5, 0.5, 0.5)))
	return panel

## 스킬 도감 섹션 헤더(금색)
func _section_header(text: String) -> Label:
	var l := _label(text, 22, Color(1.0, 0.85, 0.4))
	return l

## 스킬 1종 도감 카드 — 속성색 프레임 + 이름·속성·기본 수치(스킬은 항상 공개)
func _make_skill_entry(id: String, def: Dictionary) -> Control:
	var elem: String = def.get("element", "")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 92)
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
	return panel

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 라벨이 드래그를 막지 않게(스크롤)
	return l

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
