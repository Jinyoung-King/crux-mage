extends Area2D
## 적이 쏘는 마탄. 기지 판정 영역(Base/BaseHitbox, 레이어 4)만 감지 — 마법사가 아닌 기지가 맞는다.

signal hit_player(damage: float)

@export var speed: float = 230.0

var direction := Vector2.DOWN
var damage := 7.0
var visual_scale := 1.0  ## 보스 탄막은 더 굵게(생성 전 main이 지정)

func _ready() -> void:
	add_to_group("enemy_bolts")  # 웨이브 클리어 시 일괄 제거용
	rotation = direction.angle()
	$Sprite2D.scale *= visual_scale
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(_area) -> void:
	hit_player.emit(damage)
	queue_free()
