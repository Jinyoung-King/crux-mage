extends Area2D
## direction 방향으로 직진하는 발사체.
## 적과 충돌하면 데미지를 주고, pierce(추가 관통 수)가 남아 있으면 통과한다.
## 캐릭터 패시브(치명타/화상/둔화)는 플레이어가 발사 시 설정한다.

@export var speed: float = 600.0

var direction := Vector2.RIGHT
var damage := 10.0
var pierce := 0
# 패시브 효과 (플레이어가 발사 시 캐릭터에서 채움)
var crit_chance := 0.0
var crit_mult := 1.0
var burn_dps := 0.0
var burn_duration := 0.0
var slow_factor := 1.0
var slow_duration := 0.0

func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area) -> void:
	if not area.is_in_group("enemies"):
		return
	var dmg := damage
	if crit_chance > 0.0 and randf() < crit_chance:
		dmg *= crit_mult  # 치명타
	area.take_damage(dmg)
	if burn_dps > 0.0:
		area.apply_burn(burn_dps, burn_duration)
	if slow_duration > 0.0:
		area.apply_slow(slow_factor, slow_duration)
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()
