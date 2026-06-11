extends Node2D
## 고정 위치에서 가장 가까운 적들을 자동 조준해 발사하는 마법사. 이동/입력 없음.

signal fired(projectile)
signal hp_changed(hp: float, max_hp: float)
signal died

const PROJECTILE_SCENE := preload("res://scenes/projectile/projectile.tscn")

@export var max_hp: float = 100.0

var build: BuildState
var hp: float

@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	hp = max_hp
	build = BuildState.new()  # 런타임 생성 (.tres 직접 참조 금지)
	attack_timer.wait_time = 1.0 / build.fire_rate
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

func _on_attack_timer_timeout() -> void:
	for target in _nearest_enemies(build.projectile_count):
		_fire_at(target)

## 가까운 순으로 최대 count명의 적을 반환
func _nearest_enemies(count: int) -> Array:
	var enemies := get_tree().get_nodes_in_group("enemies")
	enemies.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return enemies.slice(0, count)

## 적 도달 등으로 피해를 받음
func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return  # 사망 후 같은 프레임에 도달한 적의 중복 피해 방지
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
	attack_timer.wait_time = 1.0 / build.fire_rate
	if card.heal > 0.0:
		hp = minf(hp + card.heal, max_hp)
		hp_changed.emit(hp, max_hp)

func _fire_at(target) -> void:
	var p = PROJECTILE_SCENE.instantiate()
	p.position = global_position  # Projectiles 컨테이너가 원점에 있어 전역 좌표와 동일
	# 적이 아래로 이동 중이므로 비행시간만큼 앞질러 조준 (1회 예측으로 충분)
	var flight_time: float = global_position.distance_to(target.global_position) / p.speed
	var predicted: Vector2 = target.global_position + Vector2.DOWN * target.speed * flight_time
	p.direction = (predicted - global_position).normalized()
	p.damage = build.damage
	p.pierce = build.pierce
	fired.emit(p)
