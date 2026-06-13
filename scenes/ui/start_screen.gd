extends Control
## 홈(시작) 화면. 선택된 캐릭터 한 명만 크게 보여주고 ◀▶로 전환한다.
## 선택 캐릭터의 오행 속성색으로 배경·오라·강조 UI를 테마화.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const ELEMENT_AURA := preload("res://scenes/fx/element_aura.gd")

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

@onready var bg: Node2D = $BgLayer/Background
@onready var char_view: VBoxContainer = $Center/CharView
@onready var play_button: Button = $Center/PlayButton
@onready var best_label: Label = $Center/BestLabel
@onready var upgrade_button: Button = $NavBar/Row/UpgradeButton
@onready var start_wave_box: VBoxContainer = $Center/StartWaveBox
@onready var start_wave_label: Label = $Center/StartWaveBox/StartWaveLabel
@onready var start_wave_slider: HSlider = $Center/StartWaveBox/StartWaveSlider
@onready var mastery_box: VBoxContainer = $Center/MasteryBox
@onready var mastery_label: Label = $Center/MasteryBox/MasteryLabel
@onready var mastery_bar: ProgressBar = $Center/MasteryBox/MasteryBar

func _ready() -> void:
	# 업데이트 후 첫 진입이면 패치노트를 먼저 보여줌(버전당 1회)
	if GameState.seen_version != GameState.VERSION:
		get_tree().change_scene_to_file("res://scenes/ui/patch_notes.tscn")
		return
	$VersionLabel.text = GameState.VERSION  # 빌드 버전 표기(단일 출처)
	if GameState.best_wave > 0:
		best_label.text = "최고 Wave %d   ·   코인 %s" % [GameState.best_wave, NumFmt.compact(GameState.coins)]
	else:
		best_label.text = "첫 도전을 시작하세요"
	# 해금된 캐릭터만 순환 대상
	for c in GameState.characters:
		if GameState.is_unlocked(c):
			view_chars.append(c)
	if view_chars.is_empty():
		view_chars = [GameState.characters[0]]
	view_pos = maxi(view_chars.find(GameState.selected), 0)
	_build_char_view()
	play_button.pressed.connect(_on_play)
	upgrade_button.pressed.connect(_on_upgrade)
	$NavBar/Row/PatchButton.pressed.connect(_on_patch)
	$NavBar/Row/RelicButton.pressed.connect(_on_relics)
	$NavBar/Row/BestiaryButton.pressed.connect(_on_bestiary)
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
	_apply_char()  # 텍스처·이름·속성색·배경·오라 적용

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
	var b := Button.new()
	b.text = text
	b.flat = true
	b.custom_minimum_size = Vector2(52, 80)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 34)
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
	var bonus := int(round((GameState.mastery_mult(c) - 1.0) * 100.0))
	mastery_label.text = "%s 숙련 Lv %d · 전투력 +%d%%" % [c.display_name, st[0], bonus]
	mastery_bar.max_value = st[2]
	mastery_bar.value = st[1]
	_xp_fill.bg_color = ElementLib.color(c.element)

func _on_play() -> void:  # 무한모드 (속성 순환, 끝없음)
	GameState.game_mode = "endless"
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

## 속성 스테이지(유한 클리어 모드) 시작 — 고른 속성으로
func _on_stage(elem: String) -> void:
	GameState.game_mode = "stage"
	GameState.stage_element = elem
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

## 속성 스테이지 선택 버튼 5개(목·화·토·금·수) 생성
func _build_stage_buttons() -> void:
	var lbl := _label("─ 속성 스테이지 (유한 클리어) ─", 15, Color(0.72, 0.72, 0.78))
	$Center.add_child(lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	$Center.add_child(row)
	for elem in ["wood", "fire", "earth", "metal", "water"]:
		var b := Button.new()
		b.text = ElementLib.display_name(elem)
		b.custom_minimum_size = Vector2(52, 48)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", ElementLib.color(elem))
		row.add_child(b)
		b.pressed.connect(_on_stage.bind(elem))

func _on_upgrade() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/meta_upgrade.tscn")

func _on_patch() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/patch_notes.tscn")

func _on_relics() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/relic_manage.tscn")

func _on_bestiary() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/bestiary.tscn")
