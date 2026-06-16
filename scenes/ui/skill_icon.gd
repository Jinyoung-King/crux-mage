extends Control
## 스킬 쿨타임 아이콘: 쿨 중엔 어둡고 라디얼 스윕으로 차오르며, 준비되면 밝게 '활성화'(테두리 글로우+펄스).
## main이 매 프레임 update_cd(이름, 색, 비율, delta)로 갱신. 비율 1.0=준비완료.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")

signal hold(active: bool)  ## 누르고 있는 동안 true, 떼면 false (main이 사거리 링 표시)
signal tapped  ## 탭(아이콘 위에서 누름→뗌)으로 발생 — 저편 수동 스킬 무장용

var col: Color = Color.WHITE
var sname: String = ""
var ratio: float = 0.0  # 0~1 (1=준비완료)
var _t: float = 0.0
var _held: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(58, 58)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP  # 눌러서 사거리 보기 — 입력 받음
	mouse_exited.connect(_release)  # 누른 채 벗어나면 해제

## 누름 시작/해제 감지 → hold 시그널. 마우스·터치 모두 지원.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_held(event.pressed)
		if not event.pressed:
			tapped.emit()  # 아이콘에서 손 뗌 = 탭
	elif event is InputEventScreenTouch:
		_set_held(event.pressed)
		if not event.pressed:
			tapped.emit()

func _release() -> void:
	_set_held(false)

func _set_held(v: bool) -> void:
	if v == _held:
		return
	_held = v
	hold.emit(v)

func update_cd(skill_name: String, color: Color, r: float, dt: float) -> void:
	sname = skill_name
	col = color
	ratio = r
	_t += dt
	queue_redraw()

func _draw() -> void:
	var sz: Vector2 = size
	var center: Vector2 = sz * 0.5
	var ready: bool = ratio >= 1.0
	var pulse: float = (1.0 + 0.05 * sin(_t * 6.0)) if ready else 1.0
	var radius: float = sz.x * 0.3 * pulse
	# 배경 타일
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.09, 0.09, 0.13, 0.9), true)
	# 본체(원): 준비=밝은 속성색 / 쿨=어둡게
	var body: Color = col if ready else col.darkened(0.45)
	draw_circle(center, radius, Color(body.r, body.g, body.b, 0.95 if ready else 0.6))
	# 쿨다운 라디얼 스윕: 남은 쿨을 어두운 부채로 덮음(12시→시계방향). 비율↑ → 부채↓ → 아이콘이 차오름
	if not ready:
		var ang: float = (1.0 - ratio) * TAU
		var pts := PackedVector2Array([center])
		var steps := 26
		for i in steps + 1:
			var a: float = -PI / 2.0 + ang * float(i) / float(steps)
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	# 테두리: 준비 시 굵고 밝게 + 외곽 글로우 / 쿨 중엔 어둡게
	if ready:
		draw_rect(Rect2(Vector2(-2, -2), sz + Vector2(4, 4)), Color(col.r, col.g, col.b, 0.3), false, 2.0)
		draw_rect(Rect2(Vector2.ZERO, sz), col.lightened(0.25), false, 3.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, sz), col.darkened(0.25), false, 1.5)
	# 스킬 이름(하단 작게)
	var nm_col: Color = Color(0.95, 0.97, 1.0) if ready else Color(0.62, 0.62, 0.68)
	draw_string(FONT, Vector2(2, sz.y - 4), sname, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 4, 11, nm_col)
