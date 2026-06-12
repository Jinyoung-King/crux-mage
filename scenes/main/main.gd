extends Node2D
## 메인 씬: 웨이브 진행(+무한 모드), 적 스폰, 클리어 판정, 카드 보상, 게임오버, 효과음.

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const DEATH_BURST_SCENE := preload("res://scenes/fx/death_burst.tscn")
const DEATH_REMAINS := preload("res://scenes/fx/death_remains.gd")
const ENEMY_BOLT_SCENE := preload("res://scenes/projectile/enemy_bolt.tscn")
const SAVE_PATH := "user://save.cfg"
const SPAWN_Y := -60.0  # 화면(720x1280) 위쪽 바깥
const SPAWN_X_MIN := 60.0  # 스폰 가로 범위 (가장자리 여백 확보)
const SPAWN_X_MAX := 660.0
const CHOICES_PER_CLEAR := 3
const RARITY_WEIGHT := {"common": 3.0, "rare": 1.0}  # 카드 등장 가중치
const ENDLESS_HP_GROWTH := 0.15  # 무한 모드 단계당 적 체력 증가율

# 정의된 일반 웨이브들 (5의 배수 웨이브는 보스, 그 외 이후는 무한 모드로 증폭 생성)
var waves: Array = [
	preload("res://resources/waves/wave_01.tres"),
	preload("res://resources/waves/wave_02.tres"),
	preload("res://resources/waves/wave_03.tres"),
	preload("res://resources/waves/wave_04.tres"),
]
var boss_wave: WaveData = preload("res://resources/waves/wave_boss.tres")
# 보상 후보 카드 풀 (소모되지 않으므로 같은 카드가 다시 나올 수 있음)
var card_pool: Array = [
	preload("res://resources/cards/card_damage_up.tres"),
	preload("res://resources/cards/card_fire_rate.tres"),
	preload("res://resources/cards/card_multi_shot.tres"),
	preload("res://resources/cards/card_pierce.tres"),
	preload("res://resources/cards/card_heal.tres"),
	preload("res://resources/cards/card_damage_big.tres"),
	preload("res://resources/cards/card_fire_rate_big.tres"),
	preload("res://resources/cards/card_multi_big.tres"),
	preload("res://resources/cards/card_chain.tres"),
	preload("res://resources/cards/card_fury.tres"),
	preload("res://resources/cards/card_blood.tres"),
	preload("res://resources/cards/card_crystal.tres"),
]

var wave_index := 0
var spawn_list: Array = []  # 이번 웨이브에서 스폰할 EnemyData 순서
var endless_hp_scale := 1.0  # 이번 웨이브의 적 체력 배율 (무한 모드에서 상승)
var spawned := 0
var alive := 0
var game_over := false
var shake := 0.0  # 화면 흔들림 세기(px), 매 프레임 감쇠
var best_wave := 0  # 최고 도달 웨이브 (user://에 저장)

@onready var spawn_timer: Timer = $SpawnTimer
@onready var card_select = $HUD/CardSelect
@onready var wave_label: Label = $HUD/WaveLabel
@onready var hp_label: Label = $HUD/HpLabel
@onready var restart_button: Button = $HUD/RestartButton
@onready var flash_overlay: ColorRect = $HUD/FlashOverlay
@onready var best_label: Label = $HUD/BestLabel

func _ready() -> void:
	$Player.fired.connect(_on_player_fired)
	$Player.hp_changed.connect(_on_player_hp_changed)
	$Player.died.connect(_on_player_died)
	spawn_timer.timeout.connect(_spawn_enemy)
	card_select.card_chosen.connect(_on_card_chosen)
	restart_button.pressed.connect(_on_restart_pressed)
	_on_player_hp_changed($Player.hp, $Player.max_hp)  # HP 초기 표시
	_load_best()
	_update_best_label()
	_start_wave(0)

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best_wave = cf.get_value("record", "best_wave", 0)

func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("record", "best_wave", best_wave)
	cf.save(SAVE_PATH)

func _update_best_label() -> void:
	best_label.text = "최고: Wave %d" % best_wave if best_wave > 0 else ""

func _process(delta: float) -> void:
	# 화면 흔들림: 월드(Main)만 움직임 — HUD(CanvasLayer)는 영향 없음
	if shake > 0.0:
		shake = maxf(shake - 60.0 * delta, 0.0)
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	elif position != Vector2.ZERO:
		position = Vector2.ZERO

func _add_shake(amount: float) -> void:
	shake = minf(shake + amount, 14.0)

## 화면 붉은 플래시 (플레이어 피격 피드백)
func _flash_screen() -> void:
	flash_overlay.color.a = 0.35
	create_tween().tween_property(flash_overlay, "color:a", 0.0, 0.25)

## 5의 배수 웨이브가 보스 웨이브
func _is_boss_wave(index: int) -> bool:
	return (index + 1) % 5 == 0

## 웨이브 5 이후의 증폭 단계 (웨이브 6 → 1, 7 → 2, ...)
func _endless_level(index: int) -> int:
	return maxi(index + 1 - 5, 0)

func _start_wave(index: int) -> void:
	wave_index = index
	spawn_list = _build_spawn_list(index)
	endless_hp_scale = pow(1.0 + ENDLESS_HP_GROWTH, _endless_level(index))  # 복리: 후반 빌드 성장을 따라잡도록
	spawned = 0
	alive = 0
	if _is_boss_wave(index):
		wave_label.text = "Wave %d - 보스" % (index + 1)
		_add_shake(6.0)  # 보스 등장 예고
		print("BOSS WAVE")
	else:
		wave_label.text = "Wave %d" % (index + 1)
	spawn_timer.wait_time = _wave_interval(index)
	spawn_timer.start()
	print("WAVE %d START" % (index + 1))

## 정의된 웨이브는 데이터에서, 보스/무한 웨이브는 기준 구성을 증폭해 생성
func _build_spawn_list(index: int) -> Array:
	var base: Array
	if _is_boss_wave(index):
		base = boss_wave.build_spawn_list()
	elif index < waves.size():
		return waves[index].build_spawn_list()
	else:
		base = waves.back().build_spawn_list()
	var extra := int(base.size() * 0.25 * _endless_level(index))
	for i in extra:
		base.append(base[randi() % base.size()])  # 기존 구성 비율대로 증원
	base.shuffle()
	return base

func _wave_interval(index: int) -> float:
	var base_interval: float
	if _is_boss_wave(index):
		base_interval = boss_wave.spawn_interval
	elif index < waves.size():
		base_interval = waves[index].spawn_interval
	else:
		base_interval = waves.back().spawn_interval
	return maxf(base_interval * pow(0.95, _endless_level(index)), 0.25)

func _spawn_enemy() -> void:
	_spawn_one(spawn_list[spawned], Vector2(randf_range(SPAWN_X_MIN, SPAWN_X_MAX), SPAWN_Y))
	spawned += 1
	if spawned >= spawn_list.size():
		spawn_timer.stop()

## 적 1마리 생성 공통 처리 (웨이브 스폰용 — 즉시 생성)
func _spawn_one(data: EnemyData, pos: Vector2) -> void:
	alive += 1
	_create_enemy(data, pos)

func _create_enemy(data: EnemyData, pos: Vector2) -> void:
	if game_over:
		return  # 게임오버 이후 도착한 예약 스폰은 무시
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(data, endless_hp_scale)
	enemy.position = pos
	enemy.goal_y = $Player.position.y - 30.0 - data.size / 2.0  # 플레이어 반높이 + 적 반높이
	enemy.died.connect(_on_enemy_died)
	enemy.reached_player.connect(_on_enemy_reached_player)
	enemy.summon.connect(_on_summon)
	enemy.ranged_attack.connect(_on_enemy_ranged_attack)
	$Enemies.add_child(enemy)

## 보스 소환·분열: 생성은 물리 콜백 밖으로 미루되(call_deferred — 분열은 충돌 콜백 중에
## 발생해 즉시 생성하면 물리 서버 오류), 생존 수는 즉시 예약해 마지막 적이 분열로 죽을 때
## 새끼 생성 전에 웨이브 클리어가 판정되는 레이스를 막는다.
func _on_summon(data: EnemyData, count: int, pos: Vector2) -> void:
	if game_over:
		return
	for i in count:
		var offset := Vector2(randf_range(-60, 60), randf_range(-10, 30))
		var p := pos + offset
		p.x = clampf(p.x, SPAWN_X_MIN, SPAWN_X_MAX)
		alive += 1
		_create_enemy.call_deferred(data, p)

## 마술사 원거리 공격: 발사 시점의 플레이어를 향해 마탄 생성 (타이머 콜백이라 즉시 생성 안전)
func _on_enemy_ranged_attack(damage: float, from_pos: Vector2) -> void:
	if game_over:
		return
	var b = ENEMY_BOLT_SCENE.instantiate()
	b.position = from_pos
	b.direction = (Vector2($Player.position) - from_pos).normalized()
	b.damage = damage
	b.hit_player.connect(_on_player_hit_by_bolt)
	$Projectiles.add_child(b)

func _on_player_hit_by_bolt(damage: float) -> void:
	$SfxPlayerHit.play()
	_add_shake(6.0)
	_flash_screen()
	$Player.take_damage(damage)

func _on_enemy_died(pos: Vector2, color: Color, size: float, tex: Texture2D) -> void:
	$SfxEnemyDie.play()
	var burst = DEATH_BURST_SCENE.instantiate()
	burst.position = pos
	burst.color = color
	burst.amount = 12 + int(size / 4.0)  # 큰 적일수록 파편 많이 (보스 30개)
	$Fx.add_child(burst)
	# 찢긴 사체(좌/우 절반)를 남긴다 — 약 1.5초 후 스스로 사라짐
	var remains = DEATH_REMAINS.new()
	remains.position = pos
	$Fx.add_child(remains)
	remains.setup(tex)
	if size >= 72.0:
		_add_shake(10.0)  # 보스 사망은 화면이 울리도록
	_unregister_enemy()

func _on_enemy_reached_player(contact_damage: float) -> void:
	$SfxPlayerHit.play()
	_add_shake(8.0)
	_flash_screen()
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
	# 보스 웨이브 보상은 희귀 카드 확정
	card_select.open(_draw_cards(CHOICES_PER_CLEAR, _is_boss_wave(wave_index)))

## 현재 빌드에서 의미 있는 카드인지 — 죽은 픽(조건 미충족 시너지 등)을 드래프트에서 제외
func _is_card_useful(card: CardData) -> bool:
	if card.fire_rate_per_pierce_bonus > 0.0 and $Player.build.pierce == 0:
		return false  # 관통이 없으면 격노는 무의미
	if card.damage_per_target_bonus > 0.0 and $Player.build.projectile_count < 2:
		return false  # 동시 표적 1이면 연쇄의 가치가 없음
	if card.heal > 0.0 and $Player.hp >= $Player.max_hp:
		return false  # 만피에 회복 카드 금지
	if card.max_hp_bonus < 0.0 and $Player.max_hp + card.max_hp_bonus < 30.0:
		return false  # 트레이드오프로 체력이 너무 낮아지면 제외
	return true

## 풀에서 희귀도 가중치로 count장 중복 없이 뽑기. rare_only면 희귀 카드만.
func _draw_cards(count: int, rare_only: bool = false) -> Array:
	var pool := card_pool.filter(_is_card_useful)
	if rare_only:
		pool = pool.filter(func(c): return c.rarity == "rare")
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
	var reached := wave_index + 1
	if reached > best_wave:
		best_wave = reached
		_save_best()
		_update_best_label()
	$SfxGameOver.play()  # process_mode=ALWAYS라 일시정지 중에도 재생됨
	# 일시정지 직전 흔들림 원위치 + 붉은 톤 고정 (멈춘 화면 연출)
	shake = 0.0
	position = Vector2.ZERO
	flash_overlay.color.a = 0.25
	get_tree().paused = true
	restart_button.show()

## 재시작: 일시정지 해제 후 씬 전체 리로드 (빌드/웨이브/HP 모두 초기화)
func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_player_fired(projectile) -> void:
	$SfxShoot.play()
	$Projectiles.add_child(projectile)
