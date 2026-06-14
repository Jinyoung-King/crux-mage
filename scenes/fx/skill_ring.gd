extends Node2D
## 광역 스킬 임팩트 — '테두리 링'이 아니라 범위를 꽉 채우는 속성별 채움 폭발.
## position 지정 후 setup(radius, color, element) 호출. 짧고 강하게 터졌다 회전하며 사라진다.
## element별 방사 모양이 달라 어떤 스킬인지 한눈에 보인다(불=불꽃혀/물=얼음결정/흙=돌+균열/금=금속침/목=가시).

var radius := 80.0
var _col := Color.WHITE
var _elem := ""

func setup(r: float, c: Color, elem := "") -> void:
	radius = maxf(r, 24.0)
	_col = c
	_elem = elem
	modulate = Color(1, 1, 1, 1)
	queue_redraw()

func _ready() -> void:
	z_index = 40  # 적·장판 위, 데미지 숫자 아래
	scale = Vector2(0.35, 0.35)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # 탄성 있게 '펑'
	tw.tween_property(self, "rotation", 0.35, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "modulate:a", 0.0, 0.42).set_delay(0.16).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _draw() -> void:
	var c := _col
	# 1) 범위를 채우는 글로우(중심 밝음 → 가장자리) — 테두리가 아니라 채움
	draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.26))
	draw_circle(Vector2.ZERO, radius * 0.62, Color(c.r, c.g, c.b, 0.42))
	draw_circle(Vector2.ZERO, radius * 0.30, Color(1, 1, 1, 0.6))  # 흰 코어 섬광
	# 2) 속성별 방사 이펙트(범위 안을 가득 채움)
	match _elem:
		"fire":  _rays_fire(c)
		"water": _shards_ice(c)
		"earth": _chunks_earth(c)
		"metal": _spikes_metal(c)
		"wood":  _burst_wood(c)
		_:       _rays_generic(c)

## 중심에서 가장자리로 뻗는 삼각 광선(밑동 넓고 끝 뾰족)
func _ray(a: float, length: float, hw: float, col: Color) -> void:
	var dir := Vector2(cos(a), sin(a))
	var perp := Vector2(-dir.y, dir.x) * hw
	draw_colored_polygon(PackedVector2Array([perp, -perp, dir * length]), col)

## 불: 길고 짧은 불꽃 혀가 번갈아 + 불티 픽셀
func _rays_fire(c: Color) -> void:
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n)
		var rr := radius * (1.0 if i % 2 == 0 else 0.58)
		_ray(a, rr, radius * 0.085, Color(c.r, c.g, c.b, 0.6))
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		var p := Vector2(cos(a), sin(a)) * radius * 0.8
		draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 4.0, 4.0), Color(1.0, 0.9, 0.4, 0.85))  # 불티

## 물: 마름모 얼음 결정이 방사 + 서리 코어
func _shards_ice(c: Color) -> void:
	var n := 8
	for i in n:
		var a := TAU * float(i) / float(n)
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x) * radius * 0.12
		var mid := dir * radius * 0.5
		draw_colored_polygon(PackedVector2Array([dir * radius * 0.1, mid + perp, dir * radius, mid - perp]), Color(c.r, c.g, c.b, 0.62))
	draw_circle(Vector2.ZERO, radius * 0.5, Color(0.8, 0.92, 1.0, 0.22))

## 흙: 중심에서 뻗는 균열 + 끝에 돌덩이
func _chunks_earth(c: Color) -> void:
	var n := 7
	for i in n:
		var a := TAU * float(i) / float(n)
		var tip := Vector2(cos(a), sin(a)) * radius
		draw_line(Vector2.ZERO, tip, Color(c.r * 0.5, c.g * 0.4, c.b * 0.3, 0.7), 3.0)  # 균열
		var u := radius * 0.12
		draw_rect(Rect2(tip.x - u, tip.y - u, 2.0 * u, 2.0 * u), Color(c.r, c.g, c.b, 0.7))  # 돌덩이

## 금: 가늘고 날카로운 금속 침이 촘촘히 방사
func _spikes_metal(c: Color) -> void:
	var n := 16
	for i in n:
		var a := TAU * float(i) / float(n)
		_ray(a, radius * (1.0 if i % 2 == 0 else 0.55), radius * 0.04, Color(c.r, c.g, c.b, 0.72))
	draw_circle(Vector2.ZERO, radius * 0.28, Color(1, 1, 1, 0.5))

## 목: 넓은 잎/가시 burst + 끝 가시 픽셀
func _burst_wood(c: Color) -> void:
	var n := 10
	for i in n:
		var a := TAU * float(i) / float(n)
		_ray(a, radius * 0.95, radius * 0.1, Color(c.r, c.g, c.b, 0.6))
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := Vector2(cos(a), sin(a)) * radius * 0.95
		draw_rect(Rect2(p.x - 2.0, p.y - 3.0, 4.0, 6.0), Color(c.r * 0.55, c.g * 0.45, c.b * 0.28, 0.8))

## 기본(처치 연출·폴백): 길고 짧은 광선 starburst
func _rays_generic(c: Color) -> void:
	var n := 12
	for i in n:
		var a := TAU * float(i) / float(n)
		_ray(a, radius * (1.0 if i % 2 == 0 else 0.6), radius * 0.07, Color(c.r, c.g, c.b, 0.55))
