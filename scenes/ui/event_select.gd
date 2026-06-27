extends Control
## 중간 이벤트 선택 패널(코드 빌드, HUD에 부착). open(title, flavor, choices)로 표시 → 선택 시 chosen(index).
## card_select와 별개 — 이벤트는 카드가 아니라 일반 선택지(제목 + 분위기글 + 버튼 N개).

signal chosen(index: int)

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

const AUTO_SECS := 10.0  ## 미선택 시 자동선택까지(실시간, 배속 무관)

var _picked := false
var _auto_until := 0     ## >0이면 자동선택까지 남은 벽시계 시각(ms)
var _auto_index := -1     ## 자동선택 대상 인덱스(보유 스킬 속성 우선 — main이 계산해 전달)
var _auto_label := ""
var _countdown: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_dt: float) -> void:
	if _auto_until <= 0 or _picked:
		return
	var rem: int = _auto_until - Time.get_ticks_msec()
	if rem <= 0:
		_pick(_auto_index)  # 10초 미선택 → 자동선택(보유 스킬 속성 우선)
	elif _countdown != null:
		_countdown.text = "%d초 후 자동 선택 → %s" % [ceili(rem / 1000.0), _auto_label]

## choices = [{label, desc, color(선택)}, ...]. auto_index>=0이면 10초 후 그 선택지로 자동.
func open(title: String, flavor: String, choices: Array, auto_index: int = -1) -> void:
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
		UIKit.style_button(b, c.get("color", Color(0.55, 0.62, 0.78)))  # 선택지색 카드 버튼
		b.add_theme_color_override("font_color", c.get("color", Color(0.92, 0.94, 1.0)))
		var desc: String = c.get("desc", "")
		b.text = c.get("label", "") + ("\n" + desc if desc != "" else "")
		b.pressed.connect(_pick.bind(i))
		v.add_child(b)
	if auto_index >= 0 and auto_index < choices.size():  # 10초 후 자동선택(보유 스킬 속성 우선)
		_auto_index = auto_index
		_auto_label = choices[auto_index].get("label", "")
		_auto_until = Time.get_ticks_msec() + int(AUTO_SECS * 1000.0)
		_countdown = _label("%d초 후 자동 선택 → %s" % [int(AUTO_SECS), _auto_label], 15, Color(0.78, 0.8, 0.92))
		v.add_child(_countdown)
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
