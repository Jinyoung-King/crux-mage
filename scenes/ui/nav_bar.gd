extends PanelContainer
## 하단 탭 네비게이션(공용) — 메타 화면에서 탭 간 즉시 이동. 시작 화면 NavBar와 동일 구성·해금 기준.
## 부모 화면 _ready에서 add_child 후 setup("<current_id>") 호출 → 현재 탭은 금색·비활성으로 강조.
## 레이아웃: [왼쪽 그룹(확장)] [홈(고정·가운데)] [오른쪽 그룹(확장)] → 어떤 탭이 숨겨져도 홈은 항상 정중앙.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const NAV_ICON := preload("res://scenes/ui/nav_icon.gd")  # 탭별 컬러 글리프 아이콘

# 탭: id / 라벨 / 씬 경로 / 해금 임계 wave(0=항상 노출) / 아이콘색.
const TABS := [
	{"id": "upgrade",  "label": "강화", "scene": "res://scenes/ui/meta_upgrade.tscn", "wave": 0, "col": Color(0.52, 0.72, 1.0)},
	{"id": "trait",    "label": "특성", "scene": "res://scenes/ui/traits.tscn",        "wave": 5, "col": Color(0.55, 0.88, 0.55)},
	{"id": "bestiary", "label": "도감", "scene": "res://scenes/ui/bestiary.tscn",      "wave": 3, "col": Color(1.0, 0.8, 0.4)},
	{"id": "home",     "label": "홈",   "scene": "res://scenes/ui/start_screen.tscn",  "wave": 0, "col": Color(1.0, 0.85, 0.5)},
	{"id": "skill",    "label": "스킬", "scene": "res://scenes/ui/skill_dex.tscn",     "wave": 3, "col": Color(0.78, 0.62, 1.0)},
	{"id": "relic",    "label": "룬",   "scene": "res://scenes/ui/relic_manage.tscn",  "wave": 8, "col": Color(0.5, 0.86, 0.86)},
	{"id": "patch",    "label": "패치", "scene": "res://scenes/ui/patch_notes.tscn",   "wave": 0, "col": Color(0.82, 0.84, 0.95)},
]

## current_id = 지금 보고 있는 탭(비활성·강조). 미해금 탭은 숨김. 탭마다 아이콘+라벨, 현재 탭은 둥근 하이라이트.
func setup(current_id: String) -> void:
	# 화면 하단 가로 전체 고정(높이 80)
	anchor_left = 0.0; anchor_top = 1.0; anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = 0.0; offset_top = -80.0; offset_right = 0.0; offset_bottom = 0.0
	# 다크 바 배경
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(0.075, 0.07, 0.10, 0.97)
	bar.set_border_width(SIDE_TOP, 1)
	bar.border_color = Color(0.3, 0.3, 0.42, 0.5)
	add_theme_stylebox_override("panel", bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for t in TABS:
		if int(t.wave) > 0 and GameState.best_wave < int(t.wave):
			continue  # 미해금 탭 숨김
		var b := _make_tab(t, current_id)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)

## 탭 버튼 1개 — 아이콘(위·탭색) + 라벨(아래). 현재 탭은 둥근 하이라이트 + 흰 글자.
func _make_tab(t: Dictionary, current_id: String) -> Button:
	var is_cur: bool = (t.id == current_id)
	var tcol: Color = t.col
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 76)
	b.flat = true
	if is_cur:  # 현재 탭: 탭색 둥근 하이라이트
		var hl := UIKit.button_box(tcol, true)
		b.add_theme_stylebox_override("normal", hl)
		b.add_theme_stylebox_override("disabled", hl)
		b.disabled = true
	else:
		b.pressed.connect(func() -> void: get_tree().change_scene_to_file(String(t.scene)))
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var icon := NAV_ICON.new()
	icon.kind = t.id
	icon.col = tcol.lightened(0.2) if is_cur else tcol
	icon.custom_minimum_size = Vector2(0, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon)
	var lbl := Label.new()
	lbl.text = String(t.label)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE if is_cur else Color(0.68, 0.70, 0.80))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)
	return b
