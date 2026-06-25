extends Node2D
## 몹 사망 혈흔(낭자 강화판) — 붉은 피가 촥! 사방으로 터진다.
##  ① 중심 불규칙 핏웅덩이 ② 방사 스프레이 줄기 ③ 사방 흩뿌림 핏방울
##  전체를 한 번만 그리고 scale 팝(0.4→1.0 오버슈트)으로 중심에서 터뜨려 "촥" 연출 — 매 프레임 redraw 없음(성능).
##  잠깐 진하게 남았다 사라진다. position 지정 후 add_child → setup(body_size).

const LIFETIME := 2.4   # 진하게 남는 시간(사체보다 길게 — 피는 오래 남음)
const HOLD := 1.6       # 페이드 전 선명 유지

const BLOOD := Color(0.66, 0.05, 0.05, 0.93)        # 선홍 핏빛
const BLOOD_DARK := Color(0.42, 0.02, 0.02, 0.96)   # 중심 짙은 핏빛
const BLOOD_BRIGHT := Color(0.82, 0.11, 0.09, 0.92) # 갓 튄 밝은 피

var _core_r := 16.0
var _pool: Array = []      # 중심 불규칙 웅덩이 덩어리 [{p,r}]
var _blobs: Array = []     # 흩뿌림 핏방울 [{p,r,bright}]
var _streaks: Array = []   # 방사 스프레이 줄기 [{a,b,w}]

## body_size: 적 크기(px). 클수록 더 크고·더 많이·더 멀리 튄다(보스는 피바다).
func setup(body_size: float) -> void:
	var s := maxf(body_size, 16.0)
	_core_r = s * 0.55
	# ① 중심 불규칙 웅덩이 — 여러 원을 살짝 어긋나게 겹쳐 비정형으로
	for i in 4:
		var a := randf() * TAU
		_pool.append({"p": Vector2(cos(a), sin(a)) * _core_r * randf_range(0.15, 0.5), "r": _core_r * randf_range(0.55, 0.95)})
	# ② 방사 스프레이 줄기(촥 튀는 방사선) — 끝에 핏방울 머리
	var m := mini(8 + int(s / 10.0), 18)
	for i in m:
		var a := randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		var ln := s * randf_range(1.4, 3.4)
		_streaks.append({"a": dir * _core_r * 0.4, "b": dir * ln, "w": s * randf_range(0.05, 0.14)})
	# ③ 흩뿌림 핏방울(넉넉히) — 가까운 큰 방울부터 멀리 잔방울까지
	var n := mini(16 + int(s / 5.0), 38)
	for i in n:
		var a := randf() * TAU
		var dist := _core_r * randf_range(0.4, 3.2)
		_blobs.append({"p": Vector2(cos(a), sin(a)) * dist, "r": s * randf_range(0.06, 0.30), "bright": randf() < 0.35})
	queue_redraw()

func _ready() -> void:
	z_index = -3  # 그을음(-4) 위, 적·사체(0) 아래 — 바닥에 깔린 느낌
	rotation = randf() * TAU  # 매번 다른 방향(반복감 제거)
	scale = Vector2(0.4, 0.4)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # 촥! 중심에서 터지는 팝(오버슈트)
	var tw := create_tween()
	tw.tween_interval(HOLD)  # 잠깐 진하게 남음
	tw.tween_property(self, "modulate:a", 0.0, LIFETIME - HOLD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _draw() -> void:
	# ② 방사 스프레이 줄기(중심→바깥 + 끝 핏방울 머리)
	for st in _streaks:
		draw_line(st.a, st.b, BLOOD, st.w)
		draw_circle(st.b, st.w * 0.95, BLOOD)
	# ① 중심 불규칙 핏웅덩이
	for pl in _pool:
		draw_circle(pl.p, pl.r, BLOOD)
	draw_circle(Vector2.ZERO, _core_r * 0.5, BLOOD_DARK)
	# ③ 흩뿌림 핏방울(일부는 갓 튄 밝은 피)
	for b in _blobs:
		draw_circle(b.p, b.r, BLOOD_BRIGHT if b.bright else BLOOD)
