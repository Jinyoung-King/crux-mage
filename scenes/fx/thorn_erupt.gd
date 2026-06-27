extends Node2D
## 가시밭 시전 순간 — 길고 날카로운 가시 다발이 바닥에서 '쫙' 솟구쳤다 사라진다.
## position 지정 후 setup(radius). 탄성 팝업(작게→크게)으로 솟는 느낌.

const OUTLINE := Color(0.10, 0.14, 0.05, 0.95)  # 어두운 외곽선(어느 배경에서도 또렷)
const BODY := Color(0.42, 0.56, 0.18)           # 이끼 초록(목 속성) — 고대비로 잘 보임
const TIP := Color(0.78, 0.98, 0.48)            # 밝은 새싹빛 끝(더 날카로워 보임)
const BASE_DARK := Color(0.20, 0.14, 0.07)      # 뿌리 그늘

var _r := 110.0
var _thorns: Array = []  # [{base:Vector2, dir:Vector2, L:float, W:float}]

func setup(r: float) -> void:
	_r = maxf(r, 60.0)
	_thorns.clear()
	var n := clampi(int(_r / 3.0), 30, 80)  # 빽빽이 — 반경 비례, 최대 80
	for i in n:
		var a := randf() * TAU
		var dist := _r * 0.7 * sqrt(randf())  # 중앙 쪽에서 시작 → 바깥으로 길게 뻗게
		var outward := Vector2(cos(a), sin(a))
		var dir := outward.rotated(randf_range(-0.4, 0.4))  # 바깥 + 약간 흩뿌림(엉킨 덤불)
		var L := _r * randf_range(0.55, 1.0)  # 길게 — 반경의 절반~전부
		var W := maxf(L * 0.16, 7.0)          # 가늘게(날카로움) + 최소 폭 보장
		_thorns.append({"base": outward * dist, "dir": dir, "L": L, "W": W})
	queue_redraw()

func _ready() -> void:
	z_index = 6  # 적·장판 위 — 잘 보이게
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # 솟구침
	tw.tween_interval(0.55)  # 더 오래 머무름(잘 보이게)
	tw.tween_property(self, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _draw() -> void:
	for t in _thorns:
		var perp: Vector2 = t.dir.orthogonal()
		var hw: float = t.W * 0.5
		var b1: Vector2 = t.base + perp * hw
		var b2: Vector2 = t.base - perp * hw
		var tip: Vector2 = t.base + t.dir * t.L
		# ① 외곽선(살짝 키운 어두운 삼각 — 배경 무관 또렷)
		draw_colored_polygon(PackedVector2Array([
			t.base + perp * (hw + 2.5), t.base - perp * (hw + 2.5), tip + t.dir * 5.0]), OUTLINE)
		# ② 본체(날카로운 초록 삼각)
		draw_colored_polygon(PackedVector2Array([b1, b2, tip]), BODY)
		# ③ 뿌리 그늘 + 끝 1/3 밝은 하이라이트
		draw_circle(t.base, hw, BASE_DARK)
		draw_colored_polygon(PackedVector2Array([b1.lerp(tip, 0.6), b2.lerp(tip, 0.6), tip]), TIP)
