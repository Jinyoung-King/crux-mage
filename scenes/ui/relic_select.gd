extends Control
## 보스 처치 후 유물 1개를 고르는 UI (카드 선택과 비슷하되 금빛 유물 테마).

signal relic_chosen(id: String)

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const RELIC_COLOR := Color(0.97, 0.8, 0.38)  # 금빛 유물

@onready var buttons: Array = [$Center/Cards/Card1, $Center/Cards/Card2, $Center/Cards/Card3]

var shown: Array = []

func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(_on_pressed.bind(i))

func open(relics: Array) -> void:
	shown = relics
	for i in buttons.size():
		var btn: Button = buttons[i]
		if i < relics.size():
			_style(btn, relics[i])
			btn.visible = true
		else:
			btn.visible = false
	show()
	var center: Control = $Center
	center.pivot_offset = center.size / 2.0
	center.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(center, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in relics.size():
		buttons[i].modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.05 + 0.07 * i)
		t.tween_property(buttons[i], "modulate:a", 1.0, 0.18)

func _style(btn: Button, relic: Dictionary) -> void:
	for c in btn.get_children():
		btn.remove_child(c)
		c.queue_free()
	btn.text = ""
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, _frame(state == "hover" or state == "pressed"))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 14.0
	box.offset_top = 10.0
	box.offset_right = -14.0
	box.offset_bottom = -10.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.add_child(_label("◆ 유물", 15, RELIC_COLOR))
	box.add_child(_label(relic["name"], 22, RELIC_COLOR))
	var d := _label(relic["desc"], 15, Color(0.82, 0.84, 0.9))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(d)
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

## 유물 프레임 (금빛 발광)
func _frame(hl: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.27, 0.21, 0.10) if hl else Color(0.21, 0.16, 0.07)
	sb.border_color = Color(1.0, 0.9, 0.55) if hl else RELIC_COLOR
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0.97, 0.78, 0.35, 0.55)
	sb.shadow_size = 16
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb

func _on_pressed(index: int) -> void:
	hide()
	relic_chosen.emit(shown[index]["id"])
