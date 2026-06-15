extends Control
## 유물 뽑기: 코인으로 랜덤 유물을 뽑아 모은다. 중복은 레벨↑로 강화되고, 모은 유물은 전부 적용된다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const RUNE_ICON := preload("res://scenes/ui/rune_icon.gd")
const NAV_BAR := preload("res://scenes/ui/nav_bar.gd")  # 하단 탭 네비게이션(유지)
const ICON_PX := 64.0  # 룬 아이콘 크기(확대)

@onready var coin_label: Label = $Center/CoinLabel
@onready var result_label: Label = $Center/SlotLabel   # 재활용: 뽑기 결과/안내(금색)
@onready var rows: VBoxContainer = $Center/Rows
@onready var roll_button: Button = $Center/SlotButton   # 재활용: 뽑기 버튼
@onready var back_button: Button = $Center/BackButton

var grid: GridContainer  # 룬 그리드(3열)
var row_cells := {}      # id → {name, eff, icon}
var free_button: Button  # 일일 무료 뽑기 버튼(코드 생성, 뽑기 버튼 아래)

func _ready() -> void:
	Music.play_menu()
	$Center/Title.text = "룬 뽑기"
	back_button.hide()  # 뒤로 제거 — 하단 nav '홈'으로 복귀
	roll_button.pressed.connect(_on_roll)
	# 일일 무료 뽑기 버튼(초록 강조) — 코인 비싸진 후반에도 매일 1회 무료로 룬 획득
	free_button = Button.new()
	free_button.add_theme_font_override("font", FONT)
	free_button.add_theme_font_size_override("font_size", 20)
	free_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	free_button.custom_minimum_size = Vector2(260, 50)
	var fst := StyleBoxFlat.new()
	fst.bg_color = Color(0.3, 0.7, 0.4, 0.28)
	fst.set_corner_radius_all(10)
	fst.set_border_width_all(2)
	fst.border_color = Color(0.5, 0.85, 0.55)
	fst.set_content_margin_all(8)
	free_button.add_theme_stylebox_override("normal", fst)
	free_button.add_theme_stylebox_override("hover", fst)
	free_button.add_theme_stylebox_override("pressed", fst)
	free_button.add_theme_color_override("font_color", Color(0.7, 1.0, 0.78))
	free_button.pressed.connect(_on_free_roll)
	$Center.add_child(free_button)
	$Center.move_child(free_button, roll_button.get_index() + 1)  # 뽑기 버튼 바로 아래
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(grid)
	for r in RelicLib.RELICS:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(176, 0)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 2)
		var icon = RUNE_ICON.new()
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.setup(r.id, r.get("color", Color.WHITE), true, ICON_PX)
		cell.add_child(icon)
		var name_lbl := _label("", 16, Color(0.92, 0.94, 1.0))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_lbl)
		var eff_lbl := _label("", 13, Color(0.7, 0.74, 0.85))
		eff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff_lbl.custom_minimum_size = Vector2(168, 0)
		cell.add_child(eff_lbl)
		grid.add_child(cell)
		row_cells[r.id] = {"name": name_lbl, "eff": eff_lbl, "icon": icon}
	result_label.text = "코인으로 룬을 뽑아 모으세요 (중복은 강화)"
	_refresh()
	var nav := NAV_BAR.new()  # 하단 탭 네비게이션 유지
	add_child(nav)
	nav.setup("relic")

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _on_roll() -> void:
	var res := GameState.roll_relic()
	if res.is_empty():
		result_label.text = "코인이 부족합니다 (%s 필요)" % NumFmt.compact(GameState.current_roll_cost())
		return
	var nm: String = RelicLib.relic_def(res.id).name
	result_label.text = ("%s 획득! (Lv %d)" % [nm, res.level]) if res.is_new else ("%s 강화! (Lv %d)" % [nm, res.level])
	_refresh()

func _on_free_roll() -> void:
	var res := GameState.free_roll_relic()
	if res.is_empty():
		result_label.text = "오늘의 무료 뽑기는 이미 받았어요 — 내일 다시!"
		return
	var nm: String = RelicLib.relic_def(res.id).name
	result_label.text = ("★ 무료 뽑기: %s 획득! (Lv %d)" % [nm, res.level]) if res.is_new else ("★ 무료 뽑기: %s 강화! (Lv %d)" % [nm, res.level])
	_refresh()

func _refresh() -> void:
	coin_label.text = "보유 코인 %s" % NumFmt.compact(GameState.coins)
	roll_button.text = "룬 뽑기 (%s코인)" % NumFmt.compact(GameState.current_roll_cost())
	roll_button.disabled = not GameState.can_roll_relic()
	if GameState.can_free_roll():
		free_button.text = "★ 오늘의 무료 뽑기"
		free_button.disabled = false
	else:
		free_button.text = "무료 뽑기 완료 · 내일 다시"
		free_button.disabled = true
	for r in RelicLib.RELICS:
		var lv := GameState.relic_level(r.id)
		var c = row_cells[r.id]
		c["icon"].setup(r.id, r.get("color", Color.WHITE), lv <= 0, ICON_PX)  # 미보유는 흐리게
		if lv > 0:
			c["name"].text = "%s Lv%d" % [r.name, lv]
			c["eff"].text = RelicLib.effect_text(r.id, lv)
			c["name"].modulate = Color(1, 1, 1)
			c["eff"].modulate = Color(1, 1, 1)
		else:
			c["name"].text = r.name
			c["eff"].text = "미보유"
			c["name"].modulate = Color(0.5, 0.5, 0.55)
			c["eff"].modulate = Color(0.5, 0.5, 0.55)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
