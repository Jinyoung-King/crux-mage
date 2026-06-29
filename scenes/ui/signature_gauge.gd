class_name SignatureGauge
extends RefCounted
## [능동] 시그니처 충전 게이지 HUD 위젯 — main.gd에서 분리.
## build()로 HUD에 한 번 짓고, main._process가 update()로 매 프레임 갱신한다. host 결합 없음(파라미터로 받음).

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

var _gauge: Control      # 게이지 루트(스킬 아이콘 위, 준비되면 "탭하여 발동")
var _fill: ColorRect     # 채움(주력 속성색, 너비 ∝ 충전율)
var _label: Label        # 라벨(충전/준비 안내)
var _pulse := 0.0        # 준비 시 라벨 점멸용 위상
var _was_ready := false  # 직전 프레임 준비 여부 — 충전 완료 순간 1회 팝 알림용

func build(hud: Node) -> void:
	_gauge = Control.new()
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 게이지는 탭을 막지 않음(전장 탭이 통과해 시전)
	_gauge.anchor_left = 0.5; _gauge.anchor_right = 0.5
	_gauge.anchor_top = 1.0; _gauge.anchor_bottom = 1.0
	_gauge.offset_left = -150.0; _gauge.offset_right = 150.0
	_gauge.offset_top = -168.0; _gauge.offset_bottom = -132.0  # SkillUI(-126~-60) 바로 위
	_gauge.pivot_offset = Vector2(150.0, 18.0)  # 가운데 기준 — 충전 완료 팝 스케일용
	hud.add_child(_gauge)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.13, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gauge.add_child(bg)
	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.anchor_top = 0.0; _fill.anchor_bottom = 1.0
	_fill.offset_left = 0.0; _fill.offset_top = 0.0; _fill.offset_bottom = 0.0
	_gauge.add_child(_fill)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 18)
	_gauge.add_child(_label)

## 매 프레임 갱신: 충전율 막대 너비 + 준비/충전 라벨(준비 시 점멸·속성색).
func update(pl, delta: float, game_over: bool) -> void:
	if _gauge == null:
		return
	if game_over:
		_gauge.visible = false
		return
	_gauge.visible = true
	var elem: String = pl.signature_element()
	var col: Color = ElementLib.color(elem)
	var charge: float = pl.signature_charge
	var ready: bool = pl.signature_ready()
	_fill.offset_right = 300.0 * clampf(charge, 0.0, 1.0)  # 0~1 채움(과충전은 색으로 표현)
	if ready and not _was_ready:  # 방금 발동 가능 — 게이지 팝으로 알림(놓치지 않게)
		_gauge.scale = Vector2(1.18, 1.18)
		_gauge.create_tween().tween_property(_gauge, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_was_ready = ready
	if ready:
		_pulse += delta * 4.0
		var a: float = 0.65 + 0.35 * sin(_pulse)  # 점멸로 시선 유도
		var oc: float = clampf((charge - 1.0) / (pl.SIG_MAX - 1.0), 0.0, 1.0)  # 과충전 진행 0~1
		_fill.color = col.lerp(Color(1.0, 0.85, 0.3), oc)  # 과충전될수록 금빛으로
		_fill.color.a = 0.6
		if oc > 0.02:
			_label.text = "▶ 탭! 과충전 +%d%%" % int(round(oc * 100.0))  # 모을수록 강함 — 지금 쏠까/더 모을까
		else:
			_label.text = "▶ %s 시그니처 — 탭하여 발동" % ElementLib.display_name(elem)
		_label.add_theme_color_override("font_color", Color(1, 1, 1, a))
	else:
		_fill.color = Color(col.r, col.g, col.b, 0.40)
		_label.text = "시그니처 충전… %d%%" % int(round(charge * 100.0))
		_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9, 0.9))
