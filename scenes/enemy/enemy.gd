extends Area2D
## 위에서 스폰되어 아래(플레이어 쪽)로 직진하는 적.

signal died
signal reached_player(contact_damage: float)

@export var max_hp: float = 30.0
@export var speed: float = 60.0  ## 이동 속도(px/s)
@export var contact_damage: float = 10.0  ## 플레이어 도달 시 입히는 피해

var hp: float
var goal_y: float = 2000.0  ## 이 y까지 내려오면 플레이어에 도달 (스폰 시 main이 설정)

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp

## 스폰 시 적 종류 데이터 적용 (add_child 전에 호출할 것)
## hp_scale: 무한 모드 체력 배율
func setup(data: EnemyData, hp_scale: float = 1.0) -> void:
	max_hp = data.hp * hp_scale
	speed = data.speed
	contact_damage = data.contact_damage
	$Sprite2D.texture = data.sprite
	$Sprite2D.scale = Vector2(3, 3)  # 스프라이트는 size/3 픽셀 그리드로 제작됨
	# 충돌 모양은 인스턴스 간 공유되므로 새로 만들어 크기 적용
	var shape := RectangleShape2D.new()
	shape.size = Vector2(data.size, data.size)
	$CollisionShape2D.shape = shape

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return  # 이미 사망/도달 처리된 적
	position.y += speed * delta
	if position.y >= goal_y:
		hp = 0.0  # 도달한 적은 이후 피격/사망 처리에서 제외
		reached_player.emit(contact_damage)
		queue_free()

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return  # 같은 프레임에 여러 발 맞았을 때 중복 사망 처리 방지
	hp -= amount
	if hp <= 0.0:
		died.emit()
		queue_free()
