class_name ComboMeter
extends RefCounted
## 연속 처치 콤보 HUD 위젯 — main.gd에서 분리.
## build()로 HUD에 라벨을 짓고, 처치 시 add(), 매 프레임 tick(delta), 웨이브 전환 등에서 reset().
## 마일스톤 연출(흔들림·화면 글로우)은 host(main)의 FX 파사드에 위임한다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const COMBO_WINDOW := 1.6  # 연속 처치 인정 시간(초, 게임시간) — 끊기면 콤보 리셋

var _host: Node       # main (마일스톤 흔들림·플래시 위임)
var _label: Label     # 화면 상단 "N 콤보!" 강조
var _combo := 0       # 현재 연속 처치 수
var _left := 0.0      # 콤보 유지 남은 시간

func build(host: Node) -> void:
	_host = host
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.anchor_left = 0.0; _label.anchor_right = 1.0
	_label.offset_top = 300.0; _label.offset_bottom = 372.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 46)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label.modulate.a = 0.0
	_label.pivot_offset = Vector2(360.0, 36.0)  # 화면 폭 720의 절반 — 가운데 기준 스케일 팝
	host.get_node("HUD").add_child(_label)

## 콤보 유지 시간 경과하면 리셋(끊김) — main._process에서 매 프레임 호출.
func tick(delta: float) -> void:
	if _combo > 0:
		_left -= delta
		if _left <= 0.0:
			reset()

## 처치 1회 — 콤보 누적. 창 안에 연속이면 숫자가 오르고 팝업·색이 세진다(2연속부터 표시).
func add() -> void:
	_combo += 1
	_left = COMBO_WINDOW
	if _combo < 2:
		return
	var col: Color
	if _combo >= 20: col = Color(1.0, 0.35, 0.30)
	elif _combo >= 10: col = Color(1.0, 0.60, 0.25)
	elif _combo >= 5: col = Color(1.0, 0.90, 0.40)
	else: col = Color(1.0, 1.0, 1.0)
	_label.text = "%d 콤보!" % _combo
	_label.add_theme_color_override("font_color", col)
	_label.modulate.a = 1.0
	var milestone: bool = _combo % 10 == 0
	_label.scale = Vector2(1.7, 1.7) if milestone else Vector2(1.3, 1.3)  # 마일스톤은 더 크게 팝
	_label.create_tween().tween_property(_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if milestone:  # 10·20·… 마일스톤: 흔들림 + 콤보색 화면 글로우(보상감) — host FX 파사드 위임
		_host._add_shake(5.0)
		_host.flash_overlay.color = Color(col.r, col.g, col.b, 0.16)
		_host.create_tween().tween_property(_host.flash_overlay, "color:a", 0.0, 0.45)

func reset() -> void:
	_combo = 0
	if _label:
		_label.create_tween().tween_property(_label, "modulate:a", 0.0, 0.3)
