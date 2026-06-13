extends Label
## 스킬 시전 시 이름을 잠깐 띄우고 위로 떠오르며 사라진다. position 지정 후 setup(text, color).
const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

func setup(txt: String, col: Color) -> void:
	text = txt
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 40)
	add_theme_color_override("font_color", col)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("outline_size", 6)

func _ready() -> void:
	z_index = 50
	pivot_offset = size * 0.5
	scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # 팝 등장
	tw.parallel().tween_property(self, "position:y", position.y - 64.0, 1.1)  # 더 높이·길게 떠오름
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.6)  # 늦게 페이드(길게 남음)
	tw.chain().tween_callback(queue_free)
