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
		for e in EnemyCache.all():
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= radius:
				e.take_damage(hit * ElementLib.multiplier(element, e.element))

func _draw() -> void:
	# 테두리 링 없이 '채움'으로만 범위 표현(중심이 살짝 진함) + 속성 픽셀 장식
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.20))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(color.r, color.g, color.b, 0.16))
	# 속성별 픽셀 장식(가시·불씨·돌). 장판은 wood(가시밭)/fire(분화구 메테오)/earth(초토화 포격)만 생성됨.
	var n := int(clampf(radius / 11.0, 8, 16))  # 반경에 비례한 장식 개수
	var sc := clampf(radius / 90.0, 0.8, 1.6)   # 픽셀 한 칸 크기 배율
	for p in _scatter(n):
		match element:
			"fire":  _pixel_ember(p, sc)
			"earth": _pixel_rock(p, sc)
			_:       _pixel_thorn(p, sc)  # wood 및 기타 — 나무 가시 기본

## 해바라기(황금각) 배치 — 반경 안쪽에 고르게 분포(결정적, 매 프레임 동일)
func _scatter(n: int) -> Array:
	var pts: Array = []
	var golden := 2.39996323  # 황금각(rad)
	for i in n:
		var rr := radius * sqrt(float(i + 1) / float(n + 1)) * 0.80
		var ang := float(i) * golden
		pts.append(Vector2(cos(ang) * rr, sin(ang) * rr))
	return pts

## 픽셀 나무 가시 1개 — p에서 위로 솟은 삼각 스파이크(아래 굵고 위로 좁아짐)
func _pixel_thorn(p: Vector2, sc: float) -> void:
	var u := maxf(2.0, 2.0 * sc)  # 픽셀 한 칸
	var body := Color(0.46, 0.30, 0.15)  # 나무 갈색
	var tip := Color(0.66, 0.50, 0.28)   # 끝 하이라이트
	for r in 4:
		var w := (4 - r) * u  # 위로 갈수록 좁게
		var c := tip if r == 3 else body
		draw_rect(Rect2(p.x - w * 0.5, p.y - (r + 1) * u, w, u), c)
	draw_rect(Rect2(p.x - 2.0 * u, p.y, 4.0 * u, u * 0.7), Color(0.26, 0.16, 0.08))  # 밑동 그늘

## 픽셀 불씨 1개 — 위로 가늘어지는 불꽃 혀(밑=주황, 끝=노랑 코어)
func _pixel_ember(p: Vector2, sc: float) -> void:
	var u := maxf(2.0, 2.0 * sc)
	var flame := Color(0.95, 0.45, 0.18)
	draw_rect(Rect2(p.x - u, p.y - u, 2.0 * u, u), flame)             # 넓은 밑
	draw_rect(Rect2(p.x - u * 0.5, p.y - 2.0 * u, u, u), flame)       # 가운데
	draw_rect(Rect2(p.x - u * 0.5, p.y - 3.0 * u, u, u), Color(1.0, 0.85, 0.35))  # 끝 코어(노랑)

## 픽셀 돌멩이 1개 — 블록형 바위(좌상 하이라이트 + 우하 그늘)
func _pixel_rock(p: Vector2, sc: float) -> void:
	var u := maxf(2.0, 2.0 * sc)
	draw_rect(Rect2(p.x - 1.5 * u, p.y - u, 3.0 * u, 2.0 * u), Color(0.55, 0.45, 0.30))  # 몸체
	draw_rect(Rect2(p.x - 1.5 * u, p.y - u, 1.5 * u, u), Color(0.70, 0.60, 0.42))        # 좌상 하이라이트
	draw_rect(Rect2(p.x, p.y, 1.5 * u, u), Color(0.36, 0.28, 0.17))                      # 우하 그늘
