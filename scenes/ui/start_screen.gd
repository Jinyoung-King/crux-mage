extends Control
## 캐릭터 선택(컬렉션) 화면. 해금된 캐릭터를 골라 게임을 시작한다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

var selected_index := 0
var cards: Array = []

@onready var grid: GridContainer = $Center/Grid
@onready var play_button: Button = $Center/PlayButton
@onready var best_label: Label = $Center/BestLabel

func _ready() -> void:
	best_label.text = "최고 기록: Wave %d" % GameState.best_wave if GameState.best_wave > 0 else "첫 도전을 시작하세요"
	for i in GameState.characters.size():
		var card := _make_card(GameState.characters[i], i)
		grid.add_child(card)
		cards.append(card)
	selected_index = maxi(GameState.characters.find(GameState.selected), 0)
	if not GameState.is_unlocked(GameState.characters[selected_index]):
		selected_index = 0  # 해금된 캐릭터로 보정
	play_button.pressed.connect(_on_play)
	_refresh()

func _make_card(c: CharacterData, idx: int) -> Button:
	var unlocked := GameState.is_unlocked(c)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 188)
	btn.disabled = not unlocked
	btn.pressed.connect(_on_card_pressed.bind(idx))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)

	var icon := TextureRect.new()
	icon.texture = c.mage_sprite
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_lbl := _label(c.display_name if unlocked else "???", 22, c.accent_color if unlocked else Color(0.6, 0.6, 0.6))
	box.add_child(name_lbl)

	var info := c.description if unlocked else "Wave %d 도달 시 해금" % c.unlock_wave
	box.add_child(_label(info, 15, Color(0.8, 0.8, 0.8) if unlocked else Color(0.55, 0.55, 0.55)))

	if unlocked:
		var stats := "공%d · 연사%.1f · 표적%d · 관통%d" % [int(c.base_damage), c.base_fire_rate, c.base_projectile_count, c.base_pierce]
		box.add_child(_label(stats, 13, Color(0.7, 0.7, 0.75)))

	btn.add_child(box)
	return btn

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _on_card_pressed(idx: int) -> void:
	selected_index = idx
	_refresh()

func _refresh() -> void:
	for i in cards.size():
		var unlocked := GameState.is_unlocked(GameState.characters[i])
		if not unlocked:
			cards[i].modulate = Color(0.45, 0.45, 0.45)
		elif i == selected_index:
			cards[i].modulate = Color(1, 1, 1)
		else:
			cards[i].modulate = Color(0.7, 0.7, 0.7)

func _on_play() -> void:
	GameState.selected = GameState.characters[selected_index]
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
