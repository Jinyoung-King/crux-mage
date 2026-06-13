extends Node2D
## 플로팅 데미지 숫자: 팝 등장 후 위로 떠오르며 페이드. 배속(time_scale)에도 화면상 동일 시간 보이도록 보정.
## Node2D + _draw로 월드 공간에 안정 렌더. 치명타=크고 금색, 상성 강타=주황.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

var _text := ""
var _size := 20
var _color := Color(1, 1, 1)

func setup(amount: float, is_crit: bool, player := false, strong := false) -> void:
	_text = NumFmt.compact(int(round(amount)))
	var pop := 1.15
	if player:  # 플레이어가 받는 피해 — 빨강, 크게
		_size = 28
		_color = Color(1.0, 0.35, 0.3)
		pop = 1.25
	elif is_crit:  # 치명타 — 금색, 가장 크게
		_size = 34
		_color = Color(1.0, 0.84, 0.2)
		pop = 1.35
	elif strong:  # 오행 상성 강타 — 주황
		_size = 27
		_color = Color(1.0, 0.58, 0.25)
		pop = 1.25
	else:
		_size = 20
		_color = Color(1, 1, 1)
	z_index = 100  # 적·발사체 위에
	position += Vector2(randf_range(-10.0, 10.0), -8.0)
	queue_redraw()
	# 배속 보정: time_scale 배만큼 트윈을 늘려 3배속에도 화면상 같은 시간 동안 보임
	var ts: float = maxf(Engine.time_scale, 1.0)
	var rise: float = 56.0 if (is_crit or player) else (48.0 if strong else 42.0)
	scale = Vector2(0.45, 0.45)
	# 팝 등장(작게→크게→정상)
	var pt := create_tween()
	pt.tween_property(self, "scale", Vector2(pop, pop), 0.12 * ts).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(self, "scale", Vector2.ONE, 0.1 * ts)
	# 떠오름(전체) + 후반 페이드 → 끝나면 소멸
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", position.y - rise, 1.0 * ts).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.4 * ts).set_delay(0.62 * ts).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)

func _draw() -> void:
	var w: float = FONT.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x
	var origin := Vector2(-w / 2.0, 0.0)  # 가로 중앙 정렬
	# 두꺼운 8방향 외곽선 — 화려함 + 배경과 대비(가독성)
	for off in [Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Vector2(-2.5, 2.5), Vector2(2.5, 2.5), Vector2(0, -2.5), Vector2(0, 2.5), Vector2(-2.5, 0), Vector2(2.5, 0)]:
		draw_string(FONT, origin + off, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, Color(0, 0, 0, 0.9))
	draw_string(FONT, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, _color)
