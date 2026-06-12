extends Control
## 유물 관리: 코인으로 영구 해금하고 런마다 장착(최대 RELIC_SLOTS개).

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

@onready var coin_label: Label = $Center/CoinLabel
@onready var slot_label: Label = $Center/SlotLabel
@onready var rows: VBoxContainer = $Center/Rows
@onready var back_button: Button = $Center/BackButton

var row_buttons := {}  # id → Button

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	for r in RelicLib.RELICS:
		_make_row(r)
	_refresh()

func _make_row(r: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(600, 62)
	row.add_theme_constant_override("separation", 12)

	var info := _label("%s\n%s" % [r.name, r.desc], 18, Color(0.92, 0.94, 1.0))
	info.custom_minimum_size = Vector2(410, 0)
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 56)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_button.bind(r.id))
	row.add_child(btn)
	row_buttons[r.id] = btn

	rows.add_child(row)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## 잠김 → 해금, 해금됨 → 장착/해제 토글
func _on_button(id: String) -> void:
	if not GameState.is_relic_unlocked(id):
		GameState.unlock_relic(id)
	else:
		GameState.toggle_relic(id)
	_refresh()

func _refresh() -> void:
	coin_label.text = "보유 코인 %d" % GameState.coins
	slot_label.text = "장착 %d / %d" % [GameState.equipped_relics.size(), GameState.relic_slots()]
	for r in RelicLib.RELICS:
		var btn: Button = row_buttons[r.id]
		if not GameState.is_relic_unlocked(r.id):
			btn.text = "해금 (%d)" % GameState.relic_cost(r.id)
			btn.disabled = not GameState.can_unlock_relic(r.id)
			btn.modulate = Color(1, 1, 1)
		elif GameState.is_relic_equipped(r.id):
			btn.text = "장착 해제"
			btn.disabled = false
			btn.modulate = Color(1.0, 0.85, 0.35)  # 장착 강조(금색)
		else:
			btn.text = "장착"
			btn.disabled = GameState.equipped_relics.size() >= GameState.relic_slots()
			btn.modulate = Color(1, 1, 1)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
