extends Node2D
## 고정 위치에서 가장 가까운 적들을 자동 조준해 발사하는 마법사. 이동/입력 없음.

signal fired(projectile)
signal hp_changed(hp: float, max_hp: float)
signal died
signal skill_cast(skill_id: String)  ## 액티브 스킬 발동 (main이 효과 처리)

const PROJECTILE_SCENE := preload("res://scenes/projectile/projectile.tscn")
const FOCUS_SPREAD := PI / 90.0  ## 표적보다 발사 수가 많을 때 같은 표적에 겹쳐 쏘는 발사의 부채 각(≈2°)

@export var max_hp: float = 100.0

var build: BuildState
var hp: float
var character: CharacterData
var lifesteal := 0.0  ## 입힌 피해의 흡혈 비율 (영구 강화)
var relics: Array = []  ## 이번 런 보유 유물 id (보스 보상)
var skill_cd_left := 0.0  ## 액티브 스킬 쿨타임 남은 시간(초)

## 유물 획득 (중복 없음)
func grant_relic(id: String) -> void:
	if not relics.has(id):
		relics.append(id)

func _process(delta: float) -> void:
	if relics.has("regen") and hp > 0.0 and hp < max_hp:
		heal(RelicLib.REGEN_PER_SEC * delta)  # 재생의 룬
	# 액티브 스킬: 쿨타임마다 자동 발동 (연사 스탯이 쿨타임 단축)
	if hp > 0.0 and character and character.skill_id != "":
		skill_cd_left -= delta
		if skill_cd_left <= 0.0:
			skill_cast.emit(character.skill_id)
			skill_cd_left = effective_skill_cooldown()

@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	hp = max_hp
	build = BuildState.new()  # 런타임 생성 (.tres 직접 참조 금지)
	attack_timer.wait_time = 0.5  # 임시값 — apply_character에서 캐릭터 기본 연사로 고정
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

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
	skill_cd_left = effective_skill_cooldown()
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

## 실효 스킬 쿨타임: 기본 × (캐릭터 기본연사 / 현재 연사). 연사가 오를수록 짧아짐, 최소 2초.
func effective_skill_cooldown() -> float:
	if character == null or character.base_fire_rate <= 0.0 or build.fire_rate <= 0.0:
		return 8.0
	return maxf(character.skill_cooldown * character.base_fire_rate / build.fire_rate, 2.0)

## 스킬 충전 진행도 0~1 (HUD 게이지용)
func skill_ratio() -> float:
	return clampf(1.0 - skill_cd_left / effective_skill_cooldown(), 0.0, 1.0)

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
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()

## 카드 보너스를 빌드에 적용
func apply_card(card: CardData) -> void:
	build.damage += card.damage_bonus
	build.fire_rate += card.fire_rate_bonus  # 평타 아님 — 스킬 쿨타임 감소에 반영
	build.projectile_count += card.projectile_count_bonus
	build.damage_per_target += card.damage_per_target_bonus
	build.defense += card.defense_bonus
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
