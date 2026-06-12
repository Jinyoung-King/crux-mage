extends Control
## 웨이브 클리어 후 카드 중 1장을 고르는 UI.
## 희귀도에 따라 카드 프레임이 달라진다(일반=강철 테두리 / 희귀=금테+발광).

signal card_chosen(card)

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const GOLD := Color(1.0, 0.84, 0.4)
const STEEL := Color(0.62, 0.72, 0.88)

@onready var buttons: Array = [$Center/Cards/Card1, $Center/Cards/Card2, $Center/Cards/Card3]

var shown_cards: Array = []

func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(_on_button_pressed.bind(i))

## cards(CardData 배열, 최대 3장)를 꾸며서 표시
func open(cards: Array) -> void:
	shown_cards = cards
	for i in buttons.size():
		var btn: Button = buttons[i]
		if i < cards.size():
			_style_card(btn, cards[i])
			btn.visible = true
		else:
			btn.visible = false
	show()
	# 패널 팝 + 카드 순차 등장(딜링 느낌)
	var center: Control = $Center
	center.pivot_offset = center.size / 2.0
	center.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(center, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in cards.size():
		buttons[i].modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.05 + 0.07 * i)
		t.tween_property(buttons[i], "modulate:a", 1.0, 0.18)

## 카드 한 장을 희귀도에 맞춰 꾸민다 (프레임 + 뱃지/이름/설명)
func _style_card(btn: Button, card) -> void:
	for c in btn.get_children():
		btn.remove_child(c)
		c.queue_free()
	btn.text = ""
	var rare: bool = card.rarity == "rare"
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, _card_style(rare, state == "hover" or state == "pressed"))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 14.0
	box.offset_top = 10.0
	box.offset_right = -14.0
	box.offset_bottom = -10.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)

	box.add_child(_label("★ 희귀" if rare else "일반", 15, GOLD if rare else STEEL))
	box.add_child(_label(card.card_name, 23, GOLD if rare else Color(0.95, 0.97, 1.0)))
	var desc := _label(card.description, 15, Color(0.78, 0.81, 0.86))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	btn.add_child(box)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## 희귀도별 카드 프레임 StyleBox. hl=true면 호버/눌림 강조 변형.
func _card_style(rare: bool, hl: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if rare:
		sb.bg_color = Color(0.30, 0.23, 0.11) if hl else Color(0.23, 0.17, 0.08)
		sb.border_color = Color(1.0, 0.9, 0.55) if hl else GOLD
		sb.set_border_width_all(3)
		sb.shadow_color = Color(1.0, 0.78, 0.3, 0.5)  # 금빛 발광
		sb.shadow_size = 12
	else:
		sb.bg_color = Color(0.19, 0.22, 0.30) if hl else Color(0.14, 0.16, 0.22)
		sb.border_color = Color(0.72, 0.82, 0.96) if hl else Color(0.5, 0.6, 0.78)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0.4, 0.5, 0.7, 0.3)
		sb.shadow_size = 6
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb

func _on_button_pressed(index: int) -> void:
	hide()
	card_chosen.emit(shown_cards[index])
