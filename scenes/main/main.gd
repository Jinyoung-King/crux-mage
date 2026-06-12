extends Node2D
## 메인 씬: 웨이브 진행(+무한 모드), 적 스폰, 클리어 판정, 카드 보상, 게임오버, 효과음.

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const DEATH_BURST_SCENE := preload("res://scenes/fx/death_burst.tscn")
const DEATH_REMAINS := preload("res://scenes/fx/death_remains.gd")
const ENEMY_BOLT_SCENE := preload("res://scenes/projectile/enemy_bolt.tscn")
const SPAWN_Y := -60.0  # 화면(720x1280) 위쪽 바깥
const SPAWN_X_MIN := 60.0  # 스폰 가로 범위 (가장자리 여백 확보)
const SPAWN_X_MAX := 660.0
const CHOICES_PER_CLEAR := 3
const RARITY_WEIGHT := {"common": 3.0, "rare": 1.0, "legendary": 0.3}  # 카드 등장 가중치(전설 희소)
const ENDLESS_HP_GROWTH := 0.15  # 무한 모드 단계당 적 체력 증가율
const SPEEDS := [1.0, 2.0, 3.0]  # 배속 순환 단계(탭마다 1→2→3→1x)
# 무한 모드 엘리트 수식어 (잡몹이 일정 확률로 하나를 달고 등장). 누락 배수는 1.0 취급.
const MODIFIERS := [
	{"name": "신속", "color": Color(1.0, 0.9, 0.3), "speed_mul": 1.7, "coins": 3},
	{"name": "강철", "color": Color(0.5, 0.85, 0.95), "hp_mul": 2.5, "coins": 3},
	{"name": "거대", "color": Color(1.0, 0.45, 0.4), "size_mul": 1.4, "hp_mul": 1.8, "contact_mul": 1.5, "coins": 4},
]

# 정의된 일반 웨이브들 (5의 배수 웨이브는 보스, 그 외 이후는 무한 모드로 증폭 생성)
var waves: Array = [
	preload("res://resources/waves/wave_01.tres"),
	preload("res://resources/waves/wave_02.tres"),
	preload("res://resources/waves/wave_03.tres"),
	preload("res://resources/waves/wave_04.tres"),
]
var boss_wave: WaveData = preload("res://resources/waves/wave_boss.tres")
var guardian_wave: WaveData = preload("res://resources/waves/wave_guardian.tres")
var midboss_wave: WaveData = preload("res://resources/waves/wave_midboss.tres")
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
	preload("res://resources/cards/card_proj_size.tres"),
	preload("res://resources/cards/card_proj_speed.tres"),
	preload("res://resources/cards/card_defense.tres"),
	preload("res://resources/cards/card_legendary_arcane.tres"),
	preload("res://resources/cards/card_legendary_storm.tres"),
]

var wave_index := 0
var spawn_list: Array = []  # 이번 웨이브에서 스폰할 EnemyData 순서
var endless_hp_scale := 1.0  # 이번 웨이브의 적 체력 배율 (무한 모드에서 상승)
var spawned := 0
var alive := 0
var run_coins := 0  # 이번 런 누적 코인 (사망 시 GameState에 정산)
var start_drafts_left := 0  # 웨이브 전 시작 드래프트 남은 횟수 (1 + 추가 시작 카드 레벨)
var auto_pick := false  # 테스트 편의: 웹에서 ?auto=1로 열면 카드 자동선택(숨김 개발 옵션)
var _draft_rare := false  # 현재 드래프트가 희귀 확정(보스)인지 — 리롤 시 동일 조건으로 재추첨
var game_over := false
var shake := 0.0  # 화면 흔들림 세기(px), 매 프레임 감쇠

@onready var spawn_timer: Timer = $SpawnTimer
@onready var card_select = $HUD/CardSelect
@onready var relic_select = $HUD/RelicSelect
@onready var wave_label: Label = $HUD/WaveLabel
@onready var hp_label: Label = $HUD/HpLabel
@onready var restart_button: Button = $HUD/RestartButton
@onready var flash_overlay: ColorRect = $HUD/FlashOverlay
@onready var best_label: Label = $HUD/BestLabel
@onready var char_select_button: Button = $HUD/CharSelectButton
@onready var speed_button: Button = $HUD/SpeedButton
@onready var coin_label: Label = $HUD/CoinLabel
@onready var pause_button: Button = $HUD/PauseButton
@onready var pause_screen: Control = $HUD/PauseScreen
@onready var volume_slider: HSlider = $HUD/PauseScreen/Center/VolumeSlider
@onready var mute_button: Button = $HUD/PauseScreen/Center/MuteButton

func _ready() -> void:
	var ch: CharacterData = GameState.selected
	$Player.apply_character(ch)
	$SfxShoot.stream = ch.shoot_sound  # 캐릭터 전용 발사음
	$Player.fired.connect(_on_player_fired)
	$Player.hp_changed.connect(_on_player_hp_changed)
	$Player.died.connect(_on_player_died)
	spawn_timer.timeout.connect(_spawn_enemy)
	card_select.card_chosen.connect(_on_card_chosen)
	card_select.reroll_requested.connect(_on_reroll_requested)
	relic_select.relic_chosen.connect(_on_relic_chosen)
	restart_button.pressed.connect(_on_restart_pressed)
	char_select_button.pressed.connect(_on_char_select_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	_apply_speed(GameState.game_speed)  # 저장된 배속 복원
	# 일시정지 메뉴 + 소리 설정
	pause_button.pressed.connect(_on_pause_pressed)
	$HUD/PauseScreen/Center/ResumeButton.pressed.connect(_on_resume_pressed)
	$HUD/PauseScreen/Center/RestartButton.pressed.connect(_on_restart_pressed)
	$HUD/PauseScreen/Center/MenuButton.pressed.connect(_on_char_select_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.value = GameState.sfx_volume
	_update_mute_label()
	_on_player_hp_changed($Player.hp, $Player.max_hp)  # HP 초기 표시
	_update_best_label()
	_update_coin_label()
	# 테스트 편의: 웹 URL에 ?auto=1이면 카드 자동선택 (일반 유저·출시 빌드엔 비노출)
	if OS.has_feature("web"):
		auto_pick = str(JavaScriptBridge.eval("window.location.search")).contains("auto=1")
	# 게임 시작: 시작 웨이브 도약 보정(건너뛴 분 무작위 카드 자동 지급) 후 카드 드래프트
	var sw: int = GameState.start_wave
	if sw > 1:
		_grant_head_start(int((sw - 1) * 0.7))
		$Player.heal($Player.max_hp)  # 만피로 시작
	wave_index = sw - 2  # 시작 드래프트 후 _start_wave(sw-1) = Wave sw
	start_drafts_left = 1 + GameState.upgrade_level("extra_card")
	_open_draft()

## 시작 웨이브 도약 보정: 건너뛴 웨이브분의 무작위 유효 카드를 자동 지급(빠른 복귀)
func _grant_head_start(n: int) -> void:
	for i in n:
		var drawn := _draw_cards(1)
		if not drawn.is_empty():
			$Player.apply_card(drawn[0])

func _update_best_label() -> void:
	best_label.text = "최고: Wave %d" % GameState.best_wave if GameState.best_wave > 0 else ""

func _update_coin_label() -> void:
	coin_label.text = "코인 %d" % run_coins

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

## 웨이브 종류: 끝자리 0(10,20…)=보스, 3·5·7=중간보스, 그 외=일반. 무한에서도 10단위 반복.
func _wave_kind(index: int) -> String:
	var n := (index + 1) % 10
	if n == 0:
		return "boss"
	if n == 3 or n == 5 or n == 7:
		return "midboss"
	return "normal"

## 웨이브 5 이후의 증폭 단계 (웨이브 6 → 1, 7 → 2, ...)
func _endless_level(index: int) -> int:
	return maxi(index + 1 - 5, 0)

## 보스 웨이브 회차에 따라 보스 종류 교대: 10·30·50=마왕 / 20·40=수호 마왕
func _boss_wave_for(index: int) -> WaveData:
	var ordinal := (index + 1) / 10  # 보스 등장 회차(정수 나눗셈): wave10→1, 20→2…
	return boss_wave if ordinal % 2 == 1 else guardian_wave

## 무한 모드 엘리트 굴림: 단계가 깊을수록 자주(최대 50%). 무한 전(단계 0)에는 없음.
func _roll_elite() -> Dictionary:
	var lvl := _endless_level(wave_index)
	if lvl <= 0:
		return {}
	if randf() < minf(0.12 + 0.04 * lvl, 0.5):
		return MODIFIERS[randi() % MODIFIERS.size()]
	return {}

func _start_wave(index: int) -> void:
	wave_index = index
	spawn_list = _build_spawn_list(index)
	endless_hp_scale = pow(1.0 + ENDLESS_HP_GROWTH, _endless_level(index))  # 복리: 후반 빌드 성장을 따라잡도록
	spawned = 0
	alive = 0
	var kind := _wave_kind(index)
	if kind == "boss":
		wave_label.text = "Wave %d - 보스" % (index + 1)
		_add_shake(6.0)  # 보스 등장 예고
		print("BOSS WAVE")
	elif kind == "midboss":
		wave_label.text = "Wave %d - 중간보스" % (index + 1)
		_add_shake(4.0)
		print("MIDBOSS WAVE")
	else:
		wave_label.text = "Wave %d" % (index + 1)
	spawn_timer.wait_time = _wave_interval(index)
	spawn_timer.start()
	$Player.on_wave_start()  # 패시브: 웨이브 시작 회복
	print("WAVE %d START" % (index + 1))

## 종류별 기준 구성(보스/중간보스/일반)을 가져와 무한 단계만큼 증원
func _build_spawn_list(index: int) -> Array:
	var kind := _wave_kind(index)
	var base: Array
	if kind == "boss":
		base = _boss_wave_for(index).build_spawn_list()
	elif kind == "midboss":
		base = midboss_wave.build_spawn_list()
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
	var kind := _wave_kind(index)
	var base_interval: float
	if kind == "boss":
		base_interval = _boss_wave_for(index).spawn_interval
	elif kind == "midboss":
		base_interval = midboss_wave.spawn_interval
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
	# 무한 모드 잡몹(보스·중간보스 제외)은 일정 확률로 엘리트 수식어를 달고 등장
	var elite := _roll_elite() if not data.show_hp_bar else {}
	_create_enemy(data, pos, elite)

func _create_enemy(data: EnemyData, pos: Vector2, elite: Dictionary = {}) -> void:
	if game_over:
		return  # 게임오버 이후 도착한 예약 스폰은 무시
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(data, endless_hp_scale, elite)
	enemy.position = pos
	enemy.goal_y = $Player.position.y - 30.0 - data.size / 2.0  # 플레이어 반높이 + 적 반높이
	enemy.died.connect(_on_enemy_died)
	enemy.reached_player.connect(_on_enemy_reached_player)
	enemy.summon.connect(_on_summon)
	enemy.ranged_attack.connect(_on_enemy_ranged_attack)
	enemy.charge_hit.connect(_on_enemy_charge_hit)
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

## 원거리 공격: 발사 시점의 플레이어를 향해 마탄 생성. count>1이면 플레이어 방향을
## 중심으로 ±spread/2 부채꼴 탄막(중간보스·보스). 타이머/예고 콜백이라 즉시 생성 안전.
func _on_enemy_ranged_attack(damage: float, from_pos: Vector2, count: int, spread_deg: float, bolt_scale: float) -> void:
	if game_over:
		return
	var base_angle := (Vector2($Player.position) - from_pos).angle()
	var spread := deg_to_rad(spread_deg)
	for i in count:
		var t := 0.0 if count <= 1 else float(i) / float(count - 1) - 0.5  # -0.5..0.5 (중앙=정면)
		var b = ENEMY_BOLT_SCENE.instantiate()
		b.position = from_pos
		b.direction = Vector2.from_angle(base_angle + t * spread)
		b.damage = damage
		b.visual_scale = bolt_scale
		b.hit_player.connect(_on_player_hit_by_bolt)
		$Projectiles.add_child(b)

func _on_player_hit_by_bolt(damage: float) -> void:
	$SfxPlayerHit.play()
	_add_shake(6.0)
	_flash_screen()
	$Player.take_damage(damage)

## 보스 돌진 적중: 마탄보다 크게 울리도록 흔들림 강화
func _on_enemy_charge_hit(damage: float) -> void:
	$SfxPlayerHit.play()
	_add_shake(10.0)
	_flash_screen()
	$Player.take_damage(damage)

func _on_enemy_died(pos: Vector2, color: Color, size: float, tex: Texture2D, coins: int) -> void:
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
	remains.setup(tex, size)
	if size >= 42.0:
		_add_shake(size / 8.0)  # 큰 적이 죽을수록 화면이 더 울리도록 (보스 9)
	var gain := coins  # 처치 코인 (엘리트 보너스 포함, 도달한 적은 _unregister만)
	if $Player.relics.has("greed"):
		gain *= RelicLib.GREED_MULT  # 황금의 룬
	run_coins += gain
	_update_coin_label()
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
	var bonus := wave_index + 1  # 웨이브 클리어 보너스 = 웨이브 번호
	if $Player.relics.has("greed"):
		bonus *= RelicLib.GREED_MULT
	run_coins += bonus
	_update_coin_label()
	# 보스 클리어: 안 가진 유물이 있으면 유물 선택, 없으면 카드(희귀 확정)
	if _wave_kind(wave_index) == "boss":
		var pool := _relic_pool()
		if not pool.is_empty():
			relic_select.open(pool)
			return
	_open_draft(_wave_kind(wave_index) == "boss")

## 아직 안 가진 유물 중 최대 3개 무작위
func _relic_pool() -> Array:
	var avail := RelicLib.RELICS.filter(func(r): return not $Player.relics.has(r.id))
	avail.shuffle()
	return avail.slice(0, 3)

func _on_relic_chosen(id: String) -> void:
	$SfxCardPick.play()
	$Player.grant_relic(id)
	_start_wave(wave_index + 1)

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
		pool = pool.filter(func(c): return c.rarity == "rare" or c.rarity == "legendary")
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

## 카드 드래프트 표시(희귀 확정 여부 rare). 테스트 자동선택(auto_pick) 시 잠깐 뒤 무작위 1장.
func _open_draft(rare: bool = false) -> void:
	_draft_rare = rare
	var cards := _draw_cards(CHOICES_PER_CLEAR, rare)
	card_select.open(cards)
	if auto_pick and not cards.is_empty():
		get_tree().create_timer(0.25).timeout.connect(card_select.pick_random)

## 리롤(드래프트당 1회): 같은 조건으로 새 카드를 뽑아 교체
func _on_reroll_requested() -> void:
	card_select.refill(_draw_cards(CHOICES_PER_CLEAR, _draft_rare))

func _on_card_chosen(card: CardData) -> void:
	$SfxCardPick.play()
	$Player.apply_card(card)
	# 시작 드래프트(웨이브 시작 전)가 남아 있으면 다음 드래프트, 아니면 다음 웨이브
	if start_drafts_left > 0:
		start_drafts_left -= 1
		if start_drafts_left > 0:
			_open_draft()
			return
	_start_wave(wave_index + 1)

func _on_player_hp_changed(hp: float, max_hp: float) -> void:
	hp_label.text = "HP %d / %d" % [hp, max_hp]

func _on_player_died() -> void:
	game_over = true
	print("GAME OVER")
	pause_button.hide()  # 사망 후엔 일시정지 불가(게임오버 UI 사용)
	wave_label.text = "GAME OVER - Wave %d" % (wave_index + 1)
	GameState.record_wave(wave_index + 1)  # 최고 기록 갱신·저장 (신규 해금 가능)
	GameState.add_coins(run_coins)  # 이번 런 코인 정산·저장
	coin_label.text = "코인 +%d 획득!" % run_coins
	_update_best_label()
	$SfxGameOver.play()  # process_mode=ALWAYS라 일시정지 중에도 재생됨
	# 일시정지 직전 흔들림 원위치 + 붉은 톤 고정 (멈춘 화면 연출)
	shake = 0.0
	position = Vector2.ZERO
	flash_overlay.color.a = 0.25
	get_tree().paused = true
	restart_button.show()
	char_select_button.show()

## 재시작: 일시정지 해제 후 씬 전체 리로드 (빌드/웨이브/HP 모두 초기화)
func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

## 캐릭터 선택 화면으로 (게임오버 후)
func _on_char_select_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0  # 메뉴는 1배로 (배속 설정은 GameState에 보존되어 다음 게임에 복원)
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")

## 배속 버튼: 1→2→3→1x 순환. Engine.time_scale 하나로 이동·타이머·트윈이 모두 가속됨.
func _on_speed_pressed() -> void:
	var i := SPEEDS.find(GameState.game_speed)
	var next: float = SPEEDS[(i + 1) % SPEEDS.size()]
	GameState.set_game_speed(next)
	_apply_speed(next)

func _apply_speed(s: float) -> void:
	Engine.time_scale = s
	speed_button.text = "배속 %dx" % int(s)

## 일시정지 메뉴 (PauseScreen은 process_mode=ALWAYS라 정지 중에도 버튼 동작)
func _on_pause_pressed() -> void:
	if game_over:
		return
	get_tree().paused = true
	pause_screen.show()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_screen.hide()

## 소리: 마스터 버스 음량/음소거 (GameState가 적용+영속)
func _on_volume_changed(v: float) -> void:
	GameState.set_sfx_volume(v)

func _on_mute_pressed() -> void:
	GameState.set_muted(not GameState.muted)
	_update_mute_label()

func _update_mute_label() -> void:
	mute_button.text = "음소거 해제" if GameState.muted else "음소거"

func _on_player_fired(projectile) -> void:
	$SfxShoot.play()
	if projectile.chain_count > 0:
		projectile.chained.connect(_on_chain)
	$Projectiles.add_child(projectile)

## 뇌전 연쇄 시각: 두 적 사이에 짧게 번쩍이는 선 (물리 콜백 밖에서 생성 — call_deferred)
func _on_chain(from: Vector2, to: Vector2) -> void:
	_draw_arc.call_deferred(from, to)

func _draw_arc(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 3.0
	line.default_color = Color(0.78, 0.62, 1.0, 0.95)
	$Fx.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)
