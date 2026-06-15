extends Control
## 중간 이벤트 선택 패널(코드 빌드, HUD에 부착). open(title, flavor, choices)로 표시 → 선택 시 chosen(index).
## card_select와 별개 — 이벤트는 카드가 아니라 일반 선택지(제목 + 분위기글 + 버튼 N개).

signal chosen(index: int)

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

var _picked := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## choices = [{label, desc, color(선택)}, ...]
func open(title: String, flavor: String, choices: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤 클릭 차단
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = -250.0
	panel.offset_bottom = 250.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.12, 0.18, 0.98)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(22)
	st.set_border_width_all(2)
	st.border_color = Color(0.55, 0.48, 0.78)
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	v.add_child(_label(title, 30, Color(0.96, 0.9, 1.0)))
	if flavor != "":
		v.add_child(_label(flavor, 16, Color(0.78, 0.8, 0.92)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	v.add_child(sp)
	for i in choices.size():
		var c: Dictionary = choices[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(520, 60)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", c.get("color", Color(0.92, 0.94, 1.0)))
		var desc: String = c.get("desc", "")
		b.text = c.get("label", "") + ("\n" + desc if desc != "" else "")
		b.pressed.connect(_pick.bind(i))
		v.add_child(b)
	show()

func _pick(i: int) -> void:
	if _picked:
		return  # 중복 입력 방지
	_picked = true
	chosen.emit(i)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
