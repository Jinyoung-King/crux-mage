extends Control
## 홈(시작) 화면. 선택된 캐릭터 한 명만 크게 보여주고 ◀▶로 전환한다.
## 선택 캐릭터의 오행 속성색으로 배경·오라·강조 UI를 테마화.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const ELEMENT_AURA := preload("res://scenes/fx/element_aura.gd")
const NAV_BAR := preload("res://scenes/ui/nav_bar.gd")  # 공용 하단 네비(가운데 집 아이콘) — 모든 화면 일관

var view_chars: Array = []   # 해금된 캐릭터(◀▶ 순환 대상)
var view_pos: int = 0
var _xp_fill: StyleBoxFlat   # 숙련 게이지 채움(선택 속성색)
var _play_style: StyleBoxFlat  # 시작 버튼 배경(선택 속성색)

# 동적 생성 노드
var mage_view: TextureRect
var aura: Node2D
var name_lbl: Label
var elem_lbl: Label
var desc_lbl: Label
var prev_btn: Button
var next_btn: Button
var counter_panel: Control   # 오행 상성 도움말 오버레이
var goal_lbl: Label          # 다음 목표(도전 과제) 안내 — 플레이 버튼 직전
var tips_panel: Control      # 공략 팁 오버레이
var _asc_sel := 0            # 선택된 상승 계층(0~GameState.ascension)
var _asc_value_label: Label  # "상승 N / 해금" 표시
var _asc_rules_label: Label  # 선택 계층의 변형 규칙 요약

# 공략 팁 (도움말 오버레이) — 친구 피드백: 30웨이브 벽·상성/메커니즘 안내
const TIPS := [
	"상성: 목→토→수→화→금. 극하면 ×1.5, 당하면 ×0.7 (오행 상성표 참고).",
	"스킬 피해는 공격력에 비례합니다 — 공격력·스킬 강화에 투자하세요.",
	"연사는 쿨타임을 줄이고, 한계 도달 후엔 위력으로 전환돼 끝까지 유효합니다.",
	"광역 스킬(유성·융단폭격·가시밭)로 무리를 한 번에. 동시 적 50 상한이라 '순삭 화력'이 핵심.",
	"부여+격발을 묶으세요: 화상+기폭, 둔화+파쇄 = 폭발적 시너지.",
	"룬·강화·특성으로 매 판 영구히 강해집니다. 막히면 코인·룬에 투자하세요.",
	"보스·중간보스(HP바)는 화력을 집중. 카드 새로고침으로 빌드에 맞는 카드를 고르세요.",
	"금속 스킬(비도)로 둔화·젖은 적을 치면 감전 연쇄가 터집니다 — 물 스킬과 함께 끼우세요 (금+수 조합).",
]

@onready var bg: Node2D = $BgLayer/Background
@onready var char_view: VBoxContainer = $Center/CharView
@onready var play_button: Button = $Center/PlayButton
@onready var best_label: Label = $Center/BestLabel
@onready var start_wave_box: VBoxContainer = $Center/StartWaveBox
@onready var start_wave_label: Label = $Center/StartWaveBox/StartWaveLabel
@onready var start_wave_slider: HSlider = $Center/StartWaveBox/StartWaveSlider
@onready var mastery_box: VBoxContainer = $Center/MasteryBox
@onready var mastery_label: Label = $Center/MasteryBox/MasteryLabel
@onready var mastery_bar: ProgressBar = $Center/MasteryBox/MasteryBar

func _ready() -> void:
	Music.play_menu()
	$VersionLabel.text = GameState.VERSION  # 빌드 버전 표기(단일 출처)
	if OS.has_feature("web"):  # PWA 업데이트 배너는 홈에서만 표시(인게임 오탭으로 진행 유실 방지) + 수동 확인 버튼
		JavaScriptBridge.eval("window.cmOnHome&&window.cmOnHome()")
		_build_update_button()
	# 업데이트 후 첫 진입: 자동 전환 대신 상단에 '새 패치' 배지(탭하면 패치노트) — _build_patch_badge
	if GameState.best_wave > 0:
		best_label.text = "최고 Wave %d   ·   코인 %s" % [GameState.best_wave, NumFmt.compact(GameState.coins)]
	else:
		best_label.text = "첫 도전을 시작하세요"
	_build_goal_label()  # ▶ 다음 목표 — 플레이 직전에 '한 판 더'의 이유 제시
	# 해금된 캐릭터만 순환 대상
	for c in GameState.characters:
		if GameState.is_unlocked(c):
			view_chars.append(c)
	if view_chars.is_empty():
		view_chars = [GameState.characters[0]]
	view_pos = maxi(view_chars.find(GameState.selected), 0)
	_build_char_view()
	play_button.pressed.connect(_on_play)
	var nav = NAV_BAR.new()  # 공용 하단 네비(가운데 집 아이콘) — 모든 화면 일관
	add_child(nav)
	nav.setup("home")  # 홈 화면이므로 집 아이콘이 현재 탭(금색·비활성)
	# 시작 웨이브 다이얼: 1 ~ 최고 기록(1단위). 기록이 2 미만이면 숨김.
	if GameState.best_wave < 2:
		start_wave_box.hide()
		GameState.start_wave = 1
	else:
		start_wave_slider.max_value = GameState.best_wave
		start_wave_slider.value = clampi(GameState.start_wave, 1, GameState.best_wave)
		GameState.start_wave = int(start_wave_slider.value)
		start_wave_slider.value_changed.connect(_on_start_wave_changed)
		_refresh_start_wave()
	# 숙련 게이지 스타일 (채움 색은 _update_mastery에서 선택 속성색으로 갱신)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0, 0, 0, 0.4)
	xp_bg.set_corner_radius_all(5)
	_xp_fill = StyleBoxFlat.new()
	_xp_fill.set_corner_radius_all(5)
	mastery_bar.add_theme_stylebox_override("background", xp_bg)
	mastery_bar.add_theme_stylebox_override("fill", _xp_fill)
	# 시작 버튼 속성색 배경
	_play_style = StyleBoxFlat.new()
	_play_style.set_corner_radius_all(10)
	_play_style.set_border_width_all(3)
	play_button.add_theme_stylebox_override("normal", _play_style)
	play_button.add_theme_stylebox_override("hover", _play_style)
	play_button.add_theme_stylebox_override("pressed", _play_style)
	_build_stage_buttons()
	_build_beyond_button()  # 저편(엔드게임) 진입 — 최고 웨이브 30+ 해금
	_build_reverse_button()  # [실험] 리버스 모드 — 스쿼드 vs 마법사
	_apply_char()  # 텍스처·이름·속성색·배경·오라 적용
	_build_counter_help()  # 상성 오버레이(최상단으로 마지막에 추가)
	_build_tips_help()     # 공략 팁 오버레이
	_build_patch_badge()   # 미열람 새 패치가 있으면 상단 배지
	_build_save_button()   # 세이브 백업(내보내기/불러오기) 진입 — 전 플랫폼

## 수동 업데이트 확인 버튼(웹) — 우하단. 새 버전이 있으면 캐시 비우고 적용(재시작), 이미 최신이면 토스트 알림만(재시작 안 함).
func _build_update_button() -> void:
	var ub := _btn("업데이트 확인", 14)
	ub.flat = true
	ub.add_theme_color_override("font_color", Color(0.62, 0.72, 0.95))
	ub.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ub.offset_left = -160.0
	ub.offset_top = -144.0
	ub.offset_right = -10.0
	ub.offset_bottom = -116.0
	ub.pressed.connect(func() -> void: JavaScriptBridge.eval("window.cmCheckUpdate&&window.cmCheckUpdate()"))  # 최신이면 토스트만, 새 버전이면 적용
	add_child(ub)

## 세이브 백업 버튼(우하단, '업데이트 확인' 위) — 모든 플랫폼. 백업 코드 패널 진입.
func _build_save_button() -> void:
	var sb := _btn("세이브 백업", 14)
	sb.flat = true
	sb.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7))
	sb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sb.offset_left = -160.0
	sb.offset_top = -176.0
	sb.offset_right = -10.0
	sb.offset_bottom = -148.0
	sb.pressed.connect(_open_save_panel)
	add_child(sb)

## 공통 버튼 생성: 텍스트 + 폰트 + 크기 (flat·색·앵커·스타일박스 등 그 외는 호출부에서)
func _btn(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	return b

func _panel_button(text: String) -> Button:
	var b := _btn(text, 18)
	b.custom_minimum_size = Vector2(0, 44)
	return b

## 세이브 백업 패널 — 열 때마다 최신 코드로 구성. 내보내기(코드+복사) / 불러오기(붙여넣기+적용).
func _open_save_panel() -> void:
	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤 입력 차단
	panel.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(cc)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(580, 0)
	box.add_theme_constant_override("separation", 9)
	cc.add_child(box)
	box.add_child(_label("세이브 백업", 26, Color(0.7, 0.9, 0.78)))
	var note := Label.new()
	note.text = "코드를 복사해 메모장 등에 보관하세요. 기기를 바꾸거나 브라우저 데이터를 지워도 코드로 복원됩니다."
	note.add_theme_font_override("font", FONT)
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.74, 0.76, 0.82))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	box.add_child(note)
	var status := _label("", 16, Color(0.7, 0.95, 0.7))
	# 내보내기
	box.add_child(_label("내보내기 — 이 코드를 복사", 17, Color(0.85, 0.88, 0.95)))
	var out := TextEdit.new()
	out.text = GameState.export_code()
	out.editable = false
	out.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	out.custom_minimum_size = Vector2(560, 86)
	out.add_theme_font_override("font", FONT)
	out.add_theme_font_size_override("font_size", 12)
	box.add_child(out)
	var copy := _panel_button("복사")
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(out.text)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("navigator.clipboard&&navigator.clipboard.writeText('%s')" % out.text)
		status.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
		status.text = "복사됨 ✓")
	box.add_child(copy)
	# 불러오기
	box.add_child(_label("불러오기 — 코드 붙여넣기", 17, Color(0.85, 0.88, 0.95)))
	var inp := TextEdit.new()
	inp.placeholder_text = "여기에 백업 코드 붙여넣기"
	inp.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	inp.custom_minimum_size = Vector2(560, 66)
	inp.add_theme_font_override("font", FONT)
	inp.add_theme_font_size_override("font_size", 12)
	box.add_child(inp)
	var apply := _panel_button("적용 (현재 진행을 덮어씀)")
	apply.pressed.connect(func() -> void:
		if GameState.import_code(inp.text):
			get_tree().reload_current_scene()  # 복원된 코인·기록·해금 즉시 반영
		else:
			status.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
			status.text = "코드가 올바르지 않습니다")
	box.add_child(apply)
	box.add_child(status)
	var close := _panel_button("닫기")
	close.pressed.connect(panel.queue_free)
	box.add_child(close)
	add_child(panel)

## 업데이트 후 첫 진입: 미열람 새 버전이면 제목 아래 '새 패치' 배지(탭 → 패치노트, 열람 시 mark_version_seen으로 사라짐).
## 자동 전환(이전 방식) 대신 — 강제로 끌고 가지 않고 눈에 띄게만(피드백 반영).
func _build_patch_badge() -> void:
	if GameState.seen_version == GameState.VERSION:
		return  # 이미 본 버전 — 배지 없음
	var b := _btn("★ 새 패치 %s — 보기" % GameState.VERSION, 18)
	b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.95, 0.55, 0.2, 0.22)
	st.set_corner_radius_all(8)
	st.set_border_width_all(2)
	st.border_color = Color(1.0, 0.7, 0.3)
	st.set_content_margin_all(9)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/patch_notes.tscn"))
	$Center.add_child(b)
	$Center.move_child(b, 1)  # 제목 바로 아래로

## 캐릭터 뷰(◀ [오라+마법사] ▶ + 이름·속성·설명) 구성
func _build_char_view() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	prev_btn = _arrow("◀")
	prev_btn.pressed.connect(_cycle.bind(-1))
	row.add_child(prev_btn)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(200, 200)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura = ELEMENT_AURA.new()
	aura.position = Vector2(100, 100)
	stage.add_child(aura)
	mage_view = TextureRect.new()
	mage_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mage_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mage_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mage_view.size = Vector2(140, 140)
	mage_view.position = Vector2(30, 30)
	mage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(mage_view)
	row.add_child(stage)
	next_btn = _arrow("▶")
	next_btn.pressed.connect(_cycle.bind(1))
	row.add_child(next_btn)
	char_view.add_child(row)
	name_lbl = _label("", 34, Color.WHITE)
	char_view.add_child(name_lbl)
	elem_lbl = _label("", 18, Color.WHITE)
	char_view.add_child(elem_lbl)
	desc_lbl = _label("", 17, Color(0.82, 0.82, 0.88))
	char_view.add_child(desc_lbl)
	var info_btn := _btn("오행 상성표 ⓘ", 16)
	info_btn.flat = true
	info_btn.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	info_btn.pressed.connect(_show_counter_help)
	char_view.add_child(info_btn)
	var tips_btn := _btn("공략 팁 ⓘ", 16)
	tips_btn.flat = true
	tips_btn.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	tips_btn.pressed.connect(_show_tips_help)
	char_view.add_child(tips_btn)

## ▶ 다음 목표 라벨 — $Center에서 플레이 버튼 바로 앞에 배치('한 판 더'의 동기)
func _build_goal_label() -> void:
	var goal := GameState.current_goal()
	goal_lbl = _label("", 18, Color(1.0, 0.86, 0.4))  # 보상=금색
	if goal.is_empty():
		goal_lbl.text = "모든 목표 달성! 최고 기록에 도전하세요"
	else:
		goal_lbl.text = "▶ 다음 목표: %s  (+%s 코인)" % [goal.desc, NumFmt.compact(int(goal.coins))]
	$Center.add_child(goal_lbl)
	$Center.move_child(goal_lbl, play_button.get_index())

## 오행 상성 도움말 오버레이(오방색). 상성표 버튼 → 표시, 딤/닫기 → 숨김.
func _build_counter_help() -> void:
	counter_panel = Control.new()
	counter_panel.visible = false
	counter_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(counter_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_counter_dim)
	counter_panel.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -290.0
	panel.offset_right = 290.0
	panel.offset_top = -290.0
	panel.offset_bottom = 290.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.12, 0.18, 0.98)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(22)
	st.set_border_width_all(2)
	st.border_color = Color(0.42, 0.42, 0.52)
	panel.add_theme_stylebox_override("panel", st)
	counter_panel.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	v.add_child(_label("오행 상성 (오방색)", 30, Color(0.95, 0.96, 1.0)))
	v.add_child(_label("내 속성이 상대를 극하면 데미지 ×1.5,\n반대로 당하면 ×0.7", 16, Color(0.82, 0.85, 0.92)))
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(0, 6); v.add_child(spacer)
	# 상극 순환: 목→토→수→화→금→(목)
	var cycle := ["wood", "earth", "water", "fire", "metal"]
	for i in cycle.size():
		v.add_child(_counter_row(cycle[i], cycle[(i + 1) % cycle.size()]))
	var spacer2 := Control.new(); spacer2.custom_minimum_size = Vector2(0, 8); v.add_child(spacer2)
	var close := _btn("닫기", 22)
	close.custom_minimum_size = Vector2(200, 50)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_hide_counter_help)
	v.add_child(close)

## 상성 한 줄: [속성색 이름] → [속성색 이름]  강함
func _counter_row(a: String, b: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("%s 속성" % ElementLib.display_name(a), 22, ElementLib.color(a)))
	row.add_child(_label("→", 20, Color(0.7, 0.7, 0.78)))
	row.add_child(_label("%s 속성" % ElementLib.display_name(b), 22, ElementLib.color(b)))
	row.add_child(_label("에 강함", 16, Color(0.75, 0.78, 0.85)))
	return row

func _show_counter_help() -> void:
	counter_panel.show()

func _hide_counter_help() -> void:
	counter_panel.hide()

func _on_counter_dim(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_hide_counter_help()

## 공략 팁 오버레이. '공략 팁' 버튼 → 표시, 딤/닫기 → 숨김.
func _build_tips_help() -> void:
	tips_panel = Control.new()
	tips_panel.visible = false
	tips_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tips_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_tips_dim)
	tips_panel.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.offset_top = -360.0
	panel.offset_bottom = 360.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.12, 0.18, 0.98)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(22)
	st.set_border_width_all(2)
	st.border_color = Color(0.42, 0.42, 0.52)
	panel.add_theme_stylebox_override("panel", st)
	tips_panel.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 13)
	panel.add_child(v)
	v.add_child(_label("공략 팁", 30, Color(0.95, 0.96, 1.0)))
	for t in TIPS:
		v.add_child(_tip_row(t))
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(0, 6); v.add_child(spacer)
	var close := _btn("닫기", 22)
	close.custom_minimum_size = Vector2(200, 50)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_hide_tips_help)
	v.add_child(close)

## 팁 한 줄(왼쪽 정렬·자동 줄바꿈)
func _tip_row(text: String) -> Label:
	var l := _label("• " + text, 16, Color(0.85, 0.88, 0.94))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(566, 0)
	return l

func _show_tips_help() -> void:
	tips_panel.show()

func _hide_tips_help() -> void:
	tips_panel.hide()

func _on_tips_dim(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_hide_tips_help()

## 오행 속성별 오라 변 수(0=원). fire=3·water=0·wood=5·metal=4·earth=6
func _sides(elem: String) -> int:
	match elem:
		"fire": return 3
		"water": return 0
		"wood": return 5
		"metal": return 4
		_: return 6  # earth

## 현재 캐릭터를 화면 전체에 반영 (속성색 테마)
func _apply_char() -> void:
	var c: CharacterData = view_chars[view_pos]
	GameState.selected = c
	var col: Color = ElementLib.color(c.element)
	mage_view.texture = c.mage_sprite
	aura.setup(col, _sides(c.element), 86.0)
	name_lbl.text = c.display_name
	name_lbl.add_theme_color_override("font_color", col)
	elem_lbl.text = "%s 속성 · %s에 강함" % [ElementLib.display_name(c.element), ElementLib.strong_against(c.element)]
	elem_lbl.add_theme_color_override("font_color", col)
	desc_lbl.text = c.description
	# 배경 속성색 테마
	bg.set_theme_color(col)
	# 시작 버튼 속성색
	_play_style.bg_color = Color(col.r, col.g, col.b, 0.22)
	_play_style.border_color = col
	play_button.add_theme_color_override("font_color", Color.WHITE)
	# 제목 외곽선 속성색
	$Center/Title.add_theme_color_override("font_outline_color", Color(col.r, col.g, col.b, 0.9))
	# 화살표 속성색
	prev_btn.add_theme_color_override("font_color", col)
	next_btn.add_theme_color_override("font_color", col)
	prev_btn.visible = view_chars.size() > 1
	next_btn.visible = view_chars.size() > 1
	_update_mastery()

func _cycle(dir: int) -> void:
	view_pos = (view_pos + dir + view_chars.size()) % view_chars.size()
	_apply_char()

func _arrow(text: String) -> Button:
	var b := _btn(text, 34)
	b.flat = true
	b.custom_minimum_size = Vector2(52, 80)
	return b

func _on_start_wave_changed(v: float) -> void:
	GameState.start_wave = int(v)
	_refresh_start_wave()

func _refresh_start_wave() -> void:
	start_wave_label.text = "시작: Wave %d" % GameState.start_wave

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 선택 캐릭터의 숙련 Lv·전투력 보너스·exp 게이지 갱신
func _update_mastery() -> void:
	var c: CharacterData = GameState.selected
	mastery_box.show()
	var st: Array = GameState._xp_state(c)  # [레벨, 레벨 내 경험치, 다음 레벨 필요치]
	var mm := GameState.mastery_mult(c)
	var bonus := int(round((mm - 1.0) * 100.0))
	# 전투력 상세 — 숙련 배율(공격력·체력 동일 적용)을 실효값으로 표기. player.apply_character와 동일 식.
	var dmg := (c.base_damage + GameState.upgrade_value("damage", c) + GameState.kill_bonus_damage()) * mm * GameState.trait_damage_mult()
	var hp := (100.0 + GameState.upgrade_value("max_hp", c) + GameState.kill_bonus_hp()) * mm * GameState.trait_hp_mult()
	mastery_label.text = "%s 숙련 Lv %d · 전투력 +%d%%\n공격력 %s · 체력 %s · 레벨당 +%d%%" % [
		c.display_name, st[0], bonus,
		NumFmt.compact(int(round(dmg))), NumFmt.compact(int(round(hp))),
		int(round(GameState.MASTERY_PER_LEVEL * 100.0))]
	mastery_bar.max_value = st[2]
	mastery_bar.value = st[1]
	_xp_fill.bg_color = ElementLib.color(c.element)

func _on_play() -> void:  # 무한모드 (속성 순환, 끝없음)
	GameState.game_mode = "endless"
	GameState.run_ascension = 0  # 무한모드는 상승 계층 무관
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

## 속성 스테이지(유한 클리어 모드) 시작 — 고른 속성 + 선택한 상승 계층으로
func _on_stage(elem: String) -> void:
	GameState.game_mode = "stage"
	GameState.stage_element = elem
	GameState.run_ascension = clampi(_asc_sel, 0, GameState.ascension)
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

## 저편(엔드게임) — 로드아웃 준비 화면으로(거기서 정수 스킬 장착 후 '진입').
func _on_beyond() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/beyond_loadout.tscn")

## [실험] 리버스 모드 — 플레이어가 스쿼드를 보내고 마법사 AI가 방어(프로토타입)
func _on_reverse() -> void:
	GameState.game_mode = "reverse"
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _build_reverse_button() -> void:
	var b := _btn("⚔ 리버스 (실험)", 18)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_color_override("font_color", Color(1.0, 0.7, 0.45))
	$Center.add_child(b)
	b.pressed.connect(_on_reverse)

## 저편 진입 섹션 — 최고 웨이브 BEYOND_WAVE 이상에서만 해금(베테랑 게이트). 미달이면 조건 안내.
func _build_beyond_button() -> void:
	var lbl := _label("─ 저편 (멀티속성 여정 · 수동 조작) ─", 15, Color(0.74, 0.66, 0.92))
	$Center.add_child(lbl)
	if GameState.best_wave >= GameState.BEYOND_WAVE:
		var b := _btn("⟡ 저편 진입", 22)
		b.custom_minimum_size = Vector2(220, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.22, 0.46)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.74, 0.66, 0.92)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		$Center.add_child(b)
		b.pressed.connect(_on_beyond)
	else:
		var locked := _label("🔒 최고 웨이브 %d 도달 시 해금 (현재 %d)" % [GameState.BEYOND_WAVE, GameState.best_wave], 14, Color(0.6, 0.6, 0.66))
		$Center.add_child(locked)

## 상승 계층 선택기 — ◀ 상승 N ▶ + 규칙 요약. 해금(ascension>0) 시에만 표시.
func _build_ascension_selector() -> void:
	_asc_sel = clampi(_asc_sel, 0, GameState.ascension)  # 가능 범위로 클램프
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	$Center.add_child(row)
	var left := _arrow("◀")
	left.custom_minimum_size = Vector2(44, 44)
	left.add_theme_font_size_override("font_size", 24)
	row.add_child(left)
	left.pressed.connect(_on_asc_step.bind(-1))
	_asc_value_label = _label("", 20, Color(1.0, 0.82, 0.4))
	_asc_value_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(_asc_value_label)
	var right := _arrow("▶")
	right.custom_minimum_size = Vector2(44, 44)
	right.add_theme_font_size_override("font_size", 24)
	row.add_child(right)
	right.pressed.connect(_on_asc_step.bind(1))
	_asc_rules_label = _label("", 13, Color(0.78, 0.78, 0.84))
	_asc_rules_label.custom_minimum_size = Vector2(420, 0)
	_asc_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Center.add_child(_asc_rules_label)
	_update_asc_labels()

func _on_asc_step(d: int) -> void:
	_asc_sel = clampi(_asc_sel + d, 0, GameState.ascension)
	_update_asc_labels()

func _update_asc_labels() -> void:
	_asc_value_label.text = "상승 %d / %d" % [_asc_sel, GameState.ascension]
	if _asc_sel <= 0:
		_asc_rules_label.text = "변형 없음 (기본 난이도) · 클리어 시 다음 계층 해금"
	else:
		_asc_rules_label.text = "  ·  ".join(GameState.ascension_rules(_asc_sel)) + "   (코인 +%d%%)" % int(round(GameState.ASC_COIN_PER * _asc_sel * 100.0))

## 속성 스테이지 선택 버튼 5개(목·화·토·금·수) 생성
func _build_stage_buttons() -> void:
	var lbl := _label("─ 속성 스테이지 (유한 클리어) ─", 15, Color(0.72, 0.72, 0.78))
	$Center.add_child(lbl)
	if GameState.ascension > 0:  # 첫 클리어 전엔 선택기 숨김
		_build_ascension_selector()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	$Center.add_child(row)
	for elem in ["wood", "fire", "earth", "metal", "water"]:
		var b := _btn(ElementLib.display_name(elem), 22)
		b.custom_minimum_size = Vector2(52, 48)
		b.add_theme_color_override("font_color", ElementLib.color(elem))
		row.add_child(b)
		b.pressed.connect(_on_stage.bind(elem))
