extends Node2D
## 메인 씬: 웨이브 진행(+무한 모드), 적 스폰, 클리어 판정, 카드 보상, 게임오버, 효과음.

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const DEATH_BURST_SCENE := preload("res://scenes/fx/death_burst.tscn")
const DEATH_REMAINS := preload("res://scenes/fx/death_remains.gd")
const DAMAGE_NUMBER := preload("res://scenes/fx/damage_number.gd")
const SKILL_RING := preload("res://scenes/fx/skill_ring.gd")  # 광역 스킬 범위 링
const SKILL_NAME := preload("res://scenes/fx/skill_name_popup.gd")  # 시전 스킬 이름 팝업
const FALLING_SKILL := preload("res://scenes/fx/falling_skill.gd")  # 하늘에서 떨어지는 광역 스킬 비주얼
const GROUND_HAZARD := preload("res://scenes/fx/ground_hazard.gd")  # 잔류 장판
const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
var _skill_rows: Array = []  # 스킬별 쿨타임 게이지 행 {fill, label}
var _wiz_hold := false   # 마법사 롱탭(길게 누름) 진행 중
var _wiz_hold_t := 0.0   # 누른 시간 누적
const ENEMY_BOLT_SCENE := preload("res://scenes/projectile/enemy_bolt.tscn")
const SPAWN_Y := -60.0  # 화면(720x1280) 위쪽 바깥
const SPAWN_X_MIN := 60.0  # 스폰 가로 범위 (가장자리 여백 확보)
const SPAWN_X_MAX := 660.0
const CHOICES_PER_CLEAR := 3
const RARITY_WEIGHT := {"common": 3.0, "uncommon": 1.7, "rare": 1.0, "epic": 0.45, "legendary": 0.22}  # 등장 가중치(고급<희귀<영웅<전설 순 희소)
const ENDLESS_HP_GROWTH := 0.15  # 무한 모드 단계당 적 체력 증가율
const ENDLESS_DMG_GROWTH := 0.10  # 무한 모드 단계당 적 피해 증가율(체력보다 완만, 흡혈 무한지속 방지)
const ENDLESS_DMG_CAP := 12.0  # 적 피해 배율 상한 — 체력은 무한 증가하되 '한 방 즉사'는 방지(체력안배 가능)
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
var storm_wave: WaveData = preload("res://resources/waves/wave_storm.tres")
var midboss_wave: WaveData = preload("res://resources/waves/wave_midboss.tres")
var bonus_wave: WaveData = preload("res://resources/waves/wave_bonus.tres")  # 보너스(코인) 웨이브 — 무해한 보물 적
# 보상 후보 카드 풀 (소모되지 않으므로 같은 카드가 다시 나올 수 있음)
var card_pool: Array = [
	preload("res://resources/cards/card_damage_up.tres"),
	preload("res://resources/cards/card_fire_rate.tres"),
	preload("res://resources/cards/card_heal.tres"),
	preload("res://resources/cards/card_damage_big.tres"),
	preload("res://resources/cards/card_fire_rate_big.tres"),
	preload("res://resources/cards/card_blood.tres"),
	preload("res://resources/cards/card_crystal.tres"),
	preload("res://resources/cards/card_defense.tres"),
	preload("res://resources/cards/card_legendary_arcane.tres"),
	preload("res://resources/cards/card_legendary_storm.tres"),
	preload("res://resources/cards/card_glass_cannon.tres"),
	preload("res://resources/cards/card_rapid.tres"),
	preload("res://resources/cards/card_bulwark.tres"),
	preload("res://resources/cards/card_skill_power.tres"),
	preload("res://resources/cards/card_skill_radius.tres"),
	preload("res://resources/cards/card_skill_bolts.tres"),
	preload("res://resources/cards/card_skill_meteor.tres"),
	preload("res://resources/cards/card_skill_chain.tres"),
	preload("res://resources/cards/card_skill_freeze.tres"),
	preload("res://resources/cards/card_skill_barrage.tres"),
	preload("res://resources/cards/card_explode.tres"),
	preload("res://resources/cards/card_explode_big.tres"),
	preload("res://resources/cards/card_multi_target.tres"),
	preload("res://resources/cards/card_volley.tres"),
	preload("res://resources/cards/card_brand_fire.tres"),
	preload("res://resources/cards/card_brand_frost.tres"),
	preload("res://resources/cards/card_detonate.tres"),
	preload("res://resources/cards/card_shatter.tres"),
	preload("res://resources/cards/card_zealot.tres"),
	preload("res://resources/cards/card_deathblow.tres"),
	preload("res://resources/cards/card_overload.tres"),
	preload("res://resources/cards/card_echo.tres"),
	preload("res://resources/cards/card_resonance.tres"),
	preload("res://resources/cards/card_knockback.tres"),
	preload("res://resources/cards/card_pierce.tres"),
	preload("res://resources/cards/card_field.tres"),
	preload("res://resources/cards/card_reaper.tres"),
	preload("res://resources/cards/card_berserker.tres"),
	preload("res://resources/cards/card_pantheon.tres"),
]

var wave_index := 0
var spawn_list: Array = []  # 이번 웨이브에서 스폰할 EnemyData 순서
var endless_hp_scale := 1.0  # 이번 웨이브의 적 체력 배율 (무한 모드에서 상승)
var endless_dmg_scale := 1.0  # 이번 웨이브의 적 피해 배율 (무한 모드에서 상승)
var spawned := 0
var alive := 0
var run_coins := 0  # 이번 런 누적 코인 (사망 시 GameState에 정산)
var _start_build_summary: Dictionary = {}  # 시작 도약 시 자동 지급한 카드 집계 {이름: 수}
var _build_summary_shown := false  # 시작 빌드 요약 토스트는 첫 진입 1회만
var _shop_active := false  # 상점 드래프트 진행 중
var _shop_cards: Array = []
var _shop_cost: Array = []
var start_drafts_left := 0  # 웨이브 전 시작 드래프트 남은 횟수 (1 + 추가 시작 카드 레벨)
var auto_pick := false  # 테스트 편의: 웹에서 ?auto=1로 열면 카드 자동선택(숨김 개발 옵션)
var _draft_rare := false  # 현재 드래프트가 희귀 확정(보스)인지 — 리롤 시 동일 조건으로 재추첨
var game_over := false
var shake := 0.0  # 화면 흔들림 세기(px), 매 프레임 감쇠

@onready var spawn_timer: Timer = $SpawnTimer
@onready var card_select = $HUD/CardSelect
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
	for id in GameState.equipped_relics:  # 장착 유물 적용(런 시작)
		if GameState.is_relic_unlocked(id):
			$Player.grant_relic(id)
	$SfxShoot.stream = ch.shoot_sound  # 캐릭터 전용 발사음
	$Player.fired.connect(_on_player_fired)
	$Player.hp_changed.connect(_on_player_hp_changed)
	$Player.died.connect(_on_player_died)
	$Player.skill_cast.connect(_on_skill_cast)
	$Player.took_damage.connect(_on_player_took_damage)
	$HUD/WizardTapZone.gui_input.connect(_on_wizard_zone_input)  # 마법사 탭 → 능력치 창
	$HUD/StatsPanel/Center/CloseButton.pressed.connect(_close_stats)
	$HUD/StatsPanel/Dim.gui_input.connect(_on_stats_dim_input)
	spawn_timer.timeout.connect(_spawn_enemy)
	card_select.card_chosen.connect(_on_card_chosen)
	card_select.reroll_requested.connect(_on_reroll_requested)
	card_select.player = $Player  # 보유 스킬 진화명을 카드에 표시하기 위해 주입
	restart_button.pressed.connect(_on_restart_pressed)
	char_select_button.pressed.connect(_on_char_select_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	_apply_speed(GameState.game_speed)  # 저장된 배속 복원
	# 일시정지 메뉴 + 소리 설정
	pause_button.pressed.connect(_on_pause_pressed)
	$HUD/PauseScreen/Center/ResumeButton.pressed.connect(_on_resume_pressed)
	$HUD/PauseScreen/Center/RestartButton.pressed.connect(_on_restart_pressed)
	$HUD/PauseScreen/Center/MenuButton.pressed.connect(_on_give_up)
	mute_button.pressed.connect(_on_mute_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.value = GameState.sfx_volume
	_update_mute_label()
	_on_player_hp_changed($Player.hp, $Player.max_hp)  # HP 초기 표시
	_update_best_label()
	_update_coin_label()
	$HUD/VersionLabel.text = GameState.VERSION  # 빌드 버전 표기(단일 출처)
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
			var nm: String = drawn[0].card_name
			_start_build_summary[nm] = int(_start_build_summary.get(nm, 0)) + 1

## 시작 도약(시작 웨이브>1)으로 자동 지급된 빌드 요약을 첫 진입 시 토스트로 안내
func _show_start_build_summary() -> void:
	var text := ""
	for nm in _start_build_summary:
		var c: int = _start_build_summary[nm]
		var part: String = "%s×%d" % [nm, c] if c > 1 else str(nm)
		text += (", " if text != "" else "") + part
	var lbl := Label.new()
	lbl.text = "시작 빌드 ┃ " + text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_KEEP_SIZE)
	lbl.offset_top = 150.0
	lbl.offset_left = 20.0
	lbl.offset_right = -20.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(lbl)
	var t := lbl.create_tween()
	t.tween_interval(3.5)
	t.tween_property(lbl, "modulate:a", 0.0, 1.0)
	t.tween_callback(lbl.queue_free)

func _update_best_label() -> void:
	best_label.text = "최고: Wave %d" % GameState.best_wave if GameState.best_wave > 0 else ""

func _update_coin_label() -> void:
	coin_label.text = "%d" % run_coins  # 앞의 동전 아이콘(CoinIcon)이 '코인'을 표시

func _process(delta: float) -> void:
	# 마법사 롱탭: 0.4초 이상 누르고 있으면 능력치 정보 창 (짧은 탭은 무시)
	if _wiz_hold and not game_over and not get_tree().paused:
		_wiz_hold_t += delta
		if _wiz_hold_t >= 0.4:
			_wiz_hold = false
			_on_player_tapped()
	# 화면 흔들림: 월드(Main)만 움직임 — HUD(CanvasLayer)는 영향 없음
	if shake > 0.0:
		shake = maxf(shake - 60.0 * delta, 0.0)
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
	# 스킬별 쿨타임 게이지 — 각 스킬이 독립 쿨타임으로 차오르는 걸 따로 표시
	var pl = $Player
	if pl.skills.size() != _skill_rows.size():
		_rebuild_skill_rows(pl.skills)
	for i in pl.skills.size():
		var s: Dictionary = pl.skills[i]
		var r: float = pl.cd_ratio(s)
		var row: Dictionary = _skill_rows[i]
		row.label.text = s.name + ("  준비!" if r >= 1.0 else "")
		row.fill.anchor_right = r
		row.fill.color = Color(1, 0.88, 0.4, 0.9) if r >= 1.0 else Color(0.55, 0.78, 1, 0.85)

## 보유 스킬 수가 바뀌면 스킬별 쿨타임 게이지 행을 다시 만든다
func _rebuild_skill_rows(skills: Array) -> void:
	for c in $HUD/SkillUI.get_children():
		c.queue_free()
	_skill_rows.clear()
	for s in skills:
		_skill_rows.append(_make_skill_row())

## 미니 쿨타임 게이지 행(어두운 바 + 채움 + 이름) 생성 → {fill, label}
func _make_skill_row() -> Dictionary:
	var row := Control.new()
	row.custom_minimum_size = Vector2(260, 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	var fill := ColorRect.new()
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	fill.color = Color(0.55, 0.78, 1, 0.85)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	$HUD/SkillUI.add_child(row)
	return {"fill": fill, "label": label}

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
	if n == 8:
		return "bonus"  # 끝자리 8(8·18·28…): 보스 직전 코인 보너스 웨이브
	return "normal"

## 웨이브 5 이후의 증폭 단계 (웨이브 6 → 1, 7 → 2, ...)
func _endless_level(index: int) -> int:
	return maxi(index + 1 - 5, 0)

## 보스 웨이브 회차에 따라 보스 3종 순환: 마왕(10·40) / 수호 마왕(20·50) / 폭풍 마왕(30·60)
func _boss_wave_for(index: int) -> WaveData:
	var ordinal := (index + 1) / 10  # 보스 등장 회차(정수 나눗셈): wave10→1, 20→2…
	match ordinal % 3:
		1: return boss_wave
		2: return guardian_wave
		_: return storm_wave

## 보스 웨이브의 HP바 적(보스 본체) 이름 — 등장 배너용
func _boss_enemy_name(index: int) -> String:
	for entry in _boss_wave_for(index).entries:
		if entry.enemy and entry.enemy.show_hp_bar:
			return entry.enemy.display_name
	return ""

## 보스 등장 배너: 중앙 위쪽에 이름이 펀치 인 → 잠깐 유지 → 페이드 아웃
func _show_boss_banner(boss_name: String) -> void:
	if boss_name.is_empty():
		return
	var b: Label = $HUD/BossBanner
	b.text = boss_name
	b.pivot_offset = Vector2(300, 40)
	b.modulate = Color(1, 0.55, 0.55, 0.0)
	b.scale = Vector2(0.6, 0.6)
	var t := create_tween()
	t.tween_property(b, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(b, "scale", Vector2(1, 1), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(b, "modulate:a", 0.0, 0.4)

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
	$Player.skills_paused = false  # 웨이브 진행 중에는 스킬 쿨타임 재개
	spawn_list = _build_spawn_list(index)
	endless_hp_scale = pow(1.0 + ENDLESS_HP_GROWTH, _endless_level(index))  # 복리: 후반 빌드 성장을 따라잡도록
	endless_dmg_scale = minf(pow(1.0 + ENDLESS_DMG_GROWTH, _endless_level(index)), ENDLESS_DMG_CAP)  # 적 피해 상승(상한 적용)
	$HUD/ThreatLabel.text = ("적 피해 ×%.1f%s" % [endless_dmg_scale, " (최대)" if endless_dmg_scale >= ENDLESS_DMG_CAP else ""]) if endless_dmg_scale > 1.05 else ""
	spawned = 0
	alive = 0
	var kind := _wave_kind(index)
	wave_label.modulate = Color(1, 1, 1)  # 종류별 색 초기화
	if kind == "boss":
		wave_label.text = "Wave %d - 보스" % (index + 1)
		_add_shake(6.0)  # 보스 등장 예고
		_show_boss_banner(_boss_enemy_name(index))  # 보스 이름 등장 배너
		print("BOSS WAVE")
	elif kind == "midboss":
		wave_label.text = "Wave %d - 중간보스" % (index + 1)
		_add_shake(4.0)
		print("MIDBOSS WAVE")
	elif kind == "bonus":
		wave_label.text = "Wave %d - 보너스!" % (index + 1)
		wave_label.modulate = Color(1.0, 0.85, 0.3)  # 금색 강조
		print("BONUS WAVE")
	else:
		wave_label.text = "Wave %d" % (index + 1)
	spawn_timer.wait_time = _wave_interval(index)
	spawn_timer.start()
	$Player.on_wave_start()  # 패시브: 웨이브 시작 회복
	print("WAVE %d START" % (index + 1))
	if not _build_summary_shown and not _start_build_summary.is_empty():
		_build_summary_shown = true
		_show_start_build_summary()  # 시작 도약 빌드 요약(첫 진입 1회)

## 종류별 기준 구성(보스/중간보스/일반)을 가져와 무한 단계만큼 증원
func _build_spawn_list(index: int) -> Array:
	var kind := _wave_kind(index)
	var base: Array
	if kind == "boss":
		base = _boss_wave_for(index).build_spawn_list()
	elif kind == "midboss":
		base = midboss_wave.build_spawn_list()
	elif kind == "bonus":
		base = bonus_wave.build_spawn_list()  # 무한 단계만큼 보물도 증원 → 후반일수록 코인 多
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
	elif kind == "bonus":
		base_interval = bonus_wave.spawn_interval
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
	# 무한 모드 잡몹(보스·중간보스 제외)은 일정 확률로 엘리트 수식어를 달고 등장. 보너스 웨이브 보물은 제외.
	var elite := _roll_elite() if (not data.show_hp_bar and _wave_kind(wave_index) != "bonus") else {}
	_create_enemy(data, pos, elite)

func _create_enemy(data: EnemyData, pos: Vector2, elite: Dictionary = {}) -> void:
	if game_over:
		return  # 게임오버 이후 도착한 예약 스폰은 무시
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(data, endless_hp_scale, endless_dmg_scale, elite)
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

func _on_player_hit_by_bolt(damage: float, pos: Vector2) -> void:
	$SfxPlayerHit.play()
	_bolt_impact(pos)  # 탄막 명중 시 작은 폭발
	_add_shake(6.0)
	_flash_screen()
	$Player.take_damage(damage)

## 탄막 명중 임팩트: 작은 폭발 + 작은 충격파 링 (마탄 보랏빛)
func _bolt_impact(pos: Vector2) -> void:
	var b = DEATH_BURST_SCENE.instantiate()
	b.position = pos
	b.color = Color(0.82, 0.52, 1.0)
	b.amount = 14
	$Fx.add_child(b)
	_skill_ring(pos, 38.0, Color(0.85, 0.6, 1.0))

## 보스 돌진 적중: 마탄보다 크게 울리도록 흔들림 강화
func _on_enemy_charge_hit(damage: float) -> void:
	$SfxPlayerHit.play()
	_add_shake(10.0)
	_flash_screen()
	$Player.take_damage(damage)

func _on_enemy_died(pos: Vector2, color: Color, size: float, tex: Texture2D, coins: int, kind: String) -> void:
	GameState.record_kill(kind)  # 도감·처치 업적 집계 (처치만 — 도달로 사라진 적은 제외)
	if _wave_kind(wave_index) == "bonus":
		$SfxCoin.play()  # 보너스 웨이브 보물: 코인 픽업음
	else:
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

func _on_enemy_reached_player(contact_damage: float, pos: Vector2) -> void:
	if contact_damage <= 0.0:
		_unregister_enemy()  # 무해한 적(보물)은 피해·연출 없이 사라짐(놓치면 코인만 손해)
		return
	$SfxPlayerHit.play()
	_base_impact(pos.x)  # 콰과과광 — 기지 충돌 임팩트
	_add_shake(16.0)
	_flash_screen()
	$Player.take_damage(contact_damage)
	_unregister_enemy()

## 기지 충돌 임팩트: 충돌 지점에 큰 폭발 + 충격파 링 2겹
func _base_impact(x: float) -> void:
	var p := Vector2(clampf(x, 40.0, 680.0), 1150.0)  # 기지 윗변
	var b = DEATH_BURST_SCENE.instantiate()
	b.position = p
	b.color = Color(1.0, 0.5, 0.2)
	b.amount = 48
	$Fx.add_child(b)
	_skill_ring(p, 95.0, Color(1.0, 0.55, 0.2))
	_skill_ring(p, 150.0, Color(1.0, 0.8, 0.35))

## 사망/도달로 적이 빠질 때의 공통 집계. 웨이브 클리어 판정도 여기서.
func _unregister_enemy() -> void:
	alive -= 1
	if game_over:
		return  # 마지막 적 도달로 게임오버가 된 경우 카드 UI를 띄우지 않음
	if spawned >= spawn_list.size() and alive == 0:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	print("WAVE CLEAR")
	# 남은 적 탄막 제거 — 웨이브 사이 카드 선택 중 잔여 탄막에 맞지 않도록
	for b in get_tree().get_nodes_in_group("enemy_bolts"):
		b.queue_free()
	var bonus := wave_index + 1  # 웨이브 클리어 보너스 = 웨이브 번호
	if $Player.relics.has("greed"):
		bonus *= RelicLib.GREED_MULT
	run_coins += bonus
	_update_coin_label()
	# 끝자리 6 웨이브 클리어 후엔 상점(코인 사용처), 그 외엔 카드 드래프트(보스는 희귀 확정)
	if _is_shop_wave(wave_index):
		_open_shop()
	else:
		_open_draft(_wave_kind(wave_index) == "boss")

## 보유 스킬 중 범위(meteor/barrage) 스킬이 하나라도 있나
func _has_radius_skill() -> bool:
	for s in $Player.skills:
		if s.radius > 0.0:
			return true
	return false

## 보유 스킬 중 표적형(마력탄·융단·체인 — count 사용) 스킬이 있나
func _has_count_skill() -> bool:
	for s in $Player.skills:
		if s.id in ["bolts", "barrage", "chain"]:
			return true
	return false

## 마력탄(발사체) 스킬을 보유했나 — 관통 카드 유효성 (관통은 발사체에만 적용)
func _has_bolts_skill() -> bool:
	for s in $Player.skills:
		if s.id == "bolts":
			return true
	return false

## 화상 부여원(부여 카드·점화 유물·메테오 스킬)이 있나 — 기폭 카드 유효성
func _has_burn_source() -> bool:
	if $Player.build.apply_burn or $Player.relics.has("ignite"):
		return true
	for s in $Player.skills:
		if s.id == "meteor":
			return true
	return false

## 둔화 부여원(부여 카드·빙결 스킬)이 있나 — 파쇄 카드 유효성
func _has_slow_source() -> bool:
	if $Player.build.apply_slow:
		return true
	for s in $Player.skills:
		if s.id == "freeze":
			return true
	return false

## 현재 빌드에서 의미 있는 카드인지 — 죽은 픽(조건 미충족 시너지 등)을 드래프트에서 제외
func _is_card_useful(card: CardData) -> bool:
	if (card.skill_radius_bonus > 0.0 or card.grant_ground_field) and not _has_radius_skill():
		return false  # 범위 스킬(메테오/융단폭격)이 없으면 범위 강화·장판 무의미
	if card.extra_targets_bonus > 0 and not _has_count_skill():
		return false  # 표적형 스킬이 없으면 다발 무의미
	if card.pierce_bonus > 0 and not _has_bolts_skill():
		return false  # 마력탄 스킬이 없으면 관통 무의미(발사체 전용)
	if card.detonate_burn_bonus > 0.0 and not _has_burn_source():
		return false  # 화상 부여원 없으면 기폭 무의미
	if card.frostbite_bonus > 0.0 and not _has_slow_source():
		return false  # 둔화 부여원 없으면 파쇄 무의미
	if card.heal > 0.0 and $Player.hp >= $Player.max_hp:
		return false  # 만피에 회복 카드 금지
	if card.max_hp_bonus < 0.0 and $Player.max_hp + card.max_hp_bonus < 30.0:
		return false  # 트레이드오프로 체력이 너무 낮아지면 제외
	return true

## 풀에서 희귀도 가중치로 count장 중복 없이 뽑기. rare_only면 희귀 카드만.
func _draw_cards(count: int, rare_only: bool = false) -> Array:
	var pool := card_pool.filter(_is_card_useful)
	if rare_only:
		pool = pool.filter(func(c): return c.rarity in ["rare", "epic", "legendary"])  # 보스 보상: 희귀+ 확정
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
	$Player.skills_paused = true  # 드래프트 중 스킬 쿨타임 정지
	_draft_rare = rare
	var cards := _draw_cards(CHOICES_PER_CLEAR, rare)
	card_select.open(cards)
	if auto_pick and not cards.is_empty():
		get_tree().create_timer(0.25).timeout.connect(card_select.pick_random)

## 끝자리 6 웨이브 클리어 후 = 상점
func _is_shop_wave(index: int) -> bool:
	return (index + 1) % 10 == 6

## 카드 희귀도별 상점 가격(코인)
func _card_cost(card: CardData) -> int:
	match card.rarity:
		"legendary": return 65
		"epic": return 40
		"rare": return 25
		"uncommon": return 15
		_: return 8

## 상점: 카드 3장에 코인 가격. 사면 차감·적용, 건너뛰기 가능.
func _open_shop() -> void:
	$Player.skills_paused = true  # 상점 중 스킬 쿨타임 정지
	_shop_cards = _draw_cards(CHOICES_PER_CLEAR)
	_shop_cost = []
	for c in _shop_cards:
		_shop_cost.append(_card_cost(c))
	_shop_active = true
	card_select.open(_shop_cards, _shop_cost, run_coins)

## 리롤(드래프트당 1회): 같은 조건으로 새 카드를 뽑아 교체. 상점에선 '건너뛰기'.
func _on_reroll_requested() -> void:
	if _shop_active:
		_shop_active = false
		_start_wave(wave_index + 1)
		return
	card_select.refill(_draw_cards(CHOICES_PER_CLEAR, _draft_rare))

func _on_card_chosen(card: CardData) -> void:
	if _shop_active:  # 상점 구매: 코인 차감 후 적용, 다음 웨이브로
		$SfxCardPick.play()
		var idx: int = _shop_cards.find(card)
		if idx >= 0:
			run_coins = maxi(run_coins - _shop_cost[idx], 0)
			_update_coin_label()
		$Player.apply_card(card)
		_shop_active = false
		_start_wave(wave_index + 1)
		return
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
	hp_label.text = "%d / %d" % [hp, max_hp]  # 앞의 방패 아이콘(HpIcon)이 '기지 내구도'를 표시

func _on_player_died() -> void:
	game_over = true
	print("GAME OVER")
	pause_button.hide()  # 사망 후엔 일시정지 불가(게임오버 UI 사용)
	wave_label.text = "GAME OVER - Wave %d" % (wave_index + 1)
	GameState.record_wave(wave_index + 1)  # 최고 기록 갱신·저장 (신규 해금 가능)
	GameState.add_coins(run_coins)  # 이번 런 코인 정산·저장
	GameState.note_run(GameState.selected, wave_index + 1)  # 플레이 수·캐릭터별 최고 웨이브 기록
	var lvl_before: int = GameState.char_level(GameState.selected)
	GameState.add_xp(GameState.selected, wave_index + 1)  # 캐릭터 숙련 경험치(= 도달 웨이브)
	var lvl_after: int = GameState.char_level(GameState.selected)
	coin_label.text = "+%d · 숙련 +%d" % [run_coins, wave_index + 1]  # 앞의 동전 아이콘이 '코인'
	if lvl_after > lvl_before:  # 레벨업: 강조 표기 + 금색 펄스
		coin_label.text += "  → %s 숙련 Lv %d!" % [GameState.selected.display_name, lvl_after]
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

## 나가기(일시정지 메뉴): 여태 도달 기록·획득 코인을 정산하고 시작 화면으로 (수동 종료)
func _on_give_up() -> void:
	GameState.record_wave(wave_index + 1)  # 도달 웨이브 기록(영속)
	GameState.add_coins(run_coins)  # 이번 런 코인 정산(영속)
	GameState.add_xp(GameState.selected, wave_index + 1)  # 캐릭터 숙련 경험치(= 도달 웨이브)
	GameState.note_run(GameState.selected, wave_index + 1)  # 플레이 수·캐릭터별 최고 웨이브 기록
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")

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
	$HUD/PauseScreen/Center/BuildLabel.text = _build_summary()
	get_tree().paused = true
	pause_screen.show()

## 마법사 탭존(HUD 투명 Control) 입력 → 누른 시간을 _process가 재서 롱탭(0.4초)일 때만 정보 창.
func _on_wizard_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_wiz_hold = event.pressed  # 누름 시작/해제
		_wiz_hold_t = 0.0
	elif event is InputEventScreenTouch:
		_wiz_hold = event.pressed  # 모바일 터치
		_wiz_hold_t = 0.0

## 마법사 탭 → 현재 능력치 창(잠깐 멈춤). 게임오버·이미 멈춤이면 무시.
func _on_player_tapped() -> void:
	if game_over or get_tree().paused:
		return
	var p = $Player
	$HUD/StatsPanel/Center/StatsLabel.text = "기지 내구도 %d / %d\n\n%s" % [int(p.hp), int(p.max_hp), _build_summary()]
	$HUD/StatsPanel.show()
	get_tree().paused = true

func _close_stats() -> void:
	$HUD/StatsPanel.hide()
	get_tree().paused = false

## 어두운 배경을 탭해도 닫힘
func _on_stats_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_close_stats()

## 현재 빌드 요약(일시정지 표시) — 카드·강화·숙련·유물이 반영된 실효 스탯
func _build_summary() -> String:
	var p = $Player
	var b = p.build
	var lines := []
	lines.append("공격력 %d   ·   방어 %d" % [roundi(b.damage), int(b.defense)])
	for s in p.skills:  # 보유 스킬마다 쿨·피해
		lines.append("스킬 %s · 쿨 %.1f초 · 피해 %d" % [s.name, p.eff_cooldown(s), roundi(p.eff_power(s))])
	var extras := []
	if p.lifesteal > 0.0:
		extras.append("흡혈 %d%%" % roundi(p.lifesteal * 100.0))
	if not extras.is_empty():
		lines.append("   ·   ".join(extras))
	if not p.relics.is_empty():
		var names := []
		for id in p.relics:
			names.append(_relic_name(id))
		lines.append("유물: " + ", ".join(names))
	return "\n".join(lines)

func _relic_name(id: String) -> String:
	for r in RelicLib.RELICS:
		if r.id == id:
			return r.name
	return id

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
	projectile.damaged.connect(_on_projectile_damaged)
	$Projectiles.add_child(projectile)

## 직격 피해 위치에 플로팅 데미지 숫자 생성 (비물리 FX라 충돌 콜백 중 즉시 추가 안전)
func _on_projectile_damaged(amount: float, is_crit: bool, pos: Vector2, is_strong := false) -> void:
	var dn = DAMAGE_NUMBER.new()
	dn.position = pos
	$Fx.add_child(dn)
	dn.setup(amount, is_crit, false, is_strong)

## 플레이어가 받는 피해 — 머리 위에 빨간 숫자
func _on_player_took_damage(amount: float) -> void:
	var dn = DAMAGE_NUMBER.new()
	dn.position = $Player.global_position + Vector2(0, -40)
	$Fx.add_child(dn)
	dn.setup(amount, false, true)

## --- 액티브 스킬 (player.skill_cast → 효과 처리. _process 흐름이라 비물리=안전) ---
func _on_skill_cast(s: Dictionary) -> void:
	if game_over:
		return
	var ep: float = s.power
	var er: float = s.radius
	var element: String = s.element
	var count: int = s.count + $Player.build.extra_targets  # 다발: 표적형 스킬 추가 표적
	var col: Color = ElementLib.color(element)
	var focus: Vector2 = $Player.global_position + Vector2(0, -150)  # 이름 팝업 위치(기본=마법사 위)
	var rng: float = SkillLib.SKILL_RANGE.get(s.id, 99999.0)  # 스킬별 사거리
	var pool := _enemies_in_range(rng)  # 사거리 내 적만 타겟
	match s.id:
		"bolts":
			var pp: Vector2 = $Player.global_position
			pool.sort_custom(func(a, b): return pp.distance_squared_to(a.global_position) < pp.distance_squared_to(b.global_position))
			for e in pool.slice(0, count):
				if is_instance_valid(e):
					$Player.fire_skill_bolt(e, ep)  # 보이는 마력탄이 날아가 명중(상성·데미지숫자 자체 처리)
		"meteor":
			var center := _densest_cluster(er, pool)
			if center != Vector2.INF:
				_drop_aoe(center, er, ep, element, col, true)  # 하늘에서 낙하 후 폭발
				focus = center
		"barrage":
			for pt in _random_enemy_points(count, pool):
				_drop_aoe(pt, er, ep, element, col, false)
				focus = pt
		"chain":
			_skill_chain(count, ep, element, pool)
		"freeze":
			for e in pool:
				if is_instance_valid(e):
					e.apply_slow(0.3, 2.5)
					_skill_hit(e, ep, element)
			_skill_ring(Vector2(360, 420), 460.0, Color(0.5, 0.8, 1.0))  # 화면 전체 서리 링
			_skill_burst(Vector2(360, 420), Color(0.5, 0.8, 1.0))
			focus = Vector2(360, 360)
	_skill_name_popup(focus, s.name, col)  # 시전 스킬 이름 표시
	_add_shake(4.0)

## 광역 스킬 범위 링 FX
func _skill_ring(pos: Vector2, radius: float, color: Color) -> void:
	var r = SKILL_RING.new()
	r.position = pos
	$Fx.add_child(r)
	r.setup(radius, color)

## 잔류 장판: 명중 지점에 지속 피해 필드(초당 ep의 절반)
func _ground_field(pos: Vector2, radius: float, ep: float, element: String) -> void:
	var h = GROUND_HAZARD.new()
	h.position = pos
	$Fx.add_child(h)
	h.setup(maxf(radius, 70.0), ep * 0.5, element, ElementLib.color(element))

## 시전 스킬 이름 팝업 FX (살짝 떠오르며 사라짐)
func _skill_name_popup(pos: Vector2, txt: String, color: Color) -> void:
	var l = SKILL_NAME.new()
	l.position = pos + Vector2(-70, -20)  # 대략 가운데 정렬
	$Fx.add_child(l)
	l.setup(txt, color)

## 스킬 1회 명중: 격노·치명타·상성 적용 → 피해 → 흡혈·점화·즉사(유물/흡혈 공용) + 데미지 숫자
func _skill_hit(e, dmg: float, element: String) -> void:
	var p = $Player
	if p.relics.has("berserk") and p.hp < p.max_hp * RelicLib.BERSERK_HP_RATIO:
		dmg *= RelicLib.BERSERK_MULT  # 격노의 룬: 저체력 시 데미지 증가
	var is_crit := false
	if p.character and p.character.passive_crit_chance > 0.0 and randf() < p.character.passive_crit_chance:
		dmg *= p.character.passive_crit_mult  # 치명타(보유 캐릭터/유물 한정)
		is_crit = true
	var pos: Vector2 = e.global_position
	var was_burning: bool = e.burn_time_left > 0.0   # 격발 판정은 이번 명중 부여 '전' 상태 기준
	var was_slowed: bool = e.slow_time_left > 0.0
	var mult := ElementLib.multiplier(element, e.element)  # 오행 상성
	var d := dmg * mult
	e.take_damage(d)
	if p.lifesteal > 0.0:
		p.heal(d * p.lifesteal)  # 흡혈
	if is_instance_valid(e) and e.hp > 0.0:
		# 원소 반응 — 격발(기존 상태 소모)
		if p.build.frostbite > 0.0 and was_slowed:
			e.take_damage(d * p.build.frostbite)  # 파쇄: 둔화/빙결 적 추가타
		if p.build.detonate_burn > 0.0 and was_burning:
			e.burn_time_left = 0.0  # 화상 소모
			_explode(pos, d * p.build.detonate_burn, element)  # 기폭: 화상 터뜨려 광역
		# 원소 반응 — 부여
		if p.build.apply_burn:
			e.apply_burn(RelicLib.RELIC_BURN_DPS, RelicLib.RELIC_BURN_DUR)
		if p.build.apply_slow:
			e.apply_slow(0.6, 2.0)
		if p.relics.has("ignite"):
			e.apply_burn(RelicLib.RELIC_BURN_DPS, RelicLib.RELIC_BURN_DUR)  # 점화의 룬
		var ex_thr: float = p.build.execute_threshold
		if p.relics.has("execute"):
			ex_thr = maxf(ex_thr, RelicLib.EXECUTE_THRESHOLD)
		if ex_thr > 0.0 and e.hp <= e.max_hp * ex_thr:
			e.take_damage(e.hp)  # 즉사(수확의 룬 + 수확자 카드)
		if p.build.knockback > 0.0 and is_instance_valid(e) and e.hp > 0.0:
			e.position.y -= p.build.knockback  # 넉백: 기지에서 밀어냄
	# 행동: 처치 폭발 — 이 명중으로 적이 죽으면 주변에 광역(직접 피해라 연쇄 폭주 없음)
	if p.build.explode_power > 0.0 and is_instance_valid(e) and e.hp <= 0.0:
		_explode(pos, d * p.build.explode_power, element)
	var dn = DAMAGE_NUMBER.new()
	dn.position = pos
	$Fx.add_child(dn)
	dn.setup(d, is_crit, false, mult > 1.0)

## 처치 폭발: 중심 주변 적에게 직접 피해(+연출). _skill_hit를 안 거쳐 재귀 폭발 방지.
func _explode(center: Vector2, dmg: float, element: String) -> void:
	_skill_burst(center, Color(1.0, 0.6, 0.2))
	_skill_ring(center, 72.0, Color(1.0, 0.55, 0.15))
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and center.distance_to(e.global_position) <= 72.0:
			e.take_damage(dmg * ElementLib.multiplier(element, e.element))

## 반경 내 적에게 스킬 피해(+선택적 화상) — 캐릭터 속성 상성 적용
func _skill_aoe(center: Vector2, radius: float, dmg: float, burn: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and center.distance_to(e.global_position) <= radius:
			_skill_hit(e, dmg, $Player.character.element)
			if burn:
				e.apply_burn(RelicLib.RELIC_BURN_DPS, RelicLib.RELIC_BURN_DUR)

func _skill_burst(pos: Vector2, color: Color) -> void:
	var b = DEATH_BURST_SCENE.instantiate()
	b.position = pos
	b.color = color
	b.amount = 64        # 파편 ↑ (더 화려)
	b.lifetime = 0.9     # 파편이 더 오래 흩날림 (길게)
	$Fx.add_child(b)

## 하늘에서 떨어지는 광역 스킬(메테오·융단): 화면 위에서 낙하 비주얼 → 도달 지점에 폭발+피해.
func _drop_aoe(center: Vector2, radius: float, ep: float, element: String, col: Color, burn: bool) -> void:
	var m = FALLING_SKILL.new()
	m.position = center + Vector2(randf_range(-30.0, 30.0), -720.0)  # 화면 위에서 시작
	m.setup(col, clampf(radius * 0.35, 16.0, 50.0))
	$Fx.add_child(m)
	var t := m.create_tween()
	t.tween_property(m, "position", center, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # 가속 낙하
	t.tween_callback(func() -> void:
		if not game_over:
			_skill_aoe(center, radius, ep, burn)  # 도달 시 폭발 피해
			_skill_ring(center, radius, col)
			_skill_burst(center, col)
			if $Player.build.ground_field:
				_ground_field(center, radius, ep, element)
			_add_shake(4.0)
		m.queue_free())

## 마법사로부터 rng 이내의 살아있는 적 (스킬 사거리 필터)
func _enemies_in_range(rng: float) -> Array:
	var pp: Vector2 = $Player.global_position
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and pp.distance_to(e.global_position) <= rng:
			out.append(e)
	return out

## candidates(사거리 내 적) 중 가장 밀집한 위치. 비면 Vector2.INF.
func _densest_cluster(radius: float, candidates: Array) -> Vector2:
	var enemies := candidates
	if enemies.is_empty():
		return Vector2.INF
	var best: Vector2 = enemies[0].global_position
	var best_n := -1
	for e in enemies:
		var n := 0
		for o in enemies:
			if e.global_position.distance_to(o.global_position) <= radius:
				n += 1
		if n > best_n:
			best_n = n
			best = e.global_position
	return best

func _random_enemy_points(count: int, pool: Array) -> Array:
	var enemies := pool.duplicate()
	enemies.shuffle()
	var pts := []
	for e in enemies.slice(0, count):
		if is_instance_valid(e):
			pts.append(e.global_position)
	return pts

func _skill_chain(count: int, dmg: float, element: String, pool: Array) -> void:
	var enemies := pool
	if enemies.is_empty():
		return
	var pp: Vector2 = $Player.global_position
	enemies.sort_custom(func(a, b): return pp.distance_squared_to(a.global_position) < pp.distance_squared_to(b.global_position))
	var prev := pp
	for e in enemies.slice(0, count):
		if not is_instance_valid(e):
			continue
		_skill_hit(e, dmg, element)
		_draw_arc(prev, e.global_position)
		prev = e.global_position

## 뇌전 연쇄 시각: 두 적 사이에 짧게 번쩍이는 선 (물리 콜백 밖에서 생성 — call_deferred)
func _on_chain(from: Vector2, to: Vector2) -> void:
	_draw_arc.call_deferred(from, to)

func _draw_arc(from: Vector2, to: Vector2) -> void:
	# 글로우(굵고 옅은) + 코어(가늘고 밝은) 2겹으로 더 굵고 천천히 사라지는 번개
	var glow := Line2D.new()
	glow.add_point(from); glow.add_point(to)
	glow.width = 10.0
	glow.default_color = Color(0.6, 0.45, 1.0, 0.5)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	$Fx.add_child(glow)
	var core := Line2D.new()
	core.add_point(from); core.add_point(to)
	core.width = 3.5
	core.default_color = Color(0.96, 0.92, 1.0, 0.98)
	$Fx.add_child(core)
	for ln in [glow, core]:
		var tw = ln.create_tween()  # ln은 Array 요소(Variant)라 := 추론 불가
		tw.tween_property(ln, "modulate:a", 0.0, 0.45)  # 0.18→0.45초 (더 길게 잔광)
		tw.tween_callback(ln.queue_free)
