extends Node2D
## 잔류 장판 — 일정 시간 반경 내 적에게 주기적 피해(지속 피해 필드). 단색 도형.
## setup(반경, 초당피해, 원소, 색) 후 배치. 직접 피해(재귀 반응 없음)라 안전·가벼움.

var radius := 90.0
var dps := 10.0
var element := ""
var color := Color(1.0, 0.5, 0.2)
var _life := 3.6
var _tick := 0.0

func setup(r: float, d: float, elem: String, col: Color) -> void:
	radius = r
	dps = d
	element = elem
	color = col
	queue_redraw()

func _ready() -> void:
	z_index = -5  # 적·마법사 아래에 깔리도록

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	modulate.a = clampf(_life / 3.6, 0.25, 1.0)  # 끝물에 옅어짐
	_tick += delta
	if _tick >= 0.3:  # 0.3초마다 틱 피해
		_tick -= 0.3
		var hit := dps * 0.3
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= radius:
				e.take_damage(hit * ElementLib.multiplier(element, e.element))

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 44, Color(color.r, color.g, color.b, 0.8), 2.5, true)
