extends Node2D
## 몹 사망 혈흔 — 붉은 핏자국이 촥! 터지듯 팝인되고 잠깐 바닥에 남았다 사라진다(순수 시각).
## position 지정 후 add_child → setup(body_size). 적·사체 아래에 깔리는 데칼.

const LIFETIME := 1.6   # 사체(death_remains)와 동일 — 같이 사라지도록
const HOLD := 0.9       # 페이드 전 선명하게 남는 시간

const BLOOD := Color(0.62, 0.06, 0.06, 0.9)       # 선홍 핏빛
const BLOOD_DARK := Color(0.40, 0.02, 0.02, 0.9)  # 중심 짙은 핏빛

var _core_r := 14.0
var _blobs: Array = []  # 중심 주변 핏방울 [{p:Vector2, r:float}]

## body_size: 적 크기(px). 클수록 혈흔도 크고 방울도 많이.
func setup(body_size: float) -> void:
	var s := maxf(body_size, 16.0)
	_core_r = s * 0.40
	var n := 5 + int(s / 12.0)  # 기본병 ~7, 보스 더 많이
	for i in n:
		var a := randf() * TAU
		var dist := _core_r * randf_range(0.7, 2.2)  # 중심에서 흩뿌려진 거리
		_blobs.append({"p": Vector2(cos(a), sin(a)) * dist, "r": s * randf_range(0.09, 0.24)})
	queue_redraw()

func _ready() -> void:
	z_index = -3  # 그을음(-4) 위, 적·사체(0) 아래 — 바닥에 깔린 느낌
	rotation = randf() * TAU  # 매번 다른 방향(반복감 제거)
	scale = Vector2(0.45, 0.45)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.13) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # 촥! 터지는 팝
	var tw := create_tween()
	tw.tween_interval(HOLD)  # 잠깐 선명하게 남음
	tw.tween_property(self, "modulate:a", 0.0, LIFETIME - HOLD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, _core_r, BLOOD)            # 중심 핏웅덩이
	draw_circle(Vector2.ZERO, _core_r * 0.55, BLOOD_DARK)
	for b in _blobs:                                      # 흩뿌려진 핏방울
		draw_circle(b.p, b.r, BLOOD)
