extends Node
## 전역 메타 진행 상태(오토로드): 최고 웨이브 기록 + 캐릭터 로스터/선택.
## 씬을 새로 로드해도 유지되며, 최고 기록은 user://에 영속 저장된다.

const SAVE_PATH := "user://save.cfg"
const VERSION := "v0.44"  ## 빌드 버전 (메인·시작 화면 공용 표기) — 빌드마다 이 값만 올릴 것

# 패치노트 (최신이 위). 새 버전 추가 시 맨 앞에 한 항목 추가. 시작 화면 "패치노트" + 업데이트 시 자동 안내.
const CHANGELOG := [
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
	{"id": "pierce", "name": "시작 관통", "per": 1.0, "max": 20, "base": 14, "suffix": " 관통"},
	{"id": "lifesteal", "name": "흡혈", "per": 0.03, "max": 12, "base": 24, "suffix": "% 흡혈"},
	{"id": "extra_card", "name": "추가 시작 카드", "per": 1.0, "max": 3, "base": 60, "suffix": "장(웨이브 전)"},
]

# 캐릭터 숙련도(경험치): 플레이만 해도 경험치가 쌓여 레벨업 → 레벨당 공격력·체력 패시브 증가.
# 경험치 획득 = 그 런의 도달 웨이브. 레벨 L→L+1 필요치 = XP_BASE + XP_STEP*L.
const XP_BASE := 50
const XP_STEP := 25
const MASTERY_PER_LEVEL := 0.02  ## 숙련 레벨당 공격력·체력 +2%

# 컬렉션 로스터 (unlock_wave 오름차순)
var characters: Array = [
	preload("res://resources/characters/char_apprentice.tres"),
	preload("res://resources/characters/char_pyromancer.tres"),
	preload("res://resources/characters/char_archer.tres"),
	preload("res://resources/characters/char_frost.tres"),
	preload("res://resources/characters/char_arc.tres"),
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
var seen_version := ""  ## 마지막으로 패치노트를 본 버전 — 다르면 시작 시 자동 안내

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
