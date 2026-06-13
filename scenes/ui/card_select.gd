extends Control
## 웨이브 클리어 후 카드 중 1장을 고르는 UI.
## 희귀도에 따라 카드 프레임이 달라진다(일반=강철 테두리 / 희귀=금테+발광).

signal card_chosen(card)
signal reroll_requested  ## 드래프트당 무료 1회 — main이 새 카드를 뽑아 refill

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const GOLD := Color(1.0, 0.84, 0.4)
const STEEL := Color(0.62, 0.72, 0.88)
const LEGEND := Color(0.8, 0.52, 1.0)  ## 전설 등급(보라)

const AUTO_SECS := 10.0  ## 자동선택까지 대기 시간

@onready var buttons: Array = [$Center/Cards/Card1, $Center/Cards/Card2, $Center/Cards/Card3]
@onready var reroll_button: Button = $Center/RerollButton
@onready var auto_button: Button = $Center/AutoButton

var shown_cards: Array = []
var can_reroll := false
var auto_left := 0.0  ## >0이면 자동선택 카운트다운 진행 중

func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
	reroll_button.pressed.connect(_on_reroll_pressed)
	auto_button.pressed.connect(_on_auto_pressed)

func _process(delta: float) -> void:
	# 드래프트가 떠 있고 자동선택이 켜져 있으면 카운트다운 → 0이면 무작위 선택
	if not (visible and GameState.auto_card and auto_left > 0.0):
		return
	auto_left -= delta
	if auto_left <= 0.0:
		pick_random()
	else:
		_update_auto_label()

## 자동선택 카운트다운 (재)시작 — 켜져 있으면 10초, 꺼져 있으면 정지
func _start_auto() -> void:
	auto_left = AUTO_SECS if GameState.auto_card else 0.0
	_update_auto_label()

func _update_auto_label() -> void:
	if GameState.auto_card:
		auto_button.text = "자동선택: 켜짐 (%d초)" % ceili(auto_left)
	else:
		auto_button.text = "자동선택: 꺼짐"

func _on_auto_pressed() -> void:
	GameState.set_auto_card(not GameState.auto_card)  # 토글 + 영속 저장
	_start_auto()

## cards(CardData 배열, 최대 3장)를 꾸며서 표시 + 리롤 1회 초기화
func open(cards: Array) -> void:
	can_reroll = true
	reroll_button.disabled = false
	reroll_button.text = "다시 뽑기 (1회)"
	_render_cards(cards)
	show()
	# 패널 팝
	var center: Control = $Center
	center.pivot_offset = center.size / 2.0
	center.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(center, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_start_auto()  # 자동선택 카운트다운 시작(켜져 있을 때)

## 리롤: 카드만 교체 (리롤 1회는 이미 소진된 상태로 유지)
func refill(cards: Array) -> void:
	_render_cards(cards)
	_start_auto()  # 새 카드이므로 카운트다운 재시작

## 카드 버튼 스타일링 + 순차 등장(딜링 느낌)
func _render_cards(cards: Array) -> void:
	shown_cards = cards
	for i in buttons.size():
		var btn: Button = buttons[i]
		if i < cards.size():
			_style_card(btn, cards[i])
			btn.visible = true
		else:
			btn.visible = false
	for i in cards.size():
		buttons[i].modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.05 + 0.07 * i)
		t.tween_property(buttons[i], "modulate:a", 1.0, 0.18)

func _on_reroll_pressed() -> void:
	if not can_reroll:
		return
	can_reroll = false
	reroll_button.disabled = true
	reroll_button.text = "다시 뽑기 (소진)"
	reroll_requested.emit()

## 카드 한 장을 희귀도에 맞춰 꾸민다 (프레임 + 뱃지/이름/설명)
func _style_card(btn: Button, card) -> void:
	for c in btn.get_children():
		btn.remove_child(c)
		c.queue_free()
	btn.text = ""
	var rarity: String = card.rarity
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, _card_style(rarity, state == "hover" or state == "pressed"))

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

	var tier := _tier_color(rarity)
	box.add_child(_label(_tier_badge(rarity), 15, tier))
	box.add_child(_label(card.card_name, 23, tier if rarity != "common" else Color(0.95, 0.97, 1.0)))
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

func _tier_color(rarity: String) -> Color:
	if rarity == "legendary":
		return LEGEND
	if rarity == "rare":
		return GOLD
	return STEEL

func _tier_badge(rarity: String) -> String:
	if rarity == "legendary":
		return "★★ 전설"
	if rarity == "rare":
		return "★ 희귀"
	return "일반"

## 희귀도별 카드 프레임 StyleBox. hl=true면 호버/눌림 강조 변형.
func _card_style(rarity: String, hl: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if rarity == "legendary":
		sb.bg_color = Color(0.30, 0.16, 0.36) if hl else Color(0.23, 0.12, 0.30)
		sb.border_color = Color(0.95, 0.75, 1.0) if hl else LEGEND
		sb.set_border_width_all(4)
		sb.shadow_color = Color(0.8, 0.45, 1.0, 0.6)  # 보랏빛 발광
		sb.shadow_size = 18
	elif rarity == "rare":
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
	auto_left = 0.0  # 선택됨 — 카운트다운 정지
	hide()
	card_chosen.emit(shown_cards[index])

## 테스트용 자동선택: 정상 선택 경로(hide + emit)와 동일하게 무작위 1장
func pick_random() -> void:
	if not shown_cards.is_empty():
		_on_button_pressed(randi() % shown_cards.size())
