extends Node2D
## 플로팅 데미지 숫자: 명중 위치에서 위로 떠오르며 페이드 후 스스로 사라진다.
## Node2D + _draw로 월드 공간에 안정적으로 렌더(Control 좌표 문제 회피). 치명타는 크고 금색.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

var _text := ""
var _size := 19
var _color := Color(1, 1, 1)

func setup(amount: float, is_crit: bool) -> void:
	_text = str(int(round(amount)))
	_size = 30 if is_crit else 19
	_color = Color(1.0, 0.82, 0.2) if is_crit else Color(1, 1, 1)
	z_index = 100  # 적·발사체 위에
	position += Vector2(randf_range(-10.0, 10.0), -8.0)  # 살짝 흩뿌리고 위에서 시작
	var rise := 52.0 if is_crit else 40.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", position.y - rise, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)
	queue_redraw()

func _draw() -> void:
	var w: float = FONT.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x
	var origin := Vector2(-w / 2.0, 0.0)  # 가로 중앙 정렬
	for off in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
		draw_string(FONT, origin + off, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, Color(0, 0, 0, 0.85))
	draw_string(FONT, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, _color)
