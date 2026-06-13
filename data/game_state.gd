extends Node
## 전역 메타 진행 상태(오토로드): 최고 웨이브 기록 + 캐릭터 로스터/선택.
## 씬을 새로 로드해도 유지되며, 최고 기록은 user://에 영속 저장된다.

const SAVE_PATH := "user://save.cfg"
const VERSION := "v0.60"  ## 빌드 버전 (메인·시작 화면 공용 표기) — 빌드마다 이 값만 올릴 것

# 패치노트 (최신이 위). 새 버전 추가 시 맨 앞에 한 항목 추가. 시작 화면 "패치노트" + 업데이트 시 자동 안내.
const CHANGELOG := [
	{"v": "v0.60", "notes": ["평타 폐지 → 스킬 캐스터 전환 — 자동 발사를 없애고 캐릭터마다 쿨타임 스킬로만 공격(견습은 '마력탄')", "모든 스킬에 데미지 숫자 표시 · 멀티샷·표적당 카드 정리(공격력·스킬 위력·쿨타임 중심 빌드로)"]},
	{"v": "v0.59", "notes": ["받는 피해 표시 — 피격 시 빨간 데미지 숫자 + 무한 모드 '적 피해 ×N' 표기로 위협 가늠"]},
	{"v": "v0.58", "notes": ["스킬 강화 카드 — 마력 집중(위력 +35%)·광역 확장(범위 +40%)로 스킬 빌드 강화"]},
	{"v": "v0.57", "notes": ["액티브 스킬 — 캐릭터마다 쿨타임 자동 발동 스킬(치유/메테오/융단폭격/체인/절대영도)", "연사 스탯은 평타 대신 스킬 쿨타임 감소로 (평타는 고정 속도)"]},
	{"v": "v0.56", "notes": ["미사용 유물 드래프트 UI 제거 — v0.45 개편 이후 쓰이지 않던 보스 보상 화면 정리"]},
	{"v": "v0.55", "notes": ["발사체 크기 카드 제거 — 효과 미미 피드백 반영(스탯·표기 정리)"]},
	{"v": "v0.54", "notes": ["관통·발사체 속도 스탯 제거(단순화) — 발사체는 1타, 관통/속도 카드·강화 정리", "서리 마도사 동시표적 +1 보강"]},
	{"v": "v0.53", "notes": ["오행 속성 상성 — 마법사 5속성(목화토금수), 적과 상극이면 데미지 ×1.5/×0.7", "캐릭터를 5명으로 정리(폭풍 궁사 → 뇌전·견습 등 5속성 체계로)"]},
	{"v": "v0.52", "notes": ["새 카드 4종 — 글래스 캐논·속사포(트레이드오프), 철벽·정밀 사격"]},
	{"v": "v0.51", "notes": ["보스 등장 배너 — 보스 웨이브 시작 시 보스 이름이 크게 표시"]},
	{"v": "v0.50", "notes": ["새 보스 폭풍 마왕 — 광역 탄막 집중형. 보스가 마왕·수호 마왕·폭풍 마왕 3종 순환"]},
	{"v": "v0.49", "notes": ["기록 표시 — 캐릭터 카드에 최고 웨이브·숙련 Lv, 상단에 누적 플레이·코인"]},
	{"v": "v0.48", "notes": ["새 캐릭터 포격술사 — 느린 강타 + 광역 폭발(splash). Wave 20 도달 시 해금"]},
	{"v": "v0.47", "notes": ["유물 슬롯 강화 — 코인으로 장착 슬롯을 최대 4칸까지 확장"]},
	{"v": "v0.46", "notes": ["PWA 자동 업데이트 — 새 버전 배포 시 앱을 다시 열면 자동 반영"]},
	{"v": "v0.45", "notes": ["유물 개편 — 코인으로 영구 해금 후 런마다 장착(시작 화면 '유물')", "보스는 유물 드래프트 대신 희귀 카드 확정"]},
	{"v": "v0.44", "notes": ["패치노트 화면 추가 — 업데이트 시 변경 내용을 안내"]},
	{"v": "v0.43", "notes": ["일시정지 화면에 현재 빌드 요약(실효 스탯·유물) 표시"]},
	{"v": "v0.42", "notes": ["웨이브 클리어 시 남은 적 탄막을 즉시 제거"]},
	{"v": "v0.41", "notes": ["적 명중 시 데미지 숫자 표시 (치명타는 금색·확대)"]},
	{"v": "v0.40", "notes": ["보물 처치 전용 코인 사운드", "게임오버에 획득 숙련 경험치·레벨업 표시"]},
	{"v": "v0.39", "notes": ["캐릭터별 강화 + 숙련도(경험치) 시스템", "기존 글로벌 강화는 코인으로 환불"]},
	{"v": "v0.38", "notes": ["보너스 코인 스테이지 (끝자리 8 웨이브, 무해한 황금 보물)"]},
	{"v": "v0.37", "notes": ["멀티샷 개편 — 표적보다 발사 수가 많으면 집중사격"]},
]

# 영구 강화 정의 (id / 이름 / 레벨당 효과 per / 최대 레벨(-1=무한) / 기본 비용 base / 표시 접미사).
# 다음 레벨 비용 = base × UPGRADE_GROWTH^현재레벨 (초반 저렴·후반 가파름).
# 공격력·체력은 무한(max=-1) — 적 체력은 기하급수로 커지므로 고정값 강화는 결국 뒤처져 자가 밸런싱됨.
const UPGRADE_GROWTH := 1.5
const UPGRADES := [
	{"id": "damage", "name": "시작 공격력", "per": 2.0, "max": -1, "base": 6, "suffix": " 공격력"},
	{"id": "max_hp", "name": "시작 체력", "per": 20.0, "max": -1, "base": 6, "suffix": " 체력"},
	{"id": "fire_rate", "name": "시작 연사", "per": 0.2, "max": 20, "base": 10, "suffix": "/s 연사"},
	{"id": "lifesteal", "name": "흡혈", "per": 0.03, "max": 12, "base": 24, "suffix": "% 흡혈"},
	{"id": "extra_card", "name": "추가 시작 카드", "per": 1.0, "max": 3, "base": 60, "suffix": "장(웨이브 전)"},
]

# 캐릭터 숙련도(경험치): 플레이만 해도 경험치가 쌓여 레벨업 → 레벨당 공격력·체력 패시브 증가.
# 경험치 획득 = 그 런의 도달 웨이브. 레벨 L→L+1 필요치 = XP_BASE + XP_STEP*L.
const XP_BASE := 50
const XP_STEP := 25
const MASTERY_PER_LEVEL := 0.02  ## 숙련 레벨당 공격력·체력 +2%
const RELIC_SLOTS := 2  ## 기본 유물 장착 슬롯 수
const RELIC_SLOTS_MAX := 4  ## 슬롯 강화 상한

# 컬렉션 로스터 (unlock_wave 오름차순)
var characters: Array = [
	preload("res://resources/characters/char_apprentice.tres"),
	preload("res://resources/characters/char_pyromancer.tres"),
	preload("res://resources/characters/char_frost.tres"),
	preload("res://resources/characters/char_arc.tres"),
	preload("res://resources/characters/char_bomb.tres"),
]
var selected: CharacterData
var start_wave := 1  ## 이번 게임 시작 웨이브 (시작 화면에서 선택, 인메모리 — best_wave 이하)
var best_wave := 0
var game_speed := 1.0  ## 배속 설정(1/2/3x) — 씬 리로드·재시작에도 유지, user://에 영속
var sfx_volume := 1.0  ## 효과음 음량(0~1) — 영속
var muted := false  ## 음소거 — 영속
var coins := 0  ## 영구 재화 (런 종료 시 누적, 캐릭터 공용 지갑)
var upgrades := {}  ## 영구 강화 레벨 — 캐릭터별 {char_key: {id: level}}
var char_xp := {}  ## 캐릭터별 누적 경험치 {char_key: xp} → 숙련도 레벨(자동 패시브)
var char_best := {}  ## 캐릭터별 최고 도달 웨이브 {char_key: wave} (기록 표시용)
var total_runs := 0  ## 누적 플레이 횟수(통계)
var lifetime_coins := 0  ## 누적 획득 코인(통계)
var seen_version := ""  ## 마지막으로 패치노트를 본 버전 — 다르면 시작 시 자동 안내
var unlocked_relics: Array = []  ## 코인으로 영구 해금한 유물 id
var equipped_relics: Array = []  ## 이번 런에 장착할 유물 id (해금분 중 최대 relic_slots개)
var relic_slot_bonus := 0  ## 코인으로 늘린 추가 유물 슬롯 (relic_slots = RELIC_SLOTS + 이것)

func _ready() -> void:
	_load()
	apply_audio()  # 저장된 음량·음소거를 마스터 버스에 적용(게임 전체)
	if selected == null:
		selected = characters[0]

## 마스터 버스에 음량·음소거 적용
func apply_audio() -> void:
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(sfx_volume, 0.0001, 1.0)))

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	_save()

func set_muted(b: bool) -> void:
	muted = b
	apply_audio()
	_save()

func is_unlocked(c: CharacterData) -> bool:
	return best_wave >= c.unlock_wave

## 도달 웨이브 기록 (갱신 시에만 저장). 새로 해금된 게 있으면 true 반환.
func record_wave(reached: int) -> bool:
	if reached <= best_wave:
		return false
	var before := best_wave
	best_wave = reached
	_save()
	# 이번 기록으로 새로 열린 캐릭터가 있는지
	for c in characters:
		if c.unlock_wave > before and c.unlock_wave <= best_wave:
			return true
	return false

## 런 종료 1회 호출: 플레이 수 + 캐릭터별 최고 웨이브 집계(영속)
func note_run(c: CharacterData, reached: int) -> void:
	total_runs += 1
	var key := char_key(c)
	if reached > int(char_best.get(key, 0)):
		char_best[key] = reached
	_save()

func char_best_wave(c: CharacterData) -> int:
	return int(char_best.get(char_key(c), 0))

## 배속 설정 변경 + 영속 저장
func set_game_speed(s: float) -> void:
	game_speed = s
	_save()

## --- 영구 강화 (캐릭터별 / 코인은 공용) ---
## 캐릭터 식별 키 = .tres 파일명(확장자 제외). 예: char_apprentice
func char_key(c: CharacterData) -> String:
	return c.resource_path.get_file().get_basename() if c else ""

func upgrade_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

func upgrade_level(id: String, c: CharacterData = selected) -> int:
	return upgrades.get(char_key(c), {}).get(id, 0)

## 현재 레벨의 누적 보너스 값 (레벨 × 레벨당 효과)
func upgrade_value(id: String, c: CharacterData = selected) -> float:
	return upgrade_level(id, c) * upgrade_def(id).get("per", 0.0)

## 다음 레벨 비용 (상한 있는 항목이 만렙이면 -1). 비용 = base × growth^현재레벨.
func next_cost(id: String, c: CharacterData = selected) -> int:
	var def := upgrade_def(id)
	var mx := int(def.get("max", 0))
	var lv := upgrade_level(id, c)
	if mx >= 0 and lv >= mx:
		return -1  # 상한 도달
	return int(round(def.get("base", 10) * pow(UPGRADE_GROWTH, lv)))

func can_buy(id: String, c: CharacterData = selected) -> bool:
	var cost := next_cost(id, c)
	return cost >= 0 and coins >= cost

## 구매 성공 시 코인(공용) 차감·해당 캐릭터 레벨↑·저장하고 true 반환
func buy_upgrade(id: String, c: CharacterData = selected) -> bool:
	if not can_buy(id, c):
		return false
	coins -= next_cost(id, c)
	var key := char_key(c)
	if not upgrades.has(key):
		upgrades[key] = {}
	upgrades[key][id] = upgrade_level(id, c) + 1
	_save()
	return true

## --- 캐릭터 숙련도(경험치) ---
## 누적 경험치 → [레벨, 레벨 내 경험치, 다음 레벨 필요치]
func _xp_state(c: CharacterData) -> Array:
	var xp: int = char_xp.get(char_key(c), 0)
	var lvl := 0
	while xp >= XP_BASE + XP_STEP * lvl:
		xp -= XP_BASE + XP_STEP * lvl
		lvl += 1
	return [lvl, xp, XP_BASE + XP_STEP * lvl]

func char_level(c: CharacterData = selected) -> int:
	return _xp_state(c)[0]

## 숙련 레벨당 공격력·체력 배율
func mastery_mult(c: CharacterData = selected) -> float:
	return 1.0 + MASTERY_PER_LEVEL * char_level(c)

## 런 종료 시 경험치 적립(= 도달 웨이브) + 저장
func add_xp(c: CharacterData, amount: int) -> void:
	if amount <= 0 or c == null:
		return
	var key := char_key(c)
	char_xp[key] = int(char_xp.get(key, 0)) + amount
	_save()

## 런 종료 시 획득 코인 적립 + 저장
func add_coins(n: int) -> void:
	if n <= 0:
		return
	coins += n
	lifetime_coins += n
	_save()

## --- 유물 (코인 영구 해금 + 런 장착) ---
func relic_slots() -> int:
	return RELIC_SLOTS + relic_slot_bonus

## 다음 유물 슬롯 비용 (상한 도달 시 -1). 비용 = 300 × 2^현재추가슬롯.
func relic_slot_cost() -> int:
	if relic_slots() >= RELIC_SLOTS_MAX:
		return -1
	return int(300 * pow(2, relic_slot_bonus))

func can_buy_relic_slot() -> bool:
	var c := relic_slot_cost()
	return c >= 0 and coins >= c

## 슬롯 +1 (코인 공용 차감·영속). 성공 시 true.
func buy_relic_slot() -> bool:
	if not can_buy_relic_slot():
		return false
	coins -= relic_slot_cost()
	relic_slot_bonus += 1
	_save()
	return true

func relic_cost(id: String) -> int:
	return int(RelicLib.relic_def(id).get("cost", 100))

func is_relic_unlocked(id: String) -> bool:
	return unlocked_relics.has(id)

func can_unlock_relic(id: String) -> bool:
	return not is_relic_unlocked(id) and coins >= relic_cost(id)

## 해금 성공 시 코인 차감·영속 저장하고 true
func unlock_relic(id: String) -> bool:
	if not can_unlock_relic(id):
		return false
	coins -= relic_cost(id)
	unlocked_relics.append(id)
	_save()
	return true

func is_relic_equipped(id: String) -> bool:
	return equipped_relics.has(id)

## 장착/해제 토글 (해금된 것만, 슬롯 한도 내). 변경 시 저장.
func toggle_relic(id: String) -> void:
	if is_relic_equipped(id):
		equipped_relics.erase(id)
	elif is_relic_unlocked(id) and equipped_relics.size() < relic_slots():
		equipped_relics.append(id)
	else:
		return
	_save()

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best_wave = cf.get_value("record", "best_wave", 0)
		game_speed = cf.get_value("settings", "game_speed", 1.0)
		sfx_volume = cf.get_value("settings", "sfx_volume", 1.0)
		muted = cf.get_value("settings", "muted", false)
		coins = cf.get_value("meta", "coins", 0)
		upgrades = cf.get_value("meta", "upgrades", {})
		char_xp = cf.get_value("meta", "char_xp", {})
		seen_version = cf.get_value("meta", "seen_version", "")
		unlocked_relics = cf.get_value("meta", "unlocked_relics", [])
		equipped_relics = cf.get_value("meta", "equipped_relics", [])
		relic_slot_bonus = cf.get_value("meta", "relic_slot_bonus", 0)
		char_best = cf.get_value("record", "char_best", {})
		total_runs = cf.get_value("record", "total_runs", 0)
		lifetime_coins = cf.get_value("record", "lifetime_coins", 0)
		_migrate_upgrades()  # 구형(글로벌) 강화 → 코인 환불 후 캐릭터별로 전환

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("record", "best_wave", best_wave)
	cf.set_value("settings", "game_speed", game_speed)
	cf.set_value("settings", "sfx_volume", sfx_volume)
	cf.set_value("settings", "muted", muted)
	cf.set_value("meta", "coins", coins)
	cf.set_value("meta", "upgrades", upgrades)
	cf.set_value("meta", "char_xp", char_xp)
	cf.set_value("meta", "seen_version", seen_version)
	cf.set_value("meta", "unlocked_relics", unlocked_relics)
	cf.set_value("meta", "equipped_relics", equipped_relics)
	cf.set_value("meta", "relic_slot_bonus", relic_slot_bonus)
	cf.set_value("record", "char_best", char_best)
	cf.set_value("record", "total_runs", total_runs)
	cf.set_value("record", "lifetime_coins", lifetime_coins)
	cf.save(SAVE_PATH)

## 현재 버전의 패치노트를 본 것으로 기록(자동 안내 1회용)
func mark_version_seen() -> void:
	if seen_version != VERSION:
		seen_version = VERSION
		_save()

## 구형 세이브(글로벌 {id:level}) → 캐릭터별 구조 전환.
## 기존 강화에 쓴 코인을 전부 환불하고 강화를 초기화(코인 환불 마이그레이션).
func _migrate_upgrades() -> void:
	if upgrades.is_empty():
		return
	if upgrades.values()[0] is Dictionary:
		return  # 이미 캐릭터별(신형)
	var refund := 0
	for id in upgrades.keys():
		var lv: int = upgrades[id]
		var base: int = int(upgrade_def(id).get("base", 10))
		for k in range(lv):
			refund += int(round(base * pow(UPGRADE_GROWTH, k)))
	coins += refund
	upgrades = {}
	_save()
	print("[migrate] 구형 강화 → 코인 %d 환불, 캐릭터별로 전환" % refund)
