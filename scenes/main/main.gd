extends Node2D
## 메인 씬: 웨이브 진행(+무한 모드), 적 스폰, 클리어 판정, 카드 보상, 게임오버, 효과음.

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const SPAWN_Y := -60.0  # 화면(720x1280) 위쪽 바깥
const SPAWN_X_MIN := 60.0  # 스폰 가로 범위 (가장자리 여백 확보)
const SPAWN_X_MAX := 660.0
const CHOICES_PER_CLEAR := 3
const RARITY_WEIGHT := {"common": 3.0, "rare": 1.0}  # 카드 등장 가중치
const ENDLESS_HP_GROWTH := 0.15  # 무한 모드 단계당 적 체력 증가율

# 정의된 웨이브들 (다 깨면 무한 모드로 증폭 생성)
var waves: Array = [
	preload("res://resources/waves/wave_01.tres"),
	preload("res://resources/waves/wave_02.tres"),
	preload("res://resources/waves/wave_03.tres"),
	preload("res://resources/waves/wave_04.tres"),
	preload("res://resources/waves/wave_05.tres"),
]
# 보상 후보 카드 풀 (소모되지 않으므로 같은 카드가 다시 나올 수 있음)
var card_pool: Array = [
	preload("res://resources/cards/card_damage_up.tres"),
	preload("res://resources/cards/card_fire_rate.tres"),
	preload("res://resources/cards/card_multi_shot.tres"),
	preload("res://resources/cards/card_pierce.tres"),
	preload("res://resources/cards/card_heal.tres"),
	preload("res://resources/cards/card_damage_big.tres"),
	preload("res://resources/cards/card_fire_rate_big.tres"),
]

var wave_index := 0
var spawn_list: Array = []  # 이번 웨이브에서 스폰할 EnemyData 순서
var endless_hp_scale := 1.0  # 이번 웨이브의 적 체력 배율 (무한 모드에서 상승)
var spawned := 0
var alive := 0
var game_over := false

@onready var spawn_timer: Timer = $SpawnTimer
@onready var card_select = $HUD/CardSelect
@onready var wave_label: Label = $HUD/WaveLabel
@onready var hp_label: Label = $HUD/HpLabel
@onready var restart_button: Button = $HUD/RestartButton

func _ready() -> void:
	$Player.fired.connect(_on_player_fired)
	$Player.hp_changed.connect(_on_player_hp_changed)
	$Player.died.connect(_on_player_died)
	spawn_timer.timeout.connect(_spawn_enemy)
	card_select.card_chosen.connect(_on_card_chosen)
	restart_button.pressed.connect(_on_restart_pressed)
	_on_player_hp_changed($Player.hp, $Player.max_hp)  # HP 초기 표시
	_start_wave(0)

func _start_wave(index: int) -> void:
	wave_index = index
	spawn_list = _build_spawn_list(index)
	var endless_level: int = maxi(index - waves.size() + 1, 0)
	endless_hp_scale = pow(1.0 + ENDLESS_HP_GROWTH, endless_level)  # 복리: 후반 빌드 성장을 따라잡도록
	spawned = 0
	alive = 0
	wave_label.text = "Wave %d" % (index + 1)
	spawn_timer.wait_time = _wave_interval(index)
	spawn_timer.start()
	print("WAVE %d START" % (index + 1))

## 정의된 웨이브는 데이터에서, 그 이후(무한 모드)는 마지막 웨이브를 증폭해 생성
func _build_spawn_list(index: int) -> Array:
	if index < waves.size():
		return waves[index].build_spawn_list()
	var level: int = index - waves.size() + 1  # 무한 1단계, 2단계, ...
	var list: Array = waves.back().build_spawn_list()
	var extra := int(list.size() * 0.25 * level)
	for i in extra:
		list.append(list[randi() % list.size()])  # 기존 구성 비율대로 증원
	list.shuffle()
	return list

func _wave_interval(index: int) -> float:
	if index < waves.size():
		return waves[index].spawn_interval
	var level: int = index - waves.size() + 1
	return maxf(waves.back().spawn_interval * pow(0.95, level), 0.25)

func _spawn_enemy() -> void:
	var data: EnemyData = spawn_list[spawned]
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(data, endless_hp_scale)
	enemy.position = Vector2(randf_range(SPAWN_X_MIN, SPAWN_X_MAX), SPAWN_Y)
	enemy.goal_y = $Player.position.y - 30.0 - data.size / 2.0  # 플레이어 반높이 + 적 반높이
	enemy.died.connect(_on_enemy_died)
	enemy.reached_player.connect(_on_enemy_reached_player)
	$Enemies.add_child(enemy)
	spawned += 1
	alive += 1
	if spawned >= spawn_list.size():
		spawn_timer.stop()

func _on_enemy_died() -> void:
	$SfxEnemyDie.play()
	_unregister_enemy()

func _on_enemy_reached_player(contact_damage: float) -> void:
	$SfxPlayerHit.play()
	$Player.take_damage(contact_damage)
	_unregister_enemy()

## 사망/도달로 적이 빠질 때의 공통 집계. 웨이브 클리어 판정도 여기서.
func _unregister_enemy() -> void:
	alive -= 1
	if game_over:
		return  # 마지막 적 도달로 게임오버가 된 경우 카드 UI를 띄우지 않음
	if spawned >= spawn_list.size() and alive == 0:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	print("WAVE CLEAR")
	card_select.open(_draw_cards(CHOICES_PER_CLEAR))

## 풀에서 희귀도 가중치로 count장 중복 없이 뽑기
func _draw_cards(count: int) -> Array:
	var pool := card_pool.duplicate()
	var picked: Array = []
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += RARITY_WEIGHT.get(c.rarity, 3.0)
		var r := randf() * total
		for c in pool:
			r -= RARITY_WEIGHT.get(c.rarity, 3.0)
			if r <= 0.0:
				picked.append(c)
				pool.erase(c)
				break
	return picked

func _on_card_chosen(card: CardData) -> void:
	$SfxCardPick.play()
	$Player.apply_card(card)
	_start_wave(wave_index + 1)

func _on_player_hp_changed(hp: float, max_hp: float) -> void:
	hp_label.text = "HP %d / %d" % [hp, max_hp]

func _on_player_died() -> void:
	game_over = true
	print("GAME OVER")
	wave_label.text = "GAME OVER - Wave %d" % (wave_index + 1)
	$SfxGameOver.play()  # process_mode=ALWAYS라 일시정지 중에도 재생됨
	get_tree().paused = true
	restart_button.show()

## 재시작: 일시정지 해제 후 씬 전체 리로드 (빌드/웨이브/HP 모두 초기화)
func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_player_fired(projectile) -> void:
	$SfxShoot.play()
	$Projectiles.add_child(projectile)
