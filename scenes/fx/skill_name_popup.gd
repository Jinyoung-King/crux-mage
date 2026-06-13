extends Label
## 스킬 시전 시 이름을 잠깐 띄우고 위로 떠오르며 사라진다. position 지정 후 setup(text, color).
const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

func setup(txt: String, col: Color) -> void:
	text = txt
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 34)
	add_theme_color_override("font_color", col)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("outline_size", 6)

func _ready() -> void:
	z_index = 50
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 48.0, 0.7)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tw.tween_callback(queue_free)
