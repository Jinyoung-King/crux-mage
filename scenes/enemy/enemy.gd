extends Area2D
## 위에서 스폰되어 아래(플레이어 쪽)로 직진하는 적.

signal died(pos: Vector2, color: Color, size: float, tex: Texture2D)
signal reached_player(contact_damage: float)
signal summon(data: EnemyData, count: int, pos: Vector2)
signal ranged_attack(damage: float, from_pos: Vector2)

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
# 상태이상 (패시브)
var burn_dps := 0.0
var burn_time_left := 0.0
var slow_factor := 1.0
var slow_time_left := 0.0
var _tint := Color.WHITE  ## 상태 색조 (화상/둔화)
var _flashing := false    ## 피격 플래시 중에는 색조 덮어쓰기 보류

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
	if data.attack_interval > 0.0:
		var at := Timer.new()
		at.wait_time = data.attack_interval
		at.autostart = true
		at.timeout.connect(_on_ranged_timer.bind(data))
		add_child(at)
	$Sprite2D.texture = data.sprite
	$Sprite2D.scale = Vector2(3, 3)  # 스프라이트는 size/3 픽셀 그리드로 제작됨
	# 충돌 모양은 인스턴스 간 공유되므로 새로 만들어 크기 적용
	var shape := RectangleShape2D.new()
	shape.size = Vector2(data.size, data.size)
	$CollisionShape2D.shape = shape

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return  # 이미 사망/도달 처리된 적
	# 화상 도트 (패시브)
	if burn_time_left > 0.0:
		burn_time_left -= delta
		hp -= burn_dps * delta
		if hp <= 0.0:
			_die()
			return
	# 둔화 적용 이동
	var spd := speed
	if slow_time_left > 0.0:
		slow_time_left -= delta
		spd *= slow_factor
	position.y += spd * delta
	if zigzag_amplitude > 0.0:
		zig_t += delta
		position.x = clampf(base_x + sin(zig_t * TAU / zigzag_period) * zigzag_amplitude, 30.0, 690.0)
	# 상태 색조 갱신 (피격 플래시 중이 아닐 때만 적용)
	_update_tint()
	if not _flashing:
		$Sprite2D.modulate = _tint
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
		_die()

## 화상 적용 (패시브): 더 센 화상으로 갱신하고 지속시간 리프레시
func apply_burn(dps: float, dur: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_time_left = maxf(burn_time_left, dur)

## 둔화 적용 (패시브): 속도 배수 갱신, 지속시간 리프레시
func apply_slow(factor: float, dur: float) -> void:
	slow_factor = factor
	slow_time_left = maxf(slow_time_left, dur)

## 사망 처리 (피격사·화상사 공통)
func _die() -> void:
	# 분열: 처치로 죽을 때만 (도달로 빠지면 분열 없음). died보다 먼저 emit해야
	# 마지막 적이 분열할 때 웨이브 클리어가 새끼 생성 전에 판정되는 것을 막는다.
	if split_count > 0 and split_enemy != null:
		summon.emit(split_enemy, split_count, global_position)
	died.emit(global_position, effect_color, body_size, $Sprite2D.texture)
	queue_free()

func _on_summon_timer(data: EnemyData) -> void:
	if hp > 0.0:
		summon.emit(data.summon_enemy, data.summon_count, global_position)

func _on_ranged_timer(data: EnemyData) -> void:
	if hp > 0.0:
		ranged_attack.emit(data.attack_damage, global_position)

## 상태이상에 따른 색조: 화상=주황 끼, 둔화=푸른 끼, 둘 다면 혼합
func _update_tint() -> void:
	var c := Color.WHITE
	if burn_time_left > 0.0:
		c *= Color(1.5, 0.7, 0.45)
	if slow_time_left > 0.0:
		c *= Color(0.6, 0.8, 1.4)
	_tint = c

## 피격 플래시: 밝게 번쩍였다가 현재 상태 색조로 복귀
func _flash() -> void:
	_flashing = true
	$Sprite2D.modulate = Color(3.0, 3.0, 3.0)
	var tw := create_tween()
	tw.tween_property($Sprite2D, "modulate", _tint, 0.12)
	tw.finished.connect(func(): _flashing = false)
