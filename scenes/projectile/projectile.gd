extends Area2D
## direction 방향으로 직진하는 발사체.
## 적과 충돌하면 데미지를 주고, pierce(추가 관통 수)가 남아 있으면 통과한다.

@export var speed: float = 600.0

var direction := Vector2.RIGHT
var damage := 10.0
var pierce := 0

func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area) -> void:
	if not area.is_in_group("enemies"):
		return
	area.take_damage(damage)
	if pierce > 0:
		pierce -= 1
	else:
		queue_free()
