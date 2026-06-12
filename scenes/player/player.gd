extends Node2D
## 고정 위치에서 가장 가까운 적들을 자동 조준해 발사하는 마법사. 이동/입력 없음.

signal fired(projectile)
signal hp_changed(hp: float, max_hp: float)
signal died

const PROJECTILE_SCENE := preload("res://scenes/projectile/projectile.tscn")

@export var max_hp: float = 100.0

var build: BuildState
var hp: float
var character: CharacterData
var lifesteal := 0.0  ## 입힌 피해의 흡혈 비율 (영구 강화)

@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	hp = max_hp
	build = BuildState.new()  # 런타임 생성 (.tres 직접 참조 금지)
	attack_timer.wait_time = 1.0 / effective_fire_rate()
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

## 선택 캐릭터의 무기·기본 빌드·외형 적용 (게임 시작 시 main이 호출)
func apply_character(c: CharacterData) -> void:
	character = c
	# 캐릭터 기본 빌드 + 영구 강화(메타) 보너스 가산
	build.damage = c.base_damage + GameState.upgrade_value("damage")
	build.fire_rate = c.base_fire_rate + GameState.upgrade_value("fire_rate")
	build.projectile_count = c.base_projectile_count
	build.pierce = c.base_pierce + int(GameState.upgrade_value("pierce"))
	max_hp += GameState.upgrade_value("max_hp")  # 기본 100 위에 가산
	hp = max_hp
	lifesteal = GameState.upgrade_value("lifesteal")
	attack_timer.wait_time = 1.0 / effective_fire_rate()
	$Sprite2D.texture = c.mage_sprite

## 웨이브 시작 시 패시브 회복 (견습 마법사)
func on_wave_start() -> void:
	if character and character.passive_wave_heal > 0.0 and hp < max_hp:
		hp = minf(hp + character.passive_wave_heal, max_hp)
		hp_changed.emit(hp, max_hp)

## 시너지 반영 실효 데미지: 기본 + (동시 표적당 데미지 × 동시 표적 수)
func effective_damage() -> float:
	return build.damage + build.damage_per_target * build.projectile_count

## 시너지 반영 실효 연사: 기본 + (관통당 연사 × 관통 수)
func effective_fire_rate() -> float:
	return build.fire_rate + build.fire_rate_per_pierce * build.pierce

func _on_attack_timer_timeout() -> void:
	var targets := _nearest_enemies(build.projectile_count)
	if not targets.is_empty():
		_recoil()
	for target in targets:
		_fire_at(target)

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
	build.fire_rate += card.fire_rate_bonus
	build.projectile_count += card.projectile_count_bonus
	build.pierce += card.pierce_bonus
	build.damage_per_target += card.damage_per_target_bonus
	build.fire_rate_per_pierce += card.fire_rate_per_pierce_bonus
	build.projectile_size += card.projectile_size_bonus
	build.projectile_speed_bonus += card.projectile_speed_bonus
	build.defense += card.defense_bonus
	attack_timer.wait_time = 1.0 / effective_fire_rate()
	if card.max_hp_bonus != 0.0:
		max_hp = maxf(max_hp + card.max_hp_bonus, 10.0)  # 트레이드오프로도 최소 10은 보장
		hp = minf(hp, max_hp)
		hp_changed.emit(hp, max_hp)
	if card.heal > 0.0:
		hp = minf(hp + card.heal, max_hp)
		hp_changed.emit(hp, max_hp)

func _fire_at(target) -> void:
	var p = PROJECTILE_SCENE.instantiate()
	if character and character.projectile_sprite:
		p.get_node("Sprite2D").texture = character.projectile_sprite  # 캐릭터 전용 발사체 외형
	if character:
		# 패시브 효과를 발사체에 실어 보냄
		p.crit_chance = character.passive_crit_chance
		p.crit_mult = character.passive_crit_mult
		p.burn_dps = character.passive_burn_dps
		p.burn_duration = character.passive_burn_duration
		p.slow_factor = character.passive_slow_factor
		p.slow_duration = character.passive_slow_duration
	p.position = global_position  # Projectiles 컨테이너가 원점에 있어 전역 좌표와 동일
	p.speed += build.projectile_speed_bonus  # 발사체 속도 카드 (예측 조준도 이 속도로 계산)
	p.size_scale = build.projectile_size  # 발사체 크기 카드
	# 적이 아래로 이동 중이므로 비행시간만큼 앞질러 조준 (1회 예측으로 충분)
	var flight_time: float = global_position.distance_to(target.global_position) / p.speed
	var predicted: Vector2 = target.global_position + Vector2.DOWN * target.speed * flight_time
	p.direction = (predicted - global_position).normalized()
	p.damage = effective_damage()
	p.pierce = build.pierce
	p.lifesteal = lifesteal
	if lifesteal > 0.0:
		p.dealt.connect(_on_lifesteal)  # 명중 시 흡혈 회복
	fired.emit(p)

## 흡혈 회복 (발사체가 적에 피해를 입힐 때마다)
func _on_lifesteal(amount: float) -> void:
	heal(amount)

func heal(amount: float) -> void:
	if hp <= 0.0:
		return  # 사망 후에는 회복 없음
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)
