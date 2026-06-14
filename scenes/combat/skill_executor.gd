class_name SkillExecutor
extends Node
## 전투 연산·타격 판정·전투 전용 FX 실행을 main에서 분리(SRP). player.skill_cast → execute()로 구동된다.
## 의존성 주입(DI): setup()으로 player·fx_root·host를 주입. 명중 동적 효과는 player.hit_modifiers(전략)가 담당.
##
## 공유 자원은 host(main)에 위임: _skill_ring(적 사망 연출 등 공용)·_damage_number(플레이어 피격에도 사용)·
## _add_shake(카메라)·game_over(씬 상태). 이로써 전투 로직은 이 노드가, 씬 레벨 책임은 main이 갖는다.
## 성능: 적 목록은 EnemyCache.all()(물리 프레임당 1회 스냅샷)로 조회 — 폭발·광역마다 O(N) 그룹 탐색을 반복하지 않음.

const SKILL_NAME := preload("res://scenes/fx/skill_name_popup.gd")
const GROUND_HAZARD := preload("res://scenes/fx/ground_hazard.gd")
const FALLING_SKILL := preload("res://scenes/fx/falling_skill.gd")
const DEATH_BURST_SCENE := preload("res://scenes/fx/death_burst.tscn")
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
	var focus: Vector2 = player.global_position + Vector2(0, -150)  # 이름 팝업 위치(기본=마법사 위)
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
				focus = center
		"barrage":
			for pt in _random_enemy_points(count, pool):
				_drop_aoe(pt, er, ep, element, col, false)
				focus = pt
		"chain":
			_skill_chain(count, ep, element, pool)
		"freeze":
			for e in pool:
				if is_instance_valid(e):
					e.apply_slow(0.3, 2.5)
					_skill_hit(e, ep, element)
			host._skill_ring(Vector2(360, 420), 460.0, Color(0.5, 0.8, 1.0))  # 화면 전체 서리 링
			_skill_burst(Vector2(360, 420), Color(0.5, 0.8, 1.0))
			focus = Vector2(360, 360)
		"thorns":  # 가시밭: 가장 밀집한 곳에 초기 광역 피해 + 지속 가시 장판(속성색=초록)
			var tc := _densest_cluster(er, pool)
			if tc != Vector2.INF:
				_skill_aoe(tc, er, ep, false, element)
				_ground_field(tc, er, ep, element)
				host._skill_ring(tc, er, col)
				_skill_burst(tc, col)
				focus = tc
	_skill_name_popup(focus, s.name, col)  # 시전 스킬 이름 표시
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
		_reaction_popup(pos, "증발!", Color(0.5, 0.85, 1.0))
		e.take_percent_damage(REACTION_HP_PCT)  # 복리 체력 관통(% 최대체력)
		_explode(pos, _hit_ctx.dealt, element)
	elif (element == "metal" or element == "earth") and e.is_slowed():  # 빙결파쇄: 금/토로 둔화 적 → 추가타 + %체력
		var pos2: Vector2 = e.global_position
		e.take_damage(_hit_ctx.dealt * 0.6)
		if is_instance_valid(e):
			e.take_percent_damage(REACTION_HP_PCT)
		_reaction_popup(pos2, "빙결파쇄!", ElementLib.color(element))

## 과부하(Overload): 화상+둔화 중첩이 형성될 때 StatusEffects.reaction(Observer) → 이 핸들러.
## 상태 부여 도중(재진입) 방출되므로 효과는 call_deferred로 다음 프레임에 안전 처리.
func on_reaction(name: String, _source_element: String, enemy) -> void:
	if name == "overload":
		_overload.call_deferred(enemy)

func _overload(enemy) -> void:
	if not is_instance_valid(enemy):
		return
	var pos: Vector2 = enemy.global_position
	_reaction_popup(pos, "과부하!", Color(1.0, 0.72, 0.2))
	_explode(pos, player.build.damage * 2.0, enemy.element)  # 빌드 공격력 기반 광역
	if is_instance_valid(enemy) and enemy.hp > 0.0 and not enemy.is_huge:
		enemy.position.y -= 60.0  # 넉백(거대 면역)

## 반응 이름 팝업 (스킬 이름 팝업 FX 재사용)
func _reaction_popup(pos: Vector2, text: String, color: Color) -> void:
	var l = SKILL_NAME.new()
	l.position = pos + Vector2(-44, -34)
	fx_root.add_child(l)
	l.setup(text, color)

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
	var b = DEATH_BURST_SCENE.instantiate()
	b.position = pos
	b.color = color
	b.amount = 64        # 파편 ↑ (더 화려)
	b.lifetime = 0.9     # 파편이 더 오래 흩날림 (길게)
	fx_root.add_child(b)

## 하늘에서 떨어지는 광역 스킬(메테오·융단): 화면 위에서 낙하 비주얼 → 도달 지점에 폭발+피해.
func _drop_aoe(center: Vector2, radius: float, ep: float, element: String, col: Color, burn: bool) -> void:
	var m = FALLING_SKILL.new()
	m.position = center + Vector2(randf_range(-30.0, 30.0), -720.0)  # 화면 위에서 시작
	m.setup(col, clampf(radius * 0.35, 16.0, 50.0), element)  # 속성별 낙하 비주얼(불=운석/흙=바위)
	fx_root.add_child(m)
	var t := m.create_tween()
	t.tween_property(m, "position", center, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # 가속 낙하
	t.tween_callback(func() -> void:
		if not host.game_over:
			_skill_aoe(center, radius, ep, burn, element)  # 도달 시 폭발 피해(스킬 속성 상성)
			host._skill_ring(center, radius, col)
			_skill_burst(center, col)
			if player.build.ground_field:
				_ground_field(center, radius, ep, element)
			host._add_shake(4.0)
		m.queue_free())

## 잔류 장판: 명중 지점에 지속 피해 필드(초당 ep의 절반)
func _ground_field(pos: Vector2, radius: float, ep: float, element: String) -> void:
	var h = GROUND_HAZARD.new()
	h.position = pos
	fx_root.add_child(h)
	h.setup(maxf(radius, 70.0), ep * 0.5, element, ElementLib.color(element))

## 시전 스킬 이름 팝업 FX (살짝 떠오르며 사라짐)
func _skill_name_popup(pos: Vector2, txt: String, color: Color) -> void:
	var l = SKILL_NAME.new()
	l.position = pos + Vector2(-70, -20)  # 대략 가운데 정렬
	fx_root.add_child(l)
	l.setup(txt, color)

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
		_skill_hit(e, dmg, element)
		_draw_arc(prev, e.global_position)
		prev = e.global_position

## 뇌전 연쇄 시각: 두 적 사이에 짧게 번쩍이는 선 (물리 콜백 밖에서 생성 — call_deferred)
func _on_chain(from: Vector2, to: Vector2) -> void:
	_draw_arc.call_deferred(from, to)

func _draw_arc(from: Vector2, to: Vector2) -> void:
	# 글로우(굵고 옅은) + 코어(가늘고 밝은) 2겹으로 더 굵고 천천히 사라지는 번개
	var glow := Line2D.new()
	glow.add_point(from); glow.add_point(to)
	glow.width = 10.0
	glow.default_color = Color(0.6, 0.45, 1.0, 0.5)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	fx_root.add_child(glow)
	var core := Line2D.new()
	core.add_point(from); core.add_point(to)
	core.width = 3.5
	core.default_color = Color(0.96, 0.92, 1.0, 0.98)
	fx_root.add_child(core)
	for ln in [glow, core]:
		var tw = ln.create_tween()  # ln은 Array 요소(Variant)라 := 추론 불가
		tw.tween_property(ln, "modulate:a", 0.0, 0.45)  # 0.18→0.45초 (더 길게 잔광)
		tw.tween_callback(ln.queue_free)
