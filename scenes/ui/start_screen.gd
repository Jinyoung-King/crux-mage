extends Control
## 캐릭터 선택(컬렉션) 화면. 해금된 캐릭터를 골라 게임을 시작한다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

var selected_index := 0
var cards: Array = []
var _xp_fill: StyleBoxFlat  # 숙련 게이지 채움 스타일(선택 캐릭터 accent 색)

@onready var grid: GridContainer = $Center/Grid
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
	for i in GameState.characters.size():
		var card := _make_card(GameState.characters[i], i)
		grid.add_child(card)
		cards.append(card)
	selected_index = maxi(GameState.characters.find(GameState.selected), 0)
	if not GameState.is_unlocked(GameState.characters[selected_index]):
		selected_index = 0  # 해금된 캐릭터로 보정
	play_button.pressed.connect(_on_play)
	upgrade_button.pressed.connect(_on_upgrade)  # 코인 잔액은 상단 BestLabel에 표기
	$NavBar/Row/PatchButton.pressed.connect(_on_patch)
	$NavBar/Row/RelicButton.pressed.connect(_on_relics)
	$NavBar/Row/BestiaryButton.pressed.connect(_on_bestiary)
	# 시작 웨이브 다이얼: 1 ~ 최고 기록(1단위). 기록이 2 미만이면 숨김(아직 스킵 구간 없음).
	if GameState.best_wave < 2:
		start_wave_box.hide()
		GameState.start_wave = 1
	else:
		start_wave_slider.max_value = GameState.best_wave
		start_wave_slider.value = clampi(GameState.start_wave, 1, GameState.best_wave)
		GameState.start_wave = int(start_wave_slider.value)
		start_wave_slider.value_changed.connect(_on_start_wave_changed)
		_refresh_start_wave()
	# 숙련 게이지 스타일 (채움 색은 _update_mastery에서 선택 캐릭터 accent로 갱신)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0, 0, 0, 0.4)
	xp_bg.set_corner_radius_all(5)
	_xp_fill = StyleBoxFlat.new()
	_xp_fill.set_corner_radius_all(5)
	mastery_bar.add_theme_stylebox_override("background", xp_bg)
	mastery_bar.add_theme_stylebox_override("fill", _xp_fill)
	_refresh()
	_build_stage_buttons()  # 무한모드(PlayButton) 아래에 속성 스테이지 선택 버튼 추가

func _on_start_wave_changed(v: float) -> void:
	GameState.start_wave = int(v)
	_refresh_start_wave()

func _refresh_start_wave() -> void:
	start_wave_label.text = "시작: Wave %d" % GameState.start_wave

func _make_card(c: CharacterData, idx: int) -> Button:
	var unlocked := GameState.is_unlocked(c)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 150)
	btn.pivot_offset = Vector2(150, 75)  # 선택 강조 확대가 카드 중앙 기준이 되도록
	btn.disabled = not unlocked
	btn.pressed.connect(_on_card_pressed.bind(idx))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)

	var icon := TextureRect.new()
	icon.texture = c.mage_sprite
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_lbl := _label(c.display_name if unlocked else "???", 22, c.accent_color if unlocked else Color(0.6, 0.6, 0.6))
	box.add_child(name_lbl)

	var info := c.description if unlocked else "Wave %d 도달 시 해금" % c.unlock_wave
	box.add_child(_label(info, 15, Color(0.8, 0.8, 0.8) if unlocked else Color(0.55, 0.55, 0.55)))

	if unlocked and c.element != "":  # 간결화: 오행 속성·상성만 (틀린 스탯줄·기록줄 제거)
		box.add_child(_label("%s · %s에 강함" % [ElementLib.display_name(c.element), ElementLib.strong_against(c.element)], 14, ElementLib.color(c.element)))

	btn.add_child(box)
	return btn

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _on_card_pressed(idx: int) -> void:
	selected_index = idx
	_refresh()

func _refresh() -> void:
	for i in cards.size():
		var unlocked := GameState.is_unlocked(GameState.characters[i])
		if not unlocked:
			cards[i].modulate = Color(0.45, 0.45, 0.45)
			cards[i].scale = Vector2(1, 1)
		elif i == selected_index:
			cards[i].modulate = Color(1, 1, 1)
			cards[i].scale = Vector2(1.06, 1.06)  # 선택 카드 확대 강조
		else:
			cards[i].modulate = Color(0.6, 0.6, 0.6)  # 비선택은 더 어둡게(대비↑)
			cards[i].scale = Vector2(1, 1)
	_update_mastery()  # 선택 캐릭터 숙련 패널 갱신

## 선택 캐릭터의 숙련 Lv·전투력 보너스·exp 게이지 갱신
func _update_mastery() -> void:
	var c: CharacterData = GameState.characters[selected_index]
	if not GameState.is_unlocked(c):
		mastery_box.hide()
		return
	mastery_box.show()
	var st: Array = GameState._xp_state(c)  # [레벨, 레벨 내 경험치, 다음 레벨 필요치]
	var bonus := int(round((GameState.mastery_mult(c) - 1.0) * 100.0))
	mastery_label.text = "%s 숙련 Lv %d · 전투력 +%d%%" % [c.display_name, st[0], bonus]
	mastery_bar.max_value = st[2]
	mastery_bar.value = st[1]
	_xp_fill.bg_color = c.accent_color

func _on_play() -> void:  # 무한모드 (속성 순환, 끝없음)
	GameState.selected = GameState.characters[selected_index]
	GameState.game_mode = "endless"
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

## 속성 스테이지(유한 클리어 모드) 시작 — 고른 속성으로
func _on_stage(elem: String) -> void:
	GameState.selected = GameState.characters[selected_index]
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
	GameState.selected = GameState.characters[selected_index]  # 강조 중인 캐릭터를 강화 대상으로
	get_tree().change_scene_to_file("res://scenes/ui/meta_upgrade.tscn")

func _on_patch() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/patch_notes.tscn")

func _on_relics() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/relic_manage.tscn")

func _on_bestiary() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/bestiary.tscn")
