extends Area2D
## direction 방향으로 직진하는 발사체.
## 적과 충돌하면 데미지를 주고 사라진다.
## 캐릭터 패시브(치명타/화상/둔화)는 플레이어가 발사 시 설정한다.

signal dealt(heal: float)  ## 적에 피해를 입힐 때 흡혈 회복량(피해×흡혈률)을 알림
signal chained(from: Vector2, to: Vector2)  ## 뇌전 연쇄 시각용 (시작점→도착점)
signal damaged(amount: float, is_crit: bool, pos: Vector2, is_strong: bool)  ## 직격 피해 수치(플로팅 숫자용, is_strong=상성 강타)
signal returned  ## 수명 종료 — 풀(main)로 반환 요청(파괴 대신 재사용)

@export var speed: float = 600.0

var direction := Vector2.RIGHT
var damage := 10.0
var lifesteal := 0.0  ## 입힌 피해의 흡혈 비율 (플레이어가 발사 시 설정)
# 패시브 효과 (플레이어가 발사 시 캐릭터에서 채움)
var crit_chance := 0.0
var crit_mult := 1.0
var burn_dps := 0.0
var burn_duration := 0.0
var slow_factor := 1.0
var slow_duration := 0.0
# 비도술사 연쇄 (플레이어가 발사 시 캐릭터에서 채움)
var chain_count := 0
var chain_factor := 0.0
var chain_range := 220.0
var execute_threshold := 0.0  ## 수확의 룬: 적 체력이 이 비율 이하면 즉사
var splash_factor := 0.0  ## 포격술사: 명중 시 반경 내 적에게 (명중피해×이 비율) 광역 피해
var splash_radius := 90.0
var element := ""  ## 오행 속성 (적 속성과 상성 판정 — ElementLib)
var pierce := 0  ## 관통: 이 수만큼 적을 추가로 꿰뚫고 비행 (소진 시 소멸)

const TRAIL_LEN := 8  ## 꼬리 잔광 점 개수
var _trail: Line2D  ## 비행 잔광(스킬 마력탄만 visible — 평타는 숨김). 노드는 1회 생성 후 재사용
var _trail_grad: Gradient  ## 트레일 색 갱신용(재사용 시 속성색 변경)
var active := false  ## 비행 중(true) / 풀 대기(false) — 중복 반환·오발 방지
var pooled := false  ## 풀 관리 대상(main.acquire가 설정) — _die가 파괴 대신 returned 방출
var _base_scale := Vector2.ONE  ## 스프라이트 기본 배율(재사용 시 복원 — 마력탄 1.5배 누적 방지)
var _base_texture: Texture2D    ## 스프라이트 기본 텍스처(재사용 시 복원)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_die)
	_base_scale = $Sprite2D.scale
	_base_texture = $Sprite2D.texture
	_make_trail()
	_trail.visible = false

## 꼬리 잔광 Line2D 1회 생성(top_level=전역좌표). 색은 enable_trail에서 속성색으로 갱신.
func _make_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = 6.0
	_trail.z_index = -1  # 발사체 스프라이트 아래
	_trail_grad = Gradient.new()
	_trail.gradient = _trail_grad
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0.1))  # 끝 가늘게
	wc.add_point(Vector2(1, 1.0))  # 머리 굵게
	_trail.width_curve = wc
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)

## 스킬 마력탄용 트레일 켜기(속성색). 평타는 호출하지 않아 숨김 유지.
func enable_trail() -> void:
	var col := ElementLib.color(element) if element != "" else Color(1.0, 0.95, 0.7)
	_trail_grad.set_color(0, Color(col.r, col.g, col.b, 0.0))  # 꼬리 끝 투명
	_trail_grad.set_color(1, Color(col.r, col.g, col.b, 0.55))  # 머리 쪽 진함
	_trail.clear_points()
	_trail.visible = true

## 발사 직전 상태 초기화(풀 재사용 시 이전 값 누수 방지) — 이후 player가 필요한 값만 덮어씀.
func reset_for_reuse() -> void:
	damage = 10.0; lifesteal = 0.0
	crit_chance = 0.0; crit_mult = 1.0
	burn_dps = 0.0; burn_duration = 0.0
	slow_factor = 1.0; slow_duration = 0.0
	chain_count = 0; chain_factor = 0.0; chain_range = 220.0
	execute_threshold = 0.0
	splash_factor = 0.0; splash_radius = 90.0
	element = ""; pierce = 0
	var spr: Sprite2D = $Sprite2D
	spr.texture = _base_texture
	spr.modulate = Color.WHITE
	spr.scale = _base_scale
	spr.hframes = 1  # 스킬 발사체가 시트 프레임을 쓰면 hframes를 바꾸므로 풀 반환 시 복원
	spr.frame = 0
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	_trail.clear_points()
	_trail.visible = false
	active = true
	visible = true
	set_physics_process(true)
	set_deferred("monitoring", true)

## 풀 대기 상태로 — 처리·충돌·표시 끄고 화면 밖으로(노티파이어 오발 방지).
func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)
	set_deferred("monitoring", false)
	position = Vector2(-9999, -9999)
	_trail.clear_points()

## 수명 종료: 풀 대상이면 반환 요청(재사용), 아니면 파괴. active 가드로 중복 방지.
func _die() -> void:
	if not active:
		return
	if pooled:
		returned.emit()
	else:
		queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	if _trail.visible:
		_trail.add_point(global_position)
		if _trail.get_point_count() > TRAIL_LEN:
			_trail.remove_point(0)

func _on_area_entered(area) -> void:
	if not area.is_in_group("enemies"):
		return
	var dmg := damage
	var is_crit := false
	if crit_chance > 0.0 and randf() < crit_chance:
		dmg *= crit_mult  # 치명타
		is_crit = true
	var mult := ElementLib.multiplier(element, area.element)  # 오행 상성
	var hit_dmg := dmg * mult * randf_range(0.95, 1.05)  # ±5% 데미지 분산
	area.take_damage(hit_dmg)
	damaged.emit(hit_dmg, is_crit, area.global_position, mult > 1.0)  # 플로팅 데미지 숫자(상성 강타 강조)
	if lifesteal > 0.0:
		dealt.emit(hit_dmg * lifesteal)  # 흡혈: 입힌 피해 비율만큼 회복
	if execute_threshold > 0.0 and area.hp > 0.0 and area.hp <= area.max_hp * execute_threshold:
		area.take_damage(area.hp)  # 수확의 룬: 즉사
	if burn_dps > 0.0:
		area.apply_burn(burn_dps, burn_duration)
	if slow_duration > 0.0:
		area.apply_slow(slow_factor, slow_duration)
	if chain_count > 0:
		_chain_from(area, dmg)
	if splash_factor > 0.0:
		_splash_from(area, dmg, area.global_position)
	if pierce > 0:
		pierce -= 1  # 관통: 적을 꿰뚫고 계속 비행 (같은 적은 area_entered가 재발화 안 함)
	else:
		_die()

## 뇌전 연쇄: 명중한 적 주변의 가까운 적들에게 연쇄 피해 + 시각 신호.
## take_damage는 일반 명중과 같은 경로(사망 시 died→main FX)라 물리 콜백에서 안전.
func _chain_from(hit, dmg: float) -> void:
	var origin: Vector2 = hit.global_position
	var others := EnemyCache.all().filter(func(e): return e != hit and is_instance_valid(e))  # filter가 새 배열 생성 → 정렬 안전
	others.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	var n := 0
	for e in others:
		if n >= chain_count:
			break
		var ep: Vector2 = e.global_position
		if origin.distance_to(ep) > chain_range:
			break  # 정렬돼 있으므로 사정거리 밖이면 이후도 전부 밖
		var cd := dmg * chain_factor * ElementLib.multiplier(element, e.element) * randf_range(0.95, 1.05)
		e.take_damage(cd)
		if lifesteal > 0.0:
			dealt.emit(cd * lifesteal)
		chained.emit(origin, ep)
		n += 1

## 포격 광역: 명중 지점 반경 내 다른 적들에게 비례 피해 + 데미지 숫자 (비물리라 충돌 콜백 안전)
func _splash_from(hit, dmg: float, center: Vector2) -> void:
	for e in EnemyCache.all():
		if e == hit or not is_instance_valid(e):
			continue
		if center.distance_to(e.global_position) <= splash_radius:
			var em := ElementLib.multiplier(element, e.element)
			var sd := dmg * splash_factor * em * randf_range(0.95, 1.05)
			e.take_damage(sd)
			damaged.emit(sd, false, e.global_position, em > 1.0)
			if lifesteal > 0.0:
				dealt.emit(sd * lifesteal)
