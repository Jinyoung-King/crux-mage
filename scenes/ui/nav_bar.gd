extends PanelContainer
## 하단 탭 네비게이션(공용) — 메타 화면에서 탭 간 즉시 이동. 시작 화면 NavBar와 동일 구성·해금 기준.
## 부모 화면 _ready에서 add_child 후 setup("<current_id>") 호출 → 현재 탭은 금색·비활성으로 강조.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const HOME_ICON := preload("res://scenes/ui/home_icon.gd")  # 가운데 집 아이콘

# 탭: id / 라벨 / 씬 경로 / 해금 임계 wave(0=항상 노출). 시작 화면 TAB_UNLOCKS와 동일 기준.
# '홈'은 가운데 집 아이콘으로 — 시작 화면에선 현재 탭(강조), 다른 화면에선 시작 화면 복귀.
const TABS := [
	{"id": "upgrade",  "label": "강화", "scene": "res://scenes/ui/meta_upgrade.tscn", "wave": 0},
	{"id": "trait",    "label": "특성", "scene": "res://scenes/ui/traits.tscn",        "wave": 5},
	{"id": "home",     "label": "",     "scene": "res://scenes/ui/start_screen.tscn",  "wave": 0},
	{"id": "relic",    "label": "룬",   "scene": "res://scenes/ui/relic_manage.tscn",  "wave": 8},
	{"id": "bestiary", "label": "도감", "scene": "res://scenes/ui/bestiary.tscn",      "wave": 3},
	{"id": "patch",    "label": "패치", "scene": "res://scenes/ui/patch_notes.tscn",   "wave": 0},
]

## current_id = 지금 보고 있는 탭(비활성·강조). 미해금 탭은 숨김(시작 화면과 동일 기준).
func setup(current_id: String) -> void:
	# 화면 하단 가로 전체 고정(높이 76)
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = -76.0
	offset_right = 0.0
	offset_bottom = 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	for t in TABS:
		if int(t.wave) > 0 and GameState.best_wave < int(t.wave):
			continue  # 미해금 탭 숨김
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 22)
		var is_cur: bool = (t.id == current_id)
		if t.id == "home":  # 가운데 집 아이콘(텍스트 대신 절차적 집 그림)
			var icon := HOME_ICON.new()
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.col = Color(0.98, 0.85, 0.4) if is_cur else Color(0.92, 0.94, 1.0)  # 현재(홈 화면)면 금색
			b.add_child(icon)
		else:
			b.text = t.label
			if is_cur:
				b.add_theme_color_override("font_color_disabled", Color(0.98, 0.85, 0.4))  # 현재 탭 금색 강조
		if is_cur:
			b.disabled = true
		else:
			var scene: String = t.scene
			b.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene))
		row.add_child(b)
