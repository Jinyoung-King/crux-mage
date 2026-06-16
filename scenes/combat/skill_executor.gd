class_name SkillExecutor
extends Node
## 전투 연산·타격 판정·전투 전용 FX 실행을 main에서 분리(SRP). player.skill_cast → execute()로 구동된다.
## 의존성 주입(DI): setup()으로 player·fx_root·host를 주입. 명중 동적 효과는 player.hit_modifiers(전략)가 담당.
##
## 공유 자원은 host(main)에 위임: _skill_ring(적 사망 연출 등 공용)·_damage_number(플레이어 피격에도 사용)·
## _add_shake(카메라)·game_over(씬 상태). 이로써 전투 로직은 이 노드가, 씬 레벨 책임은 main이 갖는다.
## 성능: 적 목록은 EnemyCache.all()(물리 프레임당 1회 스냅샷)로 조회 — 폭발·광역마다 O(N) 그룹 탐색을 반복하지 않음.

const GROUND_HAZARD := preload("res://scenes/fx/ground_hazard.gd")
const FALLING_SKILL := preload("res://scenes/fx/falling_skill.gd")
const DEATH_BURST_SCENE := preload("res://scenes/fx/death_burst.tscn")
const SCORCH := preload("res://scenes/fx/scorch_mark.gd")  # 메테오 착탄 그을음
const THORN_ERUPT := preload("res://scenes/fx/thorn_erupt.gd")  # 가시밭 가시 솟구침
const PIXEL_FX := preload("res://scenes/fx/pixel_fx.gd")  # 픽셀 FX 시트 재생기(아트 업그레이드)
const FX_EXPLOSION_EXT := preload("res://assets/sprites/fx_ext_explosion.png")  # 불 폭발(외부 CC0 — OpenGameArt "explosion-7", CC0/PD, 10x5=50프레임). 유성·불바다 공용
const FX_WATER := preload("res://assets/sprites/fx_water.png")  # 물(빙하·서리바람) — DevWizard "Splash", CC0, 192x32=6프레임
const FX_WOOD := preload("res://assets/sprites/fx_wood.png")    # 목(가시밭) — DevWizard "Plant Missle", CC0, 96x16=6프레임
const FX_METAL := preload("res://assets/sprites/fx_metal.png")  # 쇠(전격) — DevWizard "Magic Sparks", CC0, 96x16=6프레임. 연쇄 명중 스파크
# (흙=융단폭격·낙석은 FX_EXPLOSION_EXT 재사용 — 폭격 임팩트로 적합)
# (절차 생성 fx_explosion_fire.png는 외부 폭발로 통일되며 미사용 — gen_fx.py·에셋은 보존)
const REACTION_HP_PCT := 0.06  ## 격발 반응(증발·빙결파쇄)이 주는 추가 % 최대체력 피해 — 복리 체력 관통

var player
var fx_root: Node2D
var host  # main — 공유 FX·game_over 제공
var _hit_ctx := HitContext.new()  # 명중 컨텍스트 재사용(핫패스 무할당)

func setup(p, fx: Node2D, h) -> void:
	player = p
	fx_root = fx
	host = h

## 액티브 스킬 발동 처리 (player.skill_cast 시그널 → 이 메서드)
func execute(s: Dictionary) -> void:
	if host.game_over:
		return
	var ep: float = s.power
	var er: float = s.radius
	var element: String = s.element
	var count: int = s.count + player.build.extra_targets  # 다발: 표적형 스킬 추가 표적
	var col: Color = ElementLib.color(element)
	var rng: float = SkillLib.SKILL_RANGE.get(s.id, 99999.0)  # 스킬별 사거리
	var pool := _enemies_in_range(rng)  # 사거리 내 적만 타겟
	match s.id:
		"bolts":
			var pp: Vector2 = player.global_position
			pool.sort_custom(func(a, b): return pp.distance_squared_to(a.global_position) < pp.distance_squared_to(b.global_position))
			for e in pool.slice(0, count):
				if is_instance_valid(e):
					player.fire_skill_bolt(e, ep, element)  # 보이는 마력탄이 날아가 명중(스킬 속성으로 상성·틴트)
		"meteor":
			var center := _densest_cluster(er, pool)
			if center != Vector2.INF:
				_drop_aoe(center, er, ep, element, col, true)  # 하늘에서 낙하 후 폭발
		"barrage":  # 거대한 돌 하나가 가장 밀집한 곳에 낙하(단일 강타). 다발(count)은 폭발 반경으로 환산.
			var center := _densest_cluster(er, pool)
			if center != Vector2.INF:
				var giant_r: float = minf(er * (1.4 + 0.1 * float(maxi(count - 3, 0))), player.MAX_SKILL_RADIUS)
				_drop_aoe(center, giant_r, ep * 2.0, element, col, false, 80, true, true)  # 거대 낙하체·풀FX·흔들림
		"chain":
			_skill_chain(count, ep, element, pool)
		"freeze":
			for e in pool:
				if is_instance_valid(e):
					e.apply_slow(0.3, 2.5)
					_skill_hit(e, ep, element)
			host._skill_ring(Vector2(360, 420), 460.0, Color(0.5, 0.8, 1.0), "water")  # 화면 전체 서리 폭발
			_snowfall()  # 화면 가득 떨어지는 눈송이
			var sfx = PIXEL_FX.new()  # 외부 물 FX(중앙 대형)
			sfx.position = Vector2(360, 420)
			fx_root.add_child(sfx)
			sfx.play(FX_WATER, 6, 220.0, 16.0)
		"thorns":  # 가시밭: 가장 밀집한 곳에 초기 광역 피해 + 지속 가시 장판(속성색=초록)
			var tc := _densest_cluster(er, pool)
			if tc != Vector2.INF:
				_skill_aoe(tc, er, ep, false, element)
				_ground_field(tc, er, ep, element)
				host._skill_ring(tc, er, col, element)
				_thorn_erupt(tc, er)  # 가시 솟구침 연출
				var nfx = PIXEL_FX.new()  # 외부 자연 FX
				nfx.position = tc
				fx_root.add_child(nfx)
				nfx.play(FX_WOOD, 6, er * 1.4, 16.0)
		"inferno":  # 불바다: 밀집 지점에 화염 작렬(광역 피해 + 화상) + 잔류 화염 장판(지속 피해)
			var fc := _densest_cluster(er, pool)
			if fc != Vector2.INF:
				_skill_aoe(fc, er, ep, true, element)   # 광역 피해 + 화상 부여
				_ground_field(fc, er, ep, element)       # 잔류 화염 장판(DoT)
				host._skill_ring(fc, er, col, element)
				_scorch(fc, er)  # 그을음 자국
				var xfx = PIXEL_FX.new()  # 외부 CC0 팩 픽셀 폭발(유성=절차 생성과 비교용 A/B)
				xfx.position = fc
				fx_root.add_child(xfx)
				xfx.play(FX_EXPLOSION_EXT, 10, er * 2.2, 60.0, Color.WHITE, 5)  # 10x5=50프레임 격자
		"rockfall":  # 낙석: 여러 바위가 흩어진 적 위로 분산 낙하(각 중간 폭발). count=바위 수
			var pts := _random_enemy_points(count, pool)
			for pt in pts:
				_drop_aoe(pt, er, ep, element, col, false, 32, false)  # 바위당 가벼운 FX·흔들림은 1회로 묶음
			if not pts.is_empty():
				host._add_shake(3.0)
		"glacier":  # 빙하: 밀집 지점에 얼음 작렬 — 국지 고피해 + 강한 둔화 부여
			var gc := _densest_cluster(er, pool)
			if gc != Vector2.INF:
				for e in EnemyCache.all():
					if is_instance_valid(e) and gc.distance_to(e.global_position) <= er:
						_skill_hit(e, ep, element)
						if is_instance_valid(e) and e.hp > 0.0:
							e.apply_slow(0.3, 3.0)  # 강한 둔화(국지·서리바람보다 길게)
				host._skill_ring(gc, er, col, element)
				_particle_fx(gc, Color(0.7, 0.9, 1.0), 40, 0.7, 60.0, 190.0, 120.0, 1.5, 3.5)  # 얼음 파편 비산
				var gfx = PIXEL_FX.new()  # 외부 물 FX
				gfx.position = gc
				fx_root.add_child(gfx)
				gfx.play(FX_WATER, 6, er * 2.0, 16.0)
	host._add_shake(4.0)

## 스킬 1회 명중 파이프라인: pre_damage(격노·치명) → 상성·분산 → 피해·흡혈 → on_hit(반응) → on_kill(폭발) → 숫자.
## 동적 효과는 player.hit_modifiers(전략 Strategy)가 담당하고, 이 함수는 순서·코어 피해식만 책임진다(SRP).
func _skill_hit(e, dmg: float, element: String) -> void:
	var p = player
	_hit_ctx.reset(e, dmg, element, self, p)
	for m in p.hit_modifiers:
		m.on_pre_damage(_hit_ctx)  # 격노·치명 등 피해 보정
	_hit_ctx.mult = ElementLib.multiplier(element, e.element)  # 오행 상성
	_hit_ctx.pos = e.global_position  # take_damage로 free되기 전 좌표 캡처
	var d := _hit_ctx.damage * _hit_ctx.mult * randf_range(0.95, 1.05)  # ±5% 분산
	_hit_ctx.dealt = d
	e.take_damage(d)
	if p.lifesteal > 0.0:
		p.heal(d * p.lifesteal)  # 흡혈
	if is_instance_valid(e) and e.hp > 0.0:
		for m in p.hit_modifiers:
			m.on_hit(_hit_ctx)   # 파쇄·기폭·화상·둔화·점화·즉사·넉백 (순서 보존)
	_apply_element_reactions(e, element)  # 증발·빙결파쇄 (속성×상태 베이스라인 반응)
	if is_instance_valid(e) and e.hp <= 0.0:
		for m in p.hit_modifiers:
			m.on_kill(_hit_ctx)  # 처치 폭발
	host._damage_number(_hit_ctx.pos, d, _hit_ctx.is_crit, false, _hit_ctx.mult > 1.0)

# --- 원소 반응(Element Reaction) — Phase 2 ---
## 속성×상태 베이스라인 반응(카드와 별개로 상성을 살림). 카드(기폭/파쇄)가 이미 상태를 소모했으면
## 현재 상태(is_burning/is_slowed)를 보고 자연히 건너뛰어 중복 폭발을 막는다.
func _apply_element_reactions(e, element: String) -> void:
	if not is_instance_valid(e) or e.hp <= 0.0:
		return
	if element == "water" and e.is_burning():  # 증발: 물로 화상 적 타격 → 화상 소모 + 광역 + %체력
		var pos: Vector2 = e.global_position  # take_percent_damage로 free될 수 있어 먼저 캡처
		e.consume_burn()
		e.take_percent_damage(REACTION_HP_PCT)  # 복리 체력 관통(% 최대체력)
		_explode(pos, _hit_ctx.dealt, element)
	elif (element == "metal" or element == "earth") and e.is_slowed():  # 빙결파쇄: 금/토로 둔화 적 → 추가타 + %체력
		e.take_damage(_hit_ctx.dealt * 0.6)
		if is_instance_valid(e):
			e.take_percent_damage(REACTION_HP_PCT)

## 과부하(Overload): 화상+둔화 중첩이 형성될 때 StatusEffects.reaction(Observer) → 이 핸들러.
## 상태 부여 도중(재진입) 방출되므로 효과는 call_deferred로 다음 프레임에 안전 처리.
func on_reaction(name: String, _source_element: String, enemy) -> void:
	if name == "overload":
		_overload.call_deferred(enemy)

func _overload(enemy) -> void:
	if not is_instance_valid(enemy):
		return
	var pos: Vector2 = enemy.global_position
	_explode(pos, player.build.damage * 2.0, enemy.element)  # 빌드 공격력 기반 광역
	for e in EnemyCache.all():  # 넉백 대신 광역 둔화 — 폭발 범위 적을 잠시 강하게 둔화(밀치지 않아 웨이브 안 늘어남)
		if is_instance_valid(e) and e.hp > 0.0 and pos.distance_to(e.global_position) <= 72.0:
			e.apply_slow(0.25, 1.5)

## 처치 폭발: 중심 주변 적에게 직접 피해(+연출). _skill_hit를 안 거쳐 재귀 폭발 방지.
func _explode(center: Vector2, dmg: float, element: String) -> void:
	_skill_burst(center, Color(1.0, 0.6, 0.2))
	host._skill_ring(center, 72.0, Color(1.0, 0.55, 0.15))
	for e in EnemyCache.all():
		if is_instance_valid(e) and center.distance_to(e.global_position) <= 72.0:
			e.take_damage(dmg * ElementLib.multiplier(element, e.element) * randf_range(0.95, 1.05))

## 반경 내 적에게 스킬 피해(+선택적 화상) — 스킬 자체 속성 상성 적용
func _skill_aoe(center: Vector2, radius: float, dmg: float, burn: bool, element: String) -> void:
	for e in EnemyCache.all():
		if is_instance_valid(e) and center.distance_to(e.global_position) <= radius:
			_skill_hit(e, dmg, element)
			if burn:
				e.apply_burn(RelicLib.RELIC_BURN_DPS, RelicLib.RELIC_BURN_DUR)

func _skill_burst(pos: Vector2, color: Color) -> void:
	_skill_burst_n(pos, color, 64)  # 기본(단발 광역) — 화려

## 파편 수를 지정하는 버스트(융단폭격처럼 다발일 때 폭탄당 적게 → 총량 제어)
func _skill_burst_n(pos: Vector2, color: Color, amount: int) -> void:
	var b = DEATH_BURST_SCENE.instantiate()
	b.position = pos
	b.color = color
	b.amount = amount
	b.lifetime = 0.9     # 파편이 오래 흩날림
	fx_root.add_child(b)

## 속성별 파티클 버스트(얼음 파편·잔불·먼지) — death_burst(CPUParticles) 재사용, 런타임 튜닝.
## gravity_y<0이면 위로 떠오름(먼지 기둥). 모든 속성 입자는 웹/모바일 안전(CPU).
func _particle_fx(pos: Vector2, color: Color, amount: int, lifetime: float, vmin: float, vmax: float, gravity_y: float, smin: float, smax: float) -> void:
	var p = DEATH_BURST_SCENE.instantiate()
	p.position = pos
	p.color = color
	p.amount = amount
	p.lifetime = lifetime
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector2(0, gravity_y)
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	fx_root.add_child(p)

## 서리바람: 화면 상단 가로 전체에서 떨어지는 많은 눈송이(흰 입자, 천천히 낙하).
func _snowfall() -> void:
	var p = DEATH_BURST_SCENE.instantiate()
	p.position = Vector2(360, -10)  # 화면 위 가운데
	p.amount = 90
	p.lifetime = 1.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(380, 8)  # 가로 전체에 흩뿌림
	p.direction = Vector2(0, 1)
	p.spread = 18.0
	p.gravity = Vector2(0, 95.0)  # 천천히 낙하
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.92, 0.96, 1.0)
	fx_root.add_child(p)

## 메테오 착탄 그을음 자국
func _scorch(pos: Vector2, radius: float) -> void:
	var s = SCORCH.new()
	s.position = pos
	fx_root.add_child(s)
	s.setup(radius)

## 가시밭 가시 솟구침 연출
func _thorn_erupt(pos: Vector2, radius: float) -> void:
	var t = THORN_ERUPT.new()
	t.position = pos
	fx_root.add_child(t)
	t.setup(radius)

## 하늘에서 떨어지는 광역 스킬(메테오·융단): 화면 위에서 낙하 비주얼 → 도달 지점에 폭발+피해.
## burst_amt=폭발 파편 수(다발일 때 작게), do_shake=폭탄별 화면 흔들림(다발은 호출측이 1회만).
## giant=true면 낙하체를 크게(거대한 돌 — 융단폭격 단일 강타용).
func _drop_aoe(center: Vector2, radius: float, ep: float, element: String, col: Color, burn: bool, burst_amt: int = 64, do_shake: bool = true, giant: bool = false) -> void:
	var m = FALLING_SKILL.new()
	m.position = center + Vector2(randf_range(-30.0, 30.0), -720.0)  # 화면 위에서 시작
	var fall_px: float = clampf(radius * 0.5, 60.0, 110.0) if giant else clampf(radius * 0.35, 16.0, 50.0)
	m.setup(col, fall_px, element)  # 속성별 낙하 비주얼(불=운석/흙=바위, giant=거대)
	fx_root.add_child(m)
	var t := m.create_tween()
	t.tween_property(m, "position", center, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # 가속 낙하
	t.tween_callback(func() -> void:
		if not host.game_over:
			_skill_aoe(center, radius, ep, burn, element)  # 도달 시 폭발 피해(스킬 속성 상성)
			host._skill_ring(center, radius, col, element)
			_skill_burst_n(center, col, burst_amt)
			var sub := maxi(5, burst_amt / 3)  # 부속 입자(잔불·먼지)도 예산에 비례
			if element == "fire":  # 유성: 그을음 크레이터 + 잔불 + 픽셀 폭발 시트(아트 업그레이드 슬라이스)
				_scorch(center, radius)
				_particle_fx(center, Color(1.0, 0.6, 0.2), sub, 0.8, 60.0, 200.0, 160.0, 2.0, 4.0)
				var fx = PIXEL_FX.new()
				fx.position = center
				fx_root.add_child(fx)
				fx.play(FX_EXPLOSION_EXT, 10, radius * 2.2, 60.0, Color.WHITE, 5)  # 외부 CC0 폭발(불바다와 동일 — 불 통일)
			elif element == "earth":  # 융단폭격·낙석: 먼지 기둥 + 외부 폭발 시트(폭격 임팩트)
				_particle_fx(center, Color(0.72, 0.6, 0.42), sub, 0.95, 25.0, 110.0, -50.0, 4.0, 8.0)
				var efx = PIXEL_FX.new()
				efx.position = center
				fx_root.add_child(efx)
				efx.play(FX_EXPLOSION_EXT, 10, radius * 2.0, 60.0, Color.WHITE, 5)
			if player.build.ground_field:
				_ground_field(center, radius, ep * player.build.field_mult(), element)  # 누적 시 장판 피해↑
			if do_shake:
				host._add_shake(4.0)
		m.queue_free())

## 잔류 장판: 명중 지점에 지속 피해 필드(초당 ep의 절반)
func _ground_field(pos: Vector2, radius: float, ep: float, element: String) -> void:
	var h = GROUND_HAZARD.new()
	h.position = pos
	fx_root.add_child(h)
	h.setup(maxf(radius, 70.0), ep * 0.5, element, ElementLib.color(element))

## 마법사로부터 rng 이내의 살아있는 적 (스킬 사거리 필터)
func _enemies_in_range(rng: float) -> Array:
	var pp: Vector2 = player.global_position
	var out: Array = []
	for e in EnemyCache.all():
		if is_instance_valid(e) and pp.distance_to(e.global_position) <= rng:
			out.append(e)
	return out

## candidates(사거리 내 적) 중 가장 밀집한 위치. 비면 Vector2.INF.
func _densest_cluster(radius: float, candidates: Array) -> Vector2:
	var enemies := candidates
	if enemies.is_empty():
		return Vector2.INF
	var best: Vector2 = enemies[0].global_position
	var best_n := -1
	for e in enemies:
		var n := 0
		for o in enemies:
			if e.global_position.distance_to(o.global_position) <= radius:
				n += 1
		if n > best_n:
			best_n = n
			best = e.global_position
	return best

func _random_enemy_points(count: int, pool: Array) -> Array:
	var enemies := pool.duplicate()
	enemies.shuffle()
	var pts := []
	for e in enemies.slice(0, count):
		if is_instance_valid(e):
			pts.append(e.global_position)
	return pts

func _skill_chain(count: int, dmg: float, element: String, pool: Array) -> void:
	var enemies := pool
	if enemies.is_empty():
		return
	var pp: Vector2 = player.global_position
	enemies.sort_custom(func(a, b): return pp.distance_squared_to(a.global_position) < pp.distance_squared_to(b.global_position))
	var prev := pp
	for e in enemies.slice(0, count):
		if not is_instance_valid(e):
			continue
		var hp: Vector2 = e.global_position  # 명중 좌표 캡처(_skill_hit로 free될 수 있음)
		_skill_hit(e, dmg, element)
		_draw_arc(prev, hp)
		var sfx = PIXEL_FX.new()  # 외부 번개 스파크(명중 임팩트)
		sfx.position = hp
		fx_root.add_child(sfx)
		sfx.play(FX_METAL, 6, 56.0, 22.0)
		prev = hp

## 뇌전 연쇄 시각: 두 적 사이에 짧게 번쩍이는 선 (물리 콜백 밖에서 생성 — call_deferred)
func _on_chain(from: Vector2, to: Vector2) -> void:
	_draw_arc.call_deferred(from, to)

func _draw_arc(from: Vector2, to: Vector2) -> void:
	# 지그재그 번개: 글로우(굵고 옅은) + 코어(가늘고 밝은) 2겹 + 곁가지 1 + 노드 섬광
	var amp: float = minf(from.distance_to(to) * 0.14, 36.0)
	var pts := _jagged(from, to, 6, amp)
	_lightning_line(pts, 10.0, Color(0.6, 0.45, 1.0, 0.5))   # 글로우
	_lightning_line(pts, 3.5, Color(0.96, 0.92, 1.0, 0.98))  # 코어
	var mid: Vector2 = pts[pts.size() / 2]  # 중간에서 짧게 갈라지는 곁가지(가지치기)
	var ang := (to - from).angle() + randf_range(-1.1, 1.1)
	var tip := mid + Vector2(cos(ang), sin(ang)) * from.distance_to(to) * 0.3
	_lightning_line(_jagged(mid, tip, 3, amp * 0.6), 2.2, Color(0.85, 0.8, 1.0, 0.85))
	host._hit_spark(to, Color(0.85, 0.85, 1.0), 16.0)  # 노드 섬광

## 두 점 사이를 지그재그로 잇는 점열(양 끝 고정, 중간은 수직으로 무작위 흔듦)
func _jagged(from: Vector2, to: Vector2, segs: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var perp := (to - from).orthogonal().normalized()
	for i in segs + 1:
		var base: Vector2 = from.lerp(to, float(i) / float(segs))
		if i > 0 and i < segs:
			base += perp * randf_range(-amp, amp)
		pts.append(base)
	return pts

## 번개 선 1겹: 점열로 Line2D 생성 후 잔광 페이드하며 자멸
func _lightning_line(pts: PackedVector2Array, w: float, col: Color) -> void:
	var ln := Line2D.new()
	ln.points = pts
	ln.width = w
	ln.default_color = col
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	fx_root.add_child(ln)
	var tw := ln.create_tween()
	tw.tween_property(ln, "modulate:a", 0.0, 0.4)
	tw.tween_callback(ln.queue_free)
