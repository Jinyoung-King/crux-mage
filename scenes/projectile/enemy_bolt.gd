extends Area2D
## 적이 플레이어에게 쏘는 마탄. 플레이어 Hitbox(레이어 4)만 감지한다.

signal hit_player(damage: float)

@export var speed: float = 230.0

var direction := Vector2.DOWN
var damage := 7.0

func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(_area) -> void:
	hit_player.emit(damage)
	queue_free()
