extends Control
## 저편 준비(로드아웃) — 정수로 스킬 해금 + 장착(캐릭터 고유 스킬 + 최대 BEYOND_SLOTS), '저편 진입'.
## 속성별 카드 그리드(스킬 도감과 동일 레이아웃) + 카드마다 해금/장착/해제 액션.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const ELEM_ORDER := ["wood", "fire", "earth", "metal", "water"]

@onready var grid: VBoxContainer = $Center/Scroll/Grid

func _ready() -> void:
	Music.play_menu()
	$Center/Title.text = "저편 준비"
	$Center/EnterButton.pressed.connect(_on_enter)
	$Center/BackButton.pressed.connect(_on_back)
	_rebuild()

func _on_enter() -> void:
	GameState.game_mode = "beyond"
	GameState.run_ascension = 0
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")

## 상태 변화(해금·장착)마다 화면 전체를 다시 그림 — 잔액·슬롯·버튼 즉시 반영.
func _rebuild() -> void:
	for c in grid.get_children():
		c.queue_free()
	$Center/Balance.text = "정수 %d   ·   추가 스킬 %d / %d   (+ 고유 1)" % [GameState.essence, GameState.beyond_loadout.size(), GameState.BEYOND_SLOTS]
	var sig_id: String = GameState.selected.skill_id if GameState.selected else ""
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id in by_elem[elem]:
			row.add_child(_make_card(id, sig_id))
		grid.add_child(row)

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

## 스킬 카드 — 속성색 프레임 + 이름·수치 + 액션(고유 뱃지 / 해금 / 장착 / 해제)
func _make_card(id: String, sig_id: String) -> Control:
	var def: Dictionary = SkillLib.DEFS[id]
	var elem: String = str(def.get("element", ""))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 9)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var ic := ColorRect.new()
	ic.color = ElementLib.color(elem)
	ic.custom_minimum_size = Vector2(34, 34)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ic)
	var nm := _label(str(def.get("name", "스킬")), 18, Color(1, 1, 1))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	# 수치
	var detail: String
	if id == "barrier_droid":
		detail = "지속형 · 비행체 %d기" % int(def.get("count", 2))
	else:
		detail = "피해 %d · 쿨 %.1f초" % [int(def.get("power", 0)), float(def.get("cooldown", 0.0))]
		if int(def.get("count", 0)) > 0:
			detail += " · %d발" % int(def.get("count", 0))
		elif float(def.get("radius", 0.0)) > 0.0:
			detail += " · 광역"
	var dl := _label(detail, 13, Color(0.86, 0.8, 0.6))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(dl)
	# 액션
	box.add_child(_make_action(id, sig_id))
	return panel

func _make_action(id: String, sig_id: String) -> Control:
	if id == sig_id:
		return _label("고유 · 항상 장착", 14, Color(0.6, 0.95, 0.7))
	var btn := Button.new()
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 15)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id in GameState.beyond_loadout:
		btn.text = "✓ 장착됨 — 해제"
		btn.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
		btn.pressed.connect(func() -> void:
			GameState.toggle_beyond_loadout(id)
			_rebuild())
	elif id in GameState.beyond_unlocked_skills:
		if GameState.beyond_loadout.size() >= GameState.BEYOND_SLOTS:
			btn.text = "슬롯 가득"
			btn.disabled = true
		else:
			btn.text = "장착"
			btn.pressed.connect(func() -> void:
				GameState.toggle_beyond_loadout(id)
				_rebuild())
	else:
		btn.text = "🔒 정수 %d" % GameState.BEYOND_SKILL_COST
		if GameState.essence < GameState.BEYOND_SKILL_COST:
			btn.disabled = true
		else:
			btn.pressed.connect(func() -> void:
				if GameState.unlock_beyond_skill(id):
					GameState.toggle_beyond_loadout(id)  # 해금 즉시 장착(슬롯 있으면)
				_rebuild())
	return btn

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
