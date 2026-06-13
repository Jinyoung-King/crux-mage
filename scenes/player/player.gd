extends Node2D
## 고정 위치에서 가장 가까운 적들을 자동 조준해 발사하는 마법사. 이동/입력 없음.

signal fired(projectile)
signal hp_changed(hp: float, max_hp: float)
signal died
signal skill_cast(data: Dictionary)  ## 액티브 스킬 발동 — {id,power,radius,count,element} (main이 효과 처리)
signal took_damage(amount: float)  ## 받는 피해 (빨간 데미지 숫자 표시용)

const PROJECTILE_SCENE := preload("res://scenes/projectile/projectile.tscn")
const FOCUS_SPREAD := PI / 90.0  ## 표적보다 발사 수가 많을 때 같은 표적에 겹쳐 쏘는 발사의 부채 각(≈2°)

@export var max_hp: float = 100.0

var build: BuildState
var hp: float
var character: CharacterData
var lifesteal := 0.0  ## 입힌 피해의 흡혈 비율 (영구 강화)
var relics: Array = []  ## 이번 런 보유 유물 id (보스 보상)
var skills: Array = []  ## 보유 스킬 목록(각 dict: id/name/cooldown/power/radius/count/cd_left). [0]=캐릭터 고유, 이후=카드 획득

## 유물 획득 (중복 없음)
func grant_relic(id: String) -> void:
	if not relics.has(id):
		relics.append(id)

func _process(delta: float) -> void:
	if relics.has("regen") and hp > 0.0 and hp < max_hp:
		heal(RelicLib.REGEN_PER_SEC * delta)  # 재생의 룬
	# 액티브 스킬: 보유 스킬마다 독립 쿨타임으로 자동 발동 (연사 스탯이 모든 쿨타임 단축)
	if hp > 0.0:
		for s in skills:
			s.cd_left -= delta
			if s.cd_left <= 0.0:
				_cast_skill(s)
				s.cd_left = eff_cooldown(s)

@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	hp = max_hp
	build = BuildState.new()  # 런타임 생성 (.tres 직접 참조 금지)
	attack_timer.stop()  # v0.60 스킬-캐스터 전환: 연속 평타 없음 — 공격은 _process의 스킬 자동 시전으로만

## 선택 캐릭터의 무기·기본 빌드·외형 적용 (게임 시작 시 main이 호출)
func apply_character(c: CharacterData) -> void:
	character = c
	# 캐릭터 기본 빌드 + 영구 강화(메타) 보너스 가산
	var mastery := GameState.mastery_mult(c)  # 캐릭터 숙련도: 공격력·체력 +2%/레벨
	build.damage = (c.base_damage + GameState.upgrade_value("damage", c)) * mastery
	build.fire_rate = c.base_fire_rate + GameState.upgrade_value("fire_rate", c)
	build.projectile_count = c.base_projectile_count
	max_hp = (max_hp + GameState.upgrade_value("max_hp", c)) * mastery  # 기본 100 + 강화, 숙련 배율
	hp = max_hp
	lifesteal = GameState.upgrade_value("lifesteal", c)
	attack_timer.wait_time = 1.0 / c.base_fire_rate  # 평타 고정 (카드 연사는 스킬 쿨타임으로)
	skills.clear()
	if c.skill_id != "":  # 캐릭터 고유 스킬을 슬롯 0으로
		skills.append(_make_skill(c.skill_id, c.skill_name, c.skill_cooldown, c.skill_power, c.skill_radius, c.skill_count))
	$Sprite2D.texture = c.mage_sprite

## 웨이브 시작 시 패시브 회복 (견습 마법사)
func on_wave_start() -> void:
	if character and character.passive_wave_heal > 0.0 and hp < max_hp:
		hp = minf(hp + character.passive_wave_heal, max_hp)
		hp_changed.emit(hp, max_hp)

## 시너지 반영 실효 데미지: 기본 + (동시 표적당 데미지 × 동시 표적 수)
func effective_damage() -> float:
	var d := build.damage + build.damage_per_target * build.projectile_count
	if relics.has("berserk") and hp < max_hp * RelicLib.BERSERK_HP_RATIO:
		d *= RelicLib.BERSERK_MULT  # 격노의 룬
	return d

## 스킬 인스턴스 생성 (시작 시 쿨타임만큼 충전 필요)
func _make_skill(id: String, nm: String, cd: float, pwr: float, rad: float, cnt: int) -> Dictionary:
	var s := {"id": id, "name": nm, "cooldown": cd, "power": pwr, "radius": rad, "count": cnt, "cd_left": 0.0}
	s.cd_left = eff_cooldown(s)
	return s

## 스킬 발동: 실효 위력/범위를 풀어 main에 전달
func _cast_skill(s: Dictionary) -> void:
	skill_cast.emit({
		"id": s.id,
		"power": eff_power(s),
		"radius": eff_radius(s),
		"count": s.count,
		"element": character.element if character else "",
	})

## 실효 쿨타임: 스킬 기본쿨 × (캐릭터 기본연사 / 현재 연사). 연사가 오를수록 짧아짐, 최소 2초.
func eff_cooldown(s: Dictionary) -> float:
	if character == null or character.base_fire_rate <= 0.0 or build.fire_rate <= 0.0:
		return maxf(s.cooldown, 2.0)
	return maxf(s.cooldown * character.base_fire_rate / build.fire_rate, 2.0)

## 실효 위력 = 스킬 기본위력 × (현재 공격력/기본 공격력) × 강화배율 — 공격력 카드·강화·숙련이 모든 스킬을 키움
func eff_power(s: Dictionary) -> float:
	if character == null or character.base_damage <= 0.0:
		return s.power * build.skill_power_mult
	return s.power * (build.damage / character.base_damage) * build.skill_power_mult

func eff_radius(s: Dictionary) -> float:
	return s.radius * build.skill_radius_mult

## 주 스킬(슬롯0) 충전 진행도 0~1 (HUD 게이지용)
func skill_ratio() -> float:
	if skills.is_empty():
		return 0.0
	var s = skills[0]
	return clampf(1.0 - s.cd_left / eff_cooldown(s), 0.0, 1.0)

## 스킬 발사체 1발: 예측 조준으로 target에 마력탄을 쏨(위력=dmg). 평타 패시브/유물 미적용 — 순수 스킬.
## fired 신호로 main이 사운드·데미지숫자 연결 + Projectiles에 추가. 상성/사망연출은 발사체가 자체 처리.
func fire_skill_bolt(target, dmg: float) -> void:
	var p = PROJECTILE_SCENE.instantiate()
	if character and character.projectile_sprite:
		p.get_node("Sprite2D").texture = character.projectile_sprite
	if character:
		p.element = character.element  # 오행 상성(발사체가 명중 시 적용)
		p.crit_chance = character.passive_crit_chance
		p.crit_mult = character.passive_crit_mult
	p.position = global_position
	# 적이 아래로 이동 중이므로 비행시간만큼 앞질러 예측 조준
	var flight_time: float = global_position.distance_to(target.global_position) / p.speed
	var predicted: Vector2 = target.global_position + Vector2.DOWN * target.speed * flight_time
	p.direction = (predicted - global_position).normalized()
	if relics.has("berserk") and hp < max_hp * RelicLib.BERSERK_HP_RATIO:
		dmg *= RelicLib.BERSERK_MULT  # 격노의 룬
	p.damage = dmg
	p.lifesteal = lifesteal
	if lifesteal > 0.0:
		p.dealt.connect(_on_lifesteal)  # 명중 시 흡혈 회복
	_apply_relics_to(p)  # 수확·연쇄·점화의 룬을 발사체에 적용
	fired.emit(p)

func _on_attack_timer_timeout() -> void:
	var shots := build.projectile_count
	var targets := _nearest_enemies(shots)  # 가까운 순 최대 shots명
	if targets.is_empty():
		return
	_recoil()
	# 발사 수가 표적보다 많으면 남는 발사를 기존 표적에 집중사격(낭비 방지).
	# 같은 표적에 겹치는 발사는 살짝 부채꼴로 흩뿌려 시각 구분 + 인근 적 산탄 효과.
	for i in shots:
		var target = targets[i % targets.size()]
		var dup := i / targets.size()  # 같은 표적에 몇 번째 발사인지(0=첫 발)
		var offset := 0.0
		if dup > 0:
			var mag: float = ((dup + 1) / 2) * FOCUS_SPREAD
			offset = mag if dup % 2 == 1 else -mag
		_fire_at(target, offset)

## 발사 반동: 살짝 눌렸다가 복귀
func _recoil() -> void:
	$Sprite2D.scale = Vector2(3.4, 2.6)
	create_tween().tween_property($Sprite2D, "scale", Vector2(3, 3), 0.12)

## 가까운 순으로 최대 count명의 적을 반환
func _nearest_enemies(count: int) -> Array:
	var enemies := get_tree().get_nodes_in_group("enemies")
	enemies.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return enemies.slice(0, count)

## 적 도달 등으로 피해를 받음
func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return  # 사망 후 같은 프레임에 도달한 적의 중복 피해 방지
	amount = maxf(amount - build.defense, 1.0)  # 방어력: 받는 피해 감소(최소 1)
	took_damage.emit(amount)  # 받는 피해 숫자 표시
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()

## 카드 보너스를 빌드에 적용
func apply_card(card: CardData) -> void:
	if card.grant_skill_id != "":  # 스킬 획득 카드 — 보조 스킬을 목록에 추가(독립 쿨타임)
		var d: Dictionary = SkillLib.DEFS.get(card.grant_skill_id, {})
		if not d.is_empty():
			skills.append(_make_skill(card.grant_skill_id, d.name, d.cooldown, d.power, d.radius, d.count))
	build.damage += card.damage_bonus
	build.fire_rate += card.fire_rate_bonus  # 평타 아님 — 스킬 쿨타임 감소에 반영
	build.projectile_count += card.projectile_count_bonus
	build.damage_per_target += card.damage_per_target_bonus
	build.defense += card.defense_bonus
	build.skill_power_mult += card.skill_power_bonus
	build.skill_radius_mult += card.skill_radius_bonus
	if card.max_hp_bonus != 0.0:
		max_hp = maxf(max_hp + card.max_hp_bonus, 10.0)  # 트레이드오프로도 최소 10은 보장
		hp = minf(hp, max_hp)
		hp_changed.emit(hp, max_hp)
	if card.heal > 0.0:
		hp = minf(hp + card.heal, max_hp)
		hp_changed.emit(hp, max_hp)

func _fire_at(target, aim_offset := 0.0) -> void:
	var p = PROJECTILE_SCENE.instantiate()
	if character and character.projectile_sprite:
		p.get_node("Sprite2D").texture = character.projectile_sprite  # 캐릭터 전용 발사체 외형
	if character:
		# 패시브 효과를 발사체에 실어 보냄
		p.element = character.element  # 오행 속성(상성 판정)
		p.crit_chance = character.passive_crit_chance
		p.crit_mult = character.passive_crit_mult
		p.burn_dps = character.passive_burn_dps
		p.burn_duration = character.passive_burn_duration
		p.slow_factor = character.passive_slow_factor
		p.slow_duration = character.passive_slow_duration
		p.chain_count = character.passive_chain_count
		p.chain_factor = character.passive_chain_factor
		p.chain_range = character.passive_chain_range
		p.splash_factor = character.passive_splash_factor
		p.splash_radius = character.passive_splash_radius
	p.position = global_position  # Projectiles 컨테이너가 원점에 있어 전역 좌표와 동일
	# 적이 아래로 이동 중이므로 비행시간만큼 앞질러 조준 (1회 예측으로 충분)
	var flight_time: float = global_position.distance_to(target.global_position) / p.speed
	var predicted: Vector2 = target.global_position + Vector2.DOWN * target.speed * flight_time
	p.direction = (predicted - global_position).normalized()
	if aim_offset != 0.0:
		p.direction = p.direction.rotated(aim_offset)  # 집중사격 부채 흩뿌림
	p.damage = effective_damage()
	p.lifesteal = lifesteal
	if lifesteal > 0.0:
		p.dealt.connect(_on_lifesteal)  # 명중 시 흡혈 회복
	_apply_relics_to(p)
	fired.emit(p)

## 유물 효과를 발사체에 적용 (캐릭터 패시브 위에 가산/강화)
func _apply_relics_to(p) -> void:
	if relics.is_empty():
		return
	if relics.has("execute"):
		p.execute_threshold = RelicLib.EXECUTE_THRESHOLD
	if relics.has("chain"):
		p.chain_count += 1
		p.chain_factor = maxf(p.chain_factor, RelicLib.RELIC_CHAIN_FACTOR)
		p.chain_range = maxf(p.chain_range, 220.0)
	if relics.has("ignite"):
		p.burn_dps = maxf(p.burn_dps, RelicLib.RELIC_BURN_DPS)
		p.burn_duration = maxf(p.burn_duration, RelicLib.RELIC_BURN_DUR)

## 흡혈 회복 (발사체가 적에 피해를 입힐 때마다)
func _on_lifesteal(amount: float) -> void:
	heal(amount)

func heal(amount: float) -> void:
	if hp <= 0.0:
		return  # 사망 후에는 회복 없음
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)
