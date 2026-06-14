extends Control
## 특성 화면: 전 캐릭터 공용 영구 성장. 특성 포인트(=누적 숙련 레벨−사용분)로 능력치를 올린다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

@onready var balance: Label = $Center/Balance
@onready var rows: VBoxContainer = $Center/Rows
@onready var back_button: Button = $Center/BackButton

var row_labels := {}   # id → 정보 Label
var row_buttons := {}  # id → 구매 Button

func _ready() -> void:
	Music.play_menu()
	$Center/Title.text = "특성"
	back_button.pressed.connect(_on_back)
	for t in GameState.TRAITS:
		_make_row(t)
	_refresh()

func _make_row(t: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(600, 56)
	row.add_theme_constant_override("separation", 12)
	var info := _label("", 20, Color(0.92, 0.94, 1.0))
	info.custom_minimum_size = Vector2(430, 0)
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(info)
	row_labels[t.id] = info
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 50)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_buy.bind(t.id))
	row.add_child(btn)
	row_buttons[t.id] = btn
	rows.add_child(row)

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
		row_labels[t.id].text = "%s  Lv %d/%d   ·   %s %s" % [t.name, lv, int(t.max), t.desc, disp]
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
