extends Control
## 영구 강화 화면: 모은 코인으로 시작 스탯·추가 시작 카드를 영구 강화한다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

@onready var coin_label: Label = $Center/CoinLabel
@onready var rows: VBoxContainer = $Center/Rows
@onready var back_button: Button = $Center/BackButton

var row_labels := {}   # id → 정보 Label
var row_buttons := {}  # id → 구매 Button

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	var c := GameState.selected
	if c:
		$Center/Title.text = "%s 강화 · 숙련 Lv %d" % [c.display_name, GameState.char_level(c)]
	for def in GameState.UPGRADES:
		_make_row(def)
	_refresh()

func _make_row(def: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(580, 60)
	row.add_theme_constant_override("separation", 12)

	var info := _label("", 20, Color(0.92, 0.94, 1.0))
	info.custom_minimum_size = Vector2(400, 0)
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(info)
	row_labels[def["id"]] = info

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(168, 56)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_buy.bind(def["id"]))
	row.add_child(btn)
	row_buttons[def["id"]] = btn

	rows.add_child(row)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _on_buy(id: String) -> void:
	if GameState.buy_upgrade(id):
		_refresh()

func _refresh() -> void:
	coin_label.text = "보유 코인 %d" % GameState.coins
	for def in GameState.UPGRADES:
		var id: String = def["id"]
		var lv := GameState.upgrade_level(id)
		var bonus := GameState.upgrade_value(id)
		var bonus_str: String
		if id == "fire_rate":
			bonus_str = "%.1f" % bonus
		elif id == "lifesteal":
			bonus_str = str(int(round(bonus * 100.0)))  # 비율 → 퍼센트
		else:
			bonus_str = str(int(bonus))
		var mx := int(def["max"])
		var lv_str := ("Lv %d/%d" % [lv, mx]) if mx >= 0 else ("Lv %d" % lv)
		row_labels[id].text = "%s  %s  (현재 +%s%s)" % [def["name"], lv_str, bonus_str, def["suffix"]]
		var btn: Button = row_buttons[id]
		var cost := GameState.next_cost(id)
		if cost < 0:
			btn.text = "MAX"
			btn.disabled = true
		else:
			btn.text = "%d 코인" % cost
			btn.disabled = not GameState.can_buy(id)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
