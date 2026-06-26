extends Node2D
## 가시밭 시전 순간 — 날카로운 가시 다발이 바닥에서 '쫙' 솟구쳤다 사라진다.
## position 지정 후 setup(radius). 탄성 팝업(작게→크게)으로 솟는 느낌.

const BODY := Color(0.34, 0.26, 0.12)   # 가시 본체(짙은 나무빛)
const TIP := Color(0.62, 0.80, 0.40)    # 끝 하이라이트(목 속성 초록빛 — 더 날카로워 보임)
const BASE_DARK := Color(0.20, 0.14, 0.07)  # 뿌리 그늘

var _r := 110.0
var _thorns: Array = []  # [{base:Vector2, dir:Vector2, L:float, W:float}]

func setup(r: float) -> void:
	_r = maxf(r, 60.0)
	_thorns.clear()
	var n := clampi(int(_r / 4.0), 22, 60)  # 많은 양 — 반경에 비례해 빽빽이
	for i in n:
		var a := randf() * TAU
		var dist := _r * sqrt(randf())  # 면적 균일 분포(가운데부터 가장자리까지 가득)
		var outward := Vector2(cos(a), sin(a))
		var dir := outward.rotated(randf_range(-0.45, 0.45))  # 바깥으로 + 약간 흩뿌림(엉킨 가시덤불)
		var L := _r * randf_range(0.24, 0.52)  # 가시 길이
		var W := L * randf_range(0.12, 0.22)   # 폭은 길이의 일부만 → 가늘고 날카롭게
		_thorns.append({"base": outward * dist, "dir": dir, "L": L, "W": W})
	queue_redraw()

func _ready() -> void:
	z_index = 4  # 장판 위, 적과 비슷한 높이(솟는 느낌)
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # 솟구침
	tw.tween_interval(0.3)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _draw() -> void:
	for t in _thorns:
		var perp: Vector2 = t.dir.orthogonal()
		var b1: Vector2 = t.base + perp * t.W * 0.5
		var b2: Vector2 = t.base - perp * t.W * 0.5
		var tip: Vector2 = t.base + t.dir * t.L
		draw_colored_polygon(PackedVector2Array([b1, b2, tip]), BODY)  # 날카로운 삼각 가시
		draw_circle(t.base, t.W * 0.5, BASE_DARK)  # 뿌리 그늘(솟은 느낌)
		var m1: Vector2 = b1.lerp(tip, 0.55)
		var m2: Vector2 = b2.lerp(tip, 0.55)
		draw_colored_polygon(PackedVector2Array([m1, m2, tip]), TIP)  # 끝 1/3 밝은 하이라이트
