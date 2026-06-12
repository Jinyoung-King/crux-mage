extends Control
## 패치노트 화면: GameState.CHANGELOG를 버전별로 나열. 열람 시 현재 버전을 본 것으로 기록.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

@onready var list: VBoxContainer = $Center/Scroll/List
@onready var back_button: Button = $Center/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	for entry in GameState.CHANGELOG:
		list.add_child(_header(entry.v))
		for note in entry.notes:
			list.add_child(_note("· " + note))
		list.add_child(_spacer())
	GameState.mark_version_seen()  # 자동 안내 1회용 기록

func _header(v: String) -> Label:
	var l := Label.new()
	l.text = v
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	return l

func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	return l

func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 10)
	return c

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
