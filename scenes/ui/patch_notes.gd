extends Control
## 패치노트 화면: GameState.CHANGELOG를 버전별로 나열. 열람 시 현재 버전을 본 것으로 기록.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const NAV_BAR := preload("res://scenes/ui/nav_bar.gd")  # 하단 탭 네비게이션(유지)
const RECENT := 3  # 최근 N개만 펼쳐 표시, 이전은 버튼으로 토글

@onready var list: VBoxContainer = $Center/Scroll/List
@onready var back_button: Button = $Center/BackButton

func _ready() -> void:
	Music.play_menu()
	back_button.pressed.connect(_on_back)
	var total := GameState.CHANGELOG.size()
	# 최근 3개는 바로 펼쳐 표시
	for i in mini(RECENT, total):
		_add_entry(list, GameState.CHANGELOG[i], false)
	# 그 이전은 '이전 패치' 버튼으로 접어두고, 누르면 펼침
	if total > RECENT:
		var older := VBoxContainer.new()
		older.visible = false
		older.add_theme_constant_override("separation", 6)
		var toggle := Button.new()
		toggle.add_theme_font_override("font", FONT)
		toggle.add_theme_font_size_override("font_size", 20)
		toggle.custom_minimum_size = Vector2(360, 48)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		toggle.text = "이전 패치 보기 (%d개) ▾" % (total - RECENT)
		toggle.pressed.connect(func() -> void:
			older.visible = not older.visible
			toggle.text = "이전 패치 숨기기 ▴" if older.visible else "이전 패치 보기 (%d개) ▾" % (total - RECENT))
		list.add_child(toggle)
		list.add_child(older)
		for i in range(RECENT, total):
			_add_entry(older, GameState.CHANGELOG[i], true)
	GameState.mark_version_seen()  # 자동 안내 1회용 기록
	var nav := NAV_BAR.new()  # 하단 탭 네비게이션 유지
	add_child(nav)
	nav.setup("patch")

## 한 버전 항목(헤더 + 노트들 + 간격)을 parent에 추가
func _add_entry(parent: VBoxContainer, entry, old: bool) -> void:
	parent.add_child(_header(entry.v, old))
	for note in entry.notes:
		parent.add_child(_note("· " + note, old))
	parent.add_child(_spacer())

func _header(v: String, old := false) -> Label:
	var l := Label.new()
	l.text = v
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 20 if old else 24)
	l.add_theme_color_override("font_color", Color(0.62, 0.56, 0.42) if old else Color(1.0, 0.85, 0.4))
	return l

func _note(text: String, old := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 14 if old else 17)
	l.add_theme_color_override("font_color", Color(0.55, 0.57, 0.63) if old else Color(0.85, 0.88, 0.95))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	return l

func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 10)
	return c

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
