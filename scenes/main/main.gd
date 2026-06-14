extends Node2D
## 메인 씬: 웨이브 진행(+무한 모드), 적 스폰, 클리어 판정, 카드 보상, 게임오버, 효과음.

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const DEATH_BURST_SCENE := preload("res://scenes/fx/death_burst.tscn")
const DEATH_REMAINS := preload("res://scenes/fx/death_remains.gd")
const DAMAGE_NUMBER := preload("res://scenes/fx/damage_number.gd")
const SKILL_RING := preload("res://scenes/fx/skill_ring.gd")  # 광역 스킬 범위 링 (적 사망 연출 등 공용)
const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
var _skill_rows: Array = []  # 스킬별 쿨타임 게이지 행 {fill, label}
var skill_executor: SkillExecutor  # 전투 연산·FX 실행기 (DI로 player·$Fx·self 주입)
var _wiz_hold := false   # 마법사 롱탭(길게 누름) 진행 중
var _wiz_hold_t := 0.0   # 누른 시간 누적
const ENEMY_BOLT_SCENE := preload("res://scenes/projectile/enemy_bolt.tscn")
const SPAWN_Y := -60.0  # 화면(720x1280) 위쪽 바깥
const SPAWN_X_MIN := 60.0  # 스폰 가로 범위 (가장자리 여백 확보)
const SPAWN_X_MAX := 660.0
const CHOICES_PER_CLEAR := 3
const RARITY_WEIGHT := {"common": 3.0, "uncommon": 1.7, "rare": 1.0, "epic": 0.45, "legendary": 0.22}  # 등장 가중치(고급<희귀<영웅<전설 순 희소)
# 희귀도 색·뱃지 (card_select와 동일 체계) — '내 카드' 리스트 표시용
const RARITY_COLORS := {
	"legendary": Color(1.0, 0.62, 0.32), "epic": Color(0.8, 0.52, 1.0), "rare": Color(1.0, 0.84, 0.4),
	"uncommon": Color(0.56, 0.86, 0.55), "common": Color(0.62, 0.72, 0.88),
}
const RARITY_BADGE := {"legendary": "전설", "epic": "영웅", "rare": "희귀", "uncommon": "고급", "common": "일반"}
const ENDLESS_HP_GROWTH := 0.15  # 무한 모드 단계당 적 체력 증가율
const ENDLESS_DMG_GROWTH := 0.10  # 무한 모드 단계당 적 피해 증가율(체력보다 완만, 흡혈 무한지속 방지)
const ENDLESS_DMG_CAP := 12.0  # 적 피해 배율 상한 — 체력은 무한 증가하되 '한 방 즉사'는 방지(체력안배 가능)
const ELEMENT_ORDER := ["wood", "fire", "earth", "metal", "water"]  # 속성 스테이지 순환 순서(목→화→토→금→수)
const WAVES_PER_STAGE := 10  # (무한모드) 스테이지당 웨이브 수(보스로 끝). 스테이지마다 속성이 바뀜
const STAGE_WAVES := 12  # (스테이지 모드) 클리어까지 웨이브 수 — 마지막 웨이브가 보스
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
var plague_wave: WaveData = preload("res://resources/waves/wave_plague.tres")
var earthlord_wave: WaveData = preload("res://resources/waves/wave_earthlord.tres")
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
# 이번 런에 고른 카드 이력 ('내 카드' 리스트)
var _picked_count: Dictionary = {}   # {카드이름: 획득 횟수}
var _picked_rarity: Dictionary = {}  # {카드이름: rarity}
var _picked_order: Array = []        # 처음 획득한 순서(표시 순서)
var cards_button: Button             # HUD '내 카드' 버튼
var cards_panel: Control             # 획득 카드 패널(스크롤)
var cards_list: VBoxContainer        # 카드 행 컨테이너
var cards_count_label: Label         # "총 N장 · M종"
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
@onready var damage_button: Button = $HUD/PauseScreen/Center/DamageButton

func _ready() -> void:
	var ch: CharacterData = GameState.selected
	$Player.apply_character(ch)
	for id in GameState.relic_levels:  # 모은 유물 전부 적용(런 시작, 레벨=강화)
		$Player.grant_relic(id, GameState.relic_levels[id])
	$SfxShoot.stream = ch.shoot_sound  # 캐릭터 전용 발사음
	$Player.fired.connect(_on_player_fired)
	$Player.hp_changed.connect(_on_player_hp_changed)
	$Player.died.connect(_on_player_died)
	skill_executor = SkillExecutor.new()
	add_child(skill_executor)
	skill_executor.setup($Player, $Fx, self)  # DI: player·FX 루트·host(공유 FX/게임상태)
	$Player.skill_cast.connect(skill_executor.execute)
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
	damage_button.pressed.connect(_on_damage_toggle)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.value = GameState.sfx_volume
	_update_mute_label()
	_update_damage_label()
	_build_cards_ui()  # '내 카드' 버튼 + 획득 카드 리스트 패널
	_on_player_hp_changed($Player.hp, $Player.max_hp)  # HP 초기 표시
	_update_best_label()
	_update_coin_label()
	$HUD/VersionLabel.text = GameState.VERSION  # 빌드 버전 표기(단일 출처)
	# 테스트 편의: 웹 URL에 ?auto=1이면 카드 자동선택 (일반 유저·출시 빌드엔 비노출)
	if OS.has_feature("web"):
		auto_pick = str(JavaScriptBridge.eval("window.location.search")).contains("auto=1")
	# 게임 시작: 시작 웨이브 도약 보정(건너뛴 분 무작위 카드 자동 지급) 후 카드 드래프트
	if GameState.game_mode == "stage":
		wave_index = -1  # 스테이지 모드: Wave 1부터(시작 웨이브 도약 없음)
	else:
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
			_record_card(drawn[0])
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
	coin_label.text = NumFmt.compact(run_coins)  # 앞의 동전 아이콘(CoinIcon)이 '코인'을 표시

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
	if GameState.game_mode == "stage":
		if index >= STAGE_WAVES - 1:
			return "boss"  # 스테이지 마지막 = 그 속성 보스
		if (index + 1) % 4 == 0:
			return "midboss"
		return "normal"
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
## 현재 웨이브 속성 — 스테이지 모드는 고른 속성 고정, 무한모드는 10웨이브마다 순환
func _stage_element(index: int) -> String:
	if GameState.game_mode == "stage":
		return GameState.stage_element
	return ELEMENT_ORDER[(index / WAVES_PER_STAGE) % ELEMENT_ORDER.size()]

## 스테이지 속성에 맞는 보스 웨이브
func _boss_wave_for(index: int) -> WaveData:
	match _stage_element(index):
		"fire": return boss_wave
		"water": return guardian_wave
		"metal": return storm_wave
		"wood": return plague_wave
		_: return earthlord_wave  # earth — 대지 마왕

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
		var elem := _stage_element(index)
		wave_label.text = "Wave %d · %s 스테이지" % [index + 1, ElementLib.display_name(elem)]
		wave_label.modulate = ElementLib.color(elem)  # 스테이지 속성 색
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
	if kind == "normal":
		return _stage_spawn_list(index)  # 일반 웨이브 = 스테이지 속성 잡몹(자체 증원)
	var base: Array
	if kind == "boss":
		base = _boss_wave_for(index).build_spawn_list()
	elif kind == "midboss":
		base = midboss_wave.build_spawn_list()
	else:  # bonus
		base = bonus_wave.build_spawn_list()  # 무한 단계만큼 보물도 증원 → 후반일수록 코인 多
	var extra := int(base.size() * 0.25 * _endless_level(index))
	for i in extra:
		base.append(base[randi() % base.size()])  # 기존 구성 비율대로 증원
	base.shuffle()
	return base

## 일반 웨이브: 그 스테이지 속성의 잡몹들로 구성(스테이지 진행·무한 단계로 수 증가)
func _stage_spawn_list(index: int) -> Array:
	var elem := _stage_element(index)
	var pool := GameState.enemies.filter(func(e): return e.element == elem and not e.show_hp_bar)
	if pool.is_empty():
		pool = [GameState.enemies[0]]
	var within := index % WAVES_PER_STAGE          # 스테이지 내 웨이브(0~9)
	var total := 6 + within + _endless_level(index) * 2
	var list: Array = []
	for i in total:
		list.append(pool[i % pool.size()])
	list.shuffle()
	return list

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
	enemy.status.reaction.connect(skill_executor.on_reaction.bind(enemy))  # 원소 반응(과부하 등) 구독(Observer)
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
		GameFeel.hit_stop(0.07, clampf(size / 90.0, 0.4, 1.0))  # 큰 적·보스 처치 역경직(클수록 강하게)
	var gain := coins  # 처치 코인 (엘리트 보너스 포함, 도달한 적은 _unregister만)
	if $Player.relic_levels.has("greed"):
		gain = int(round(gain * RelicLib.greed_mult($Player.relic_levels["greed"])))  # 황금의 룬(레벨별)
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
	if $Player.relic_levels.has("greed"):
		bonus = int(round(bonus * RelicLib.greed_mult($Player.relic_levels["greed"])))
	run_coins += bonus
	_update_coin_label()
	# 스테이지 모드: 마지막(보스) 웨이브를 깨면 클리어(다음 웨이브 없음)
	if GameState.game_mode == "stage" and wave_index >= STAGE_WAVES - 1:
		_stage_cleared()
		return
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

## 해당 스킬을 이미 보유했나 (스킬 슬롯 필터용)
func _has_skill(id: String) -> bool:
	for s in $Player.skills:
		if s.id == id:
			return true
	return false

## 화상 부여원(부여 카드·점화 유물·메테오 스킬)이 있나 — 기폭 카드 유효성
func _has_burn_source() -> bool:
	if $Player.build.apply_burn or $Player.relic_levels.has("ignite"):
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
	if card.grant_skill_id != "" and not _has_skill(card.grant_skill_id) and $Player.skills.size() >= $Player.MAX_SKILL_SLOTS:
		return false  # 스킬 슬롯이 꽉 차면 미보유 스킬 카드는 제외(보유 스킬 진화 카드만 노출)
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
	# 1회성 '순수 부여' 카드 — 새로 켤 불리언 플래그가 하나도 없으면 제외(중복=낭비).
	# 부여+수치 혼합 카드(예: 공명=부여+기폭/파쇄)는 수치가 누적되므로 제외하지 않는다.
	if _is_pure_grant(card) and not _grants_new_flag(card):
		return false
	return true

## 효과가 불리언 부여뿐인 1회성 카드인지(다른 수치/스킬/회복이 전혀 없음)
func _is_pure_grant(card: CardData) -> bool:
	if not (card.grant_burn or card.grant_slow or card.grant_echo or card.grant_ground_field):
		return false
	if card.damage_bonus != 0.0 or card.fire_rate_bonus != 0.0 or card.projectile_count_bonus != 0: return false
	if card.damage_per_target_bonus != 0.0 or card.max_hp_bonus != 0.0 or card.defense_bonus != 0.0: return false
	if card.skill_power_bonus != 0.0 or card.skill_radius_bonus != 0.0 or card.grant_skill_id != "": return false
	if card.explode_power_bonus != 0.0 or card.extra_targets_bonus != 0 or card.detonate_burn_bonus != 0.0: return false
	if card.frostbite_bonus != 0.0 or card.knockback_bonus != 0.0 or card.execute_threshold_bonus != 0.0: return false
	if card.pierce_bonus != 0 or card.heal != 0.0: return false
	return true

## 이 부여 카드가 아직 안 켜진 플래그를 새로 켜는지(하나라도 새로 켜면 유효)
func _grants_new_flag(card: CardData) -> bool:
	var b = $Player.build
	if card.grant_burn and not b.apply_burn: return true
	if card.grant_slow and not b.apply_slow: return true
	if card.grant_echo and not b.echo: return true
	if card.grant_ground_field and not b.ground_field: return true
	return false

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
		_record_card(card)
		_shop_active = false
		_start_wave(wave_index + 1)
		return
	$SfxCardPick.play()
	$Player.apply_card(card)
	_record_card(card)
	# 시작 드래프트(웨이브 시작 전)가 남아 있으면 다음 드래프트, 아니면 다음 웨이브
	if start_drafts_left > 0:
		start_drafts_left -= 1
		if start_drafts_left > 0:
			_open_draft()
			return
	_start_wave(wave_index + 1)

func _on_player_hp_changed(hp: float, max_hp: float) -> void:
	hp_label.text = "%s / %s" % [NumFmt.compact(int(hp)), NumFmt.compact(int(max_hp))]  # 앞의 방패 아이콘(HpIcon)이 '기지 내구도'를 표시

## 스테이지 모드 클리어 — 마지막(보스) 웨이브 격파. 승리 화면(코인·숙련 정산).
func _stage_cleared() -> void:
	game_over = true
	print("STAGE CLEAR")
	pause_button.hide()
	wave_label.text = "%s 스테이지 클리어!" % ElementLib.display_name(GameState.stage_element)
	wave_label.modulate = ElementLib.color(GameState.stage_element)
	GameState.add_coins(run_coins)
	GameState.add_xp(GameState.selected, wave_index + 1)
	GameState.note_run(GameState.selected, wave_index + 1)
	coin_label.text = "+%s 클리어 보상" % NumFmt.compact(run_coins)
	_update_best_label()
	get_tree().paused = true
	restart_button.show()
	char_select_button.show()

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
	coin_label.text = "+%s · 숙련 +%d" % [NumFmt.compact(run_coins), wave_index + 1]  # 앞의 동전 아이콘이 '코인'
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
	$HUD/StatsPanel/Center/StatsLabel.text = "기지 내구도 %s / %s\n\n%s" % [NumFmt.compact(int(p.hp)), NumFmt.compact(int(p.max_hp)), _build_summary()]
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
	if not p.relic_levels.is_empty():
		var names := []
		for id in p.relic_levels:
			names.append("%s Lv%d" % [_relic_name(id), p.relic_levels[id]])
		lines.append("유물: " + ", ".join(names))
	return "\n".join(lines)

func _relic_name(id: String) -> String:
	for r in RelicLib.RELICS:
		if r.id == id:
			return r.name
	return id

## 카드 획득 1건 기록 (이번 런 '내 카드' 리스트용)
func _record_card(card) -> void:
	var nm: String = card.card_name
	if not _picked_count.has(nm):
		_picked_order.append(nm)
		_picked_rarity[nm] = card.rarity
	_picked_count[nm] = int(_picked_count.get(nm, 0)) + 1

## '내 카드' 버튼 + 스크롤 패널을 코드로 구성 (HUD에 추가)
func _build_cards_ui() -> void:
	cards_button = Button.new()
	cards_button.text = "내 카드"
	cards_button.add_theme_font_override("font", FONT)
	cards_button.add_theme_font_size_override("font_size", 22)
	cards_button.anchor_left = 1.0
	cards_button.anchor_right = 1.0
	cards_button.grow_horizontal = 0
	cards_button.offset_left = -126.0
	cards_button.offset_top = 120.0
	cards_button.offset_right = -16.0
	cards_button.offset_bottom = 164.0
	$HUD.add_child(cards_button)
	cards_button.pressed.connect(_open_cards)

	cards_panel = Control.new()
	cards_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # 정지 중에도 동작
	cards_panel.visible = false
	cards_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(cards_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_cards_dim_input)
	cards_panel.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -290.0
	panel.offset_right = 290.0
	panel.offset_top = -430.0
	panel.offset_bottom = 430.0
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.12, 0.11, 0.16, 0.98)
	pstyle.set_corner_radius_all(14)
	pstyle.set_content_margin_all(20)
	pstyle.set_border_width_all(2)
	pstyle.border_color = Color(0.4, 0.4, 0.5)
	panel.add_theme_stylebox_override("panel", pstyle)
	cards_panel.add_child(panel)

	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 12)
	panel.add_child(center)
	var title := Label.new()
	title.text = "획득 카드"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 36)
	center.add_child(title)
	cards_count_label = Label.new()
	cards_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_count_label.add_theme_font_override("font", FONT)
	cards_count_label.add_theme_font_size_override("font_size", 18)
	cards_count_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	center.add_child(cards_count_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(520, 600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(scroll)
	cards_list = VBoxContainer.new()
	cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_list.add_theme_constant_override("separation", 6)
	scroll.add_child(cards_list)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(220, 54)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(_close_cards)
	center.add_child(close)

## 획득 카드 패널 열기 (현재까지 고른 카드 리스트 갱신 후 표시·일시정지)
func _open_cards() -> void:
	if card_select.visible:  # 카드 선택(드래프트) 중에는 막음
		return
	for ch in cards_list.get_children():
		ch.queue_free()
	var total := 0
	for nm in _picked_order:
		var cnt: int = _picked_count[nm]
		total += cnt
		cards_list.add_child(_card_row(nm, cnt, _picked_rarity.get(nm, "common")))
	if _picked_order.is_empty():
		var empty := Label.new()
		empty.text = "아직 획득한 카드가 없습니다"
		empty.add_theme_font_override("font", FONT)
		empty.add_theme_font_size_override("font_size", 20)
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		cards_list.add_child(empty)
	cards_count_label.text = "총 %d장 · %d종" % [total, _picked_order.size()]
	cards_panel.show()
	get_tree().paused = true

## 카드 한 줄: [희귀도 뱃지] 이름 ··· ×횟수 (희귀도 색)
func _card_row(nm: String, cnt: int, rar: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(500, 0)
	row.add_theme_constant_override("separation", 10)
	var col: Color = RARITY_COLORS.get(rar, Color.WHITE)
	var badge := Label.new()
	badge.text = RARITY_BADGE.get(rar, "일반")
	badge.add_theme_font_override("font", FONT)
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", col)
	badge.custom_minimum_size = Vector2(52, 0)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(badge)
	var name_lbl := Label.new()
	name_lbl.text = nm
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	if cnt > 1:
		var cnt_lbl := Label.new()
		cnt_lbl.text = "×%d" % cnt
		cnt_lbl.add_theme_font_override("font", FONT)
		cnt_lbl.add_theme_font_size_override("font_size", 22)
		cnt_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		row.add_child(cnt_lbl)
	return row

func _close_cards() -> void:
	cards_panel.hide()
	if not game_over:  # 게임오버 중엔 멈춤 유지(사망 후 빌드 회고 가능)
		get_tree().paused = false

func _on_cards_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_close_cards()

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

func _on_damage_toggle() -> void:
	GameState.set_show_damage_numbers(not GameState.show_damage_numbers)
	_update_damage_label()

func _update_damage_label() -> void:
	damage_button.text = "데미지 숫자: 켜짐" if GameState.show_damage_numbers else "데미지 숫자: 꺼짐"

func _on_player_fired(projectile) -> void:
	$SfxShoot.play()
	if projectile.chain_count > 0:
		projectile.chained.connect(skill_executor._on_chain)
	projectile.damaged.connect(_on_projectile_damaged)
	$Projectiles.add_child(projectile)

## 플로팅 데미지 숫자 생성 (설정에서 끄면 표시 안 함). 비물리 FX라 충돌 콜백 중 즉시 추가 안전.
func _damage_number(pos: Vector2, amount: float, is_crit := false, player := false, strong := false) -> void:
	if not GameState.show_damage_numbers:
		return
	var dn = DAMAGE_NUMBER.new()
	dn.position = pos
	$Fx.add_child(dn)
	dn.setup(amount, is_crit, player, strong)

## 직격 피해 위치에 플로팅 데미지 숫자
func _on_projectile_damaged(amount: float, is_crit: bool, pos: Vector2, is_strong := false) -> void:
	_damage_number(pos, amount, is_crit, false, is_strong)

## 플레이어가 받는 피해 — 머리 위에 빨간 숫자
func _on_player_took_damage(amount: float) -> void:
	_damage_number($Player.global_position + Vector2(0, -40), amount, false, true)

## 광역 스킬 범위 링 FX
func _skill_ring(pos: Vector2, radius: float, color: Color) -> void:
	var r = SKILL_RING.new()
	r.position = pos
	$Fx.add_child(r)
	r.setup(radius, color)
