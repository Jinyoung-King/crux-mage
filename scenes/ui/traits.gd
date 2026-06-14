extends Control
## 특성 화면: 전 캐릭터 공용 영구 성장. 특성 포인트(=누적 숙련 레벨−사용분)로 능력치를 올린다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const NAV_BAR := preload("res://scenes/ui/nav_bar.gd")  # 하단 탭 네비게이션(유지)

@onready var balance: Label = $Center/Balance
@onready var rows: VBoxContainer = $Center/Rows
@onready var back_button: Button = $Center/BackButton

var row_labels := {}   # id → 정보 Label
var row_buttons := {}  # id → 구매 Button

func _ready() -> void:
	Music.play_menu()
	$Center/Title.text = "특성"
	back_button.hide()  # 뒤로 제거 — 하단 nav '홈'으로 복귀
	var grid := GridContainer.new()  # 특성 카드 2열 그리드
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(grid)
	for t in GameState.TRAITS:
		grid.add_child(_make_card(t))
	_refresh()
	var nav := NAV_BAR.new()  # 하단 탭 네비게이션 유지
	add_child(nav)
	nav.setup("trait")

## 특성 1개 카드 — 이름·레벨·효과 + 구매 버튼(세로). 그리드 셀로 배치.
func _make_card(t: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.21, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var info := _label("", 18, Color(0.92, 0.94, 1.0))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(300, 0)
	v.add_child(info)
	row_labels[t.id] = info
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 46)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 19)
	btn.pressed.connect(_on_buy.bind(t.id))
	v.add_child(btn)
	row_buttons[t.id] = btn
	return panel

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _on_buy(id: String) -> void:
	if GameState.buy_trait(id):
		_refresh()

func _refresh() -> void:
	var avail := GameState.trait_points_available()
	balance.text = "특성 포인트 %d   ·   누적 숙련 %d" % [avail, GameState.trait_points_earned()]
	for t in GameState.TRAITS:
		var lv := GameState.trait_level(t.id)
		var val := GameState.trait_value(t.id)
		var disp: String
		if t.get("pct", false):
			disp = "+%d%%" % int(round(val * 100.0))
		else:
			disp = "+%.2f%s" % [val, t.get("suffix", "")]
		row_labels[t.id].text = "%s  (Lv %d/%d)\n%s\n현재 %s" % [t.name, lv, int(t.max), t.desc, disp]
		var btn: Button = row_buttons[t.id]
		if lv >= int(t.max):
			btn.text = "MAX"
			btn.disabled = true
		elif avail <= 0:
			btn.text = "포인트 부족"
			btn.disabled = true
		else:
			btn.text = "올리기 (1P)"
			btn.disabled = false

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
