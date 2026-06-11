extends Node2D
## 메인 씬: 웨이브 진행, 적 스폰, 클리어 판정, 카드 보상, 게임오버 흐름.

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const SPAWN_Y := -60.0  # 화면(720x1280) 위쪽 바깥
const SPAWN_X_MIN := 60.0  # 스폰 가로 범위 (가장자리 여백 확보)
const SPAWN_X_MAX := 660.0
const CHOICES_PER_CLEAR := 3

# 순서대로 진행할 웨이브들
var waves: Array = [
	preload("res://resources/waves/wave_01.tres"),
	preload("res://resources/waves/wave_02.tres"),
	preload("res://resources/waves/wave_03.tres"),
]
# 보상 후보 카드 풀 (소모되지 않으므로 같은 카드가 다시 나올 수 있음)
var card_pool: Array = [
	preload("res://resources/cards/card_damage_up.tres"),
	preload("res://resources/cards/card_fire_rate.tres"),
	preload("res://resources/cards/card_multi_shot.tres"),
	preload("res://resources/cards/card_pierce.tres"),
]

var wave_index := 0
var spawn_list: Array = []  # 이번 웨이브에서 스폰할 EnemyData 순서
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
	spawn_list = waves[index].build_spawn_list()
	spawned = 0
	alive = 0
	wave_label.text = "Wave %d / %d" % [index + 1, waves.size()]
	spawn_timer.wait_time = waves[index].spawn_interval
	spawn_timer.start()
	print("WAVE %d START" % (index + 1))

func _spawn_enemy() -> void:
	var data: EnemyData = spawn_list[spawned]
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(data)
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
	_unregister_enemy()

func _on_enemy_reached_player(contact_damage: float) -> void:
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
	if wave_index + 1 >= waves.size():
		print("ALL WAVES CLEAR")
		wave_label.text = "ALL WAVES CLEAR"
		restart_button.show()
		return
	card_select.open(_draw_cards(CHOICES_PER_CLEAR))

## 풀에서 무작위로 count장 뽑기 (풀이 작으면 있는 만큼)
func _draw_cards(count: int) -> Array:
	var pool := card_pool.duplicate()
	pool.shuffle()
	return pool.slice(0, count)

func _on_card_chosen(card: CardData) -> void:
	$Player.apply_card(card)
	_start_wave(wave_index + 1)

func _on_player_hp_changed(hp: float, max_hp: float) -> void:
	hp_label.text = "HP %d / %d" % [hp, max_hp]

func _on_player_died() -> void:
	game_over = true
	print("GAME OVER")
	wave_label.text = "GAME OVER"
	get_tree().paused = true
	restart_button.show()

## 재시작: 일시정지 해제 후 씬 전체 리로드 (빌드/웨이브/HP 모두 초기화)
func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_player_fired(projectile) -> void:
	$Projectiles.add_child(projectile)
