extends Area2D
## 위에서 스폰되어 아래(플레이어 쪽)로 직진하는 적.

signal died(pos: Vector2, color: Color, size: float)
signal reached_player(contact_damage: float)
signal summon(data: EnemyData, count: int, pos: Vector2)

@export var max_hp: float = 30.0
@export var speed: float = 60.0  ## 이동 속도(px/s)
@export var contact_damage: float = 10.0  ## 플레이어 도달 시 입히는 피해

var hp: float
var goal_y: float = 2000.0  ## 이 y까지 내려오면 플레이어에 도달 (스폰 시 main이 설정)
var effect_color := Color(0.85, 0.25, 0.25)  ## 사망 파편 색 (setup에서 지정)
var body_size := 36.0  ## 파편 양 계산용 (setup에서 지정)
# 패턴 상태 (setup에서 지정)
var zigzag_amplitude := 0.0
var zigzag_period := 2.0
var split_count := 0
var split_enemy: EnemyData
var base_x := 0.0  ## 지그재그 기준 x
var zig_t := 0.0

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	base_x = position.x
	# 등장 팝인 연출
	$Sprite2D.scale = Vector2(1.2, 1.2)
	create_tween().tween_property($Sprite2D, "scale", Vector2(3, 3), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 스폰 시 적 종류 데이터 적용 (add_child 전에 호출할 것)
## hp_scale: 무한 모드 체력 배율
func setup(data: EnemyData, hp_scale: float = 1.0) -> void:
	max_hp = data.hp * hp_scale
	speed = data.speed
	contact_damage = data.contact_damage
	effect_color = data.effect_color
	body_size = data.size
	zigzag_amplitude = data.zigzag_amplitude
	zigzag_period = data.zigzag_period
	split_count = data.split_count
	split_enemy = data.split_enemy
	if data.summon_interval > 0.0:
		var t := Timer.new()
		t.wait_time = data.summon_interval
		t.autostart = true  # 트리 진입 시 자동 시작
		t.timeout.connect(_on_summon_timer.bind(data))
		add_child(t)
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
	if zigzag_amplitude > 0.0:
		zig_t += delta
		position.x = clampf(base_x + sin(zig_t * TAU / zigzag_period) * zigzag_amplitude, 30.0, 690.0)
	if position.y >= goal_y:
		hp = 0.0  # 도달한 적은 이후 피격/사망 처리에서 제외
		reached_player.emit(contact_damage)
		queue_free()

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return  # 같은 프레임에 여러 발 맞았을 때 중복 사망 처리 방지
	hp -= amount
	_flash()
	if hp <= 0.0:
		# 분열: 처치로 죽을 때만 (도달로 빠지면 분열 없음). died보다 먼저 emit해야
		# 마지막 적이 분열할 때 웨이브 클리어가 새끼 생성 전에 판정되는 것을 막는다.
		if split_count > 0 and split_enemy != null:
			summon.emit(split_enemy, split_count, global_position)
		died.emit(global_position, effect_color, body_size)
		queue_free()

func _on_summon_timer(data: EnemyData) -> void:
	if hp > 0.0:
		summon.emit(data.summon_enemy, data.summon_count, global_position)

## 피격 플래시: 밝게 번쩍였다가 원색으로
func _flash() -> void:
	$Sprite2D.modulate = Color(3.0, 3.0, 3.0)
	create_tween().tween_property($Sprite2D, "modulate", Color.WHITE, 0.12)
