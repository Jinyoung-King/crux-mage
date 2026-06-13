extends Node
## 전역 메타 진행 상태(오토로드): 최고 웨이브 기록 + 캐릭터 로스터/선택.
## 씬을 새로 로드해도 유지되며, 최고 기록은 user://에 영속 저장된다.

const SAVE_PATH := "user://save.cfg"
const VERSION := "v0.89"  ## 빌드 버전 (메인·시작 화면 공용 표기) — 빌드마다 이 값만 올릴 것

# 패치노트 (최신이 위). 새 버전 추가 시 맨 앞에 한 항목 추가. 시작 화면 "패치노트" + 업데이트 시 자동 안내.
const CHANGELOG := [
	{"v": "v0.89", "notes": ["스킬 이펙트 강화 — 광역 범위 링이 이중 링+글로우로 회전하며 더 오래 남고(0.35→0.7초), 번개는 굵은 2겹으로, 스킬 이름은 팝 등장 후 길게, 잔류 장판도 더 오래 유지. 시전 연출이 전반적으로 화려하고 길어짐", "홈 화면 개선 — 단색 배경을 게임과 같은 보랏빛 그라데이션+흐르는 별 배경으로 통일, 타이틀 글로우, 선택한 캐릭터 카드를 확대 강조"]},
	{"v": "v0.88", "notes": ["스킬 쿨타임 밸런스 — 기본 쿨타임을 전반 상향하고 스킬 성격별로 차등. 약한 마력탄은 짧게(고유 3.5초), 강력한 메테오·융단폭격과 전체 둔화 절대영도는 길게(6~7초). 강한 한 방엔 더 긴 텀, 약한 스킬은 자주 — 스킬 선택·조합의 무게가 생김(연사·진화로 단축은 유지)"]},
	{"v": "v0.87", "notes": ["적 속성 표시 — 적마다 오행 속성(목·화·토·금·수) 색 테두리가 보인다. 마법사 속성과 상극이면 데미지 ×1.5(상성 강타는 주황·확대 숫자), 역상성이면 ×0.7. 적 속성을 보고 캐릭터·스킬을 고르는 전략", "시작 웨이브 다이얼 — 시작 화면에서 1~최고기록을 슬라이더로 1단위 정밀 선택(기존 5단위 버튼 대체). 시작 웨이브를 높이면 그만큼 무작위 카드를 자동 지급하고 진입 시 '시작 빌드' 요약을 보여줌"]},
	{"v": "v0.86", "notes": ["관통 (행동 카드) — '관통'을 얻으면 마력탄이 적을 꿰뚫고 계속 날아가 일직선의 적을 연달아 타격한다. 적이 한 줄로 몰려올수록 강력(마력탄 스킬 보유 시 등장)"]},
	{"v": "v0.85", "notes": ["웨이브 상점 — 끝자리 6 웨이브를 깨면 상점 등장. 런 코인으로 카드를 사거나 건너뛸 수 있다(못 사는 카드는 비활성). 코인 사용처 + '지금 살까/모아둘까' 고민"]},
	{"v": "v0.84", "notes": ["스킬별 쿨타임 게이지 — 보유한 스킬마다 이름+쿨타임 바를 따로 표시. 각 스킬이 자기 쿨타임으로 독립 충전·발동하는 게 한눈에 보임(여러 스킬이 엇갈려 터짐)"]},
	{"v": "v0.83", "notes": ["전설 카드 3종 — 수확자(체력 20% 이하 적을 스킬·마력탄으로 즉사)·광전사(스킬 위력 +80%/체력 -30)·만신전(공격력·위력·연사 전능 강화)"]},
	{"v": "v0.82", "notes": ["잔류 장판 (행동 카드) — '잔류 장판'을 얻으면 메테오·융단폭격이 명중 지점에 지속 피해 필드를 남긴다(약 2.6초). 불바다·서리밭 같은 광역 빌드"]},
	{"v": "v0.81", "notes": ["적 탄막 명중 폭발 — 탄막이 기지에 피해를 줄 때 명중 지점에 작은 폭발+충격파", "카드 5등급 희귀도 — 일반·고급·희귀·영웅·전설로 세분(색·뱃지·프레임 차등). 보스 보상은 희귀 이상 확정"]},
	{"v": "v0.80", "notes": ["기지 충돌 임팩트 — 적이 기지에 도달하면 충돌 지점에 큰 폭발 + 충격파 링 2겹 + 강한 화면 흔들림 (콰과과광)"]},
	{"v": "v0.79", "notes": ["업데이트 알림 팝업 가로 확장 — 더 넓은 카드로(내용을 양끝으로 배치). ※ 다음 업데이트부터 적용"]},
	{"v": "v0.78", "notes": ["기지 내구도 표시를 방패 아이콘으로 변경", "스킬 진화 4티어(궁극) 추가 — 비전 노바·종말의 운석·뇌신의 분노·절대 영도·행성 붕괴까지 진화"]},
	{"v": "v0.77", "notes": ["기지 방어 판정 — 적 탄막이 마법사가 아닌 '기지'를 맞히는 판정으로 변경(피해는 기지 내구도). 넉백 행동 카드 '밀쳐내기' 추가 — 스킬 명중 시 적을 기지에서 밀어내 시간 벌기"]},
	{"v": "v0.76", "notes": ["'새 버전 있음' 알림 디자인 개선 — 밋밋한 알약에서 그라데이션 카드 팝업(✨ 아이콘 + 제목·부제 + 업데이트 버튼, 위에서 슬라이드인)으로. ※ 이 알림은 다음 업데이트부터 새 모양으로 보임"]},
	{"v": "v0.75", "notes": ["규칙 변경 전설 카드 — 메아리(모든 스킬이 0.25초 뒤 60% 위력으로 한 번 더 발동) · 공명(스킬이 화상·둔화 부여 + 즉시 기폭·파쇄, 반응 엔진을 한 장에)"]},
	{"v": "v0.74", "notes": ["카드 아이콘 + 상세 설명 — 드래프트 카드에 종류별 아이콘(공격·연사·위력·폭발·화염·서리·다발·방어·스킬)과 효과·수치·시너지를 적은 설명", "리스크-리턴 카드 추가 — 광신(위력↑/체력↓)·필사의 각오(공격력↑/체력↓)·폭주(연사·위력↑/방어↓)"]},
	{"v": "v0.73", "notes": ["카드 선택 연출 강화 — 호버 시 카드가 떠오르고, 고르면 그 카드가 번쩍 팝업·나머지는 흐려진 뒤 닫힘", "스킬 진화를 5종 전부로 확장 — 전격→폭풍 번개→천벌 / 서리바람→눈보라→영겁의 겨울 / 융단폭격→집중포화→궤도 포격"]},
	{"v": "v0.72", "notes": ["스킬 진화 트리 — 같은 스킬을 다시 얻으면 상위로 진화(마력탄→연발 마력탄→마력 폭풍 / 유성→쌍둥이 메테오→운석 강우). 위력·횟수·쿨 강화 + 이름 변화로 '빌드 완성' 손맛. 최고 티어 후엔 새 스킬로 누적"]},
	{"v": "v0.71", "notes": ["카드 자동선택 — 드래프트에서 10초 동안 안 고르면 자동으로 1장 선택. 카드 화면의 토글로 켜고 끄며(설정 영속), 켜면 남은 시간 표시. 기본은 꺼짐"]},
	{"v": "v0.70", "notes": ["원소 반응 1차 — 부여(화염/서리 각인: 스킬이 화상·둔화 부여) + 격발(기폭: 화상 적을 터뜨려 광역 / 파쇄: 둔화·빙결 적 추가타). 화염각인+기폭 같은 콤보로 멀티원소 빌드 시작"]},
	{"v": "v0.69", "notes": ["행동 카드 1차 — 숫자 대신 '플레이가 바뀌는' 카드 도입. 처치 폭발(스킬로 적 처치 시 주변 폭발)·다발(표적형 스킬이 적을 더 노림). 관통·연쇄·장판·원소 반응 등은 이후 확장"]},
	{"v": "v0.68", "notes": ["밸런스 — 무한 모드 적 '피해'에 상한(×12) 도입. 체력은 계속 증가하되 한 방 즉사를 막아 체력 안배가 가능(라운드 60 즉사 해결). 위협 표기에 '(최대)' 안내", "코인 표시를 텍스트 대신 동전 아이콘으로(인게임 카운터)"]},
	{"v": "v0.67", "notes": ["마법사 탭이 안 먹던 문제 수정 — 마법사 위 탭 영역으로 교체해 능력치 창이 확실히 열림"]},
	{"v": "v0.66", "notes": ["스킬 가시성 향상 — 광역 스킬 범위 링 + 시전 시 스킬 이름 표시 + 더 큰 이펙트", "마법사를 탭하면 현재 능력치 창(공격력·방어·기지 내구도·보유 스킬·유물)", "마법사의 기지(성벽) 추가 — HP를 '기지 내구도'로, 적을 막아 기지를 지키는 연출"]},
	{"v": "v0.65", "notes": ["스킬 획득 카드 — 드래프트에서 새 스킬(마력탄·유성·전격·서리바람·융단폭격)을 얻어 독립 쿨타임으로 추가 시전. 여러 스킬이 엇갈려 터지며 빈 시간을 메우고 빌드가 다양해짐", "홈 화면 하단 네비게이션 바 — 강화·유물·패치노트를 하단 고정 바로, 중앙은 캐릭터 선택+시작에 집중"]},
	{"v": "v0.64", "notes": ["유물·흡혈 부활 — 수확(즉사)·점화(화상)·격노(저체력 +50%)·흡혈이 스킬 명중에도 적용(스킬 전환으로 비활성됐던 것 복원). 각 캐릭터 시그니처(둔화·화상·광역·연쇄)는 스킬 자체에 유지"]},
	{"v": "v0.63", "notes": ["홈 화면 정리 — 캐릭터 카드를 핵심(이름·속성·설명)만 4줄로 간결화, 보조 버튼(강화·유물·패치노트)을 한 줄로 묶고 코인 잔액을 상단에 표기"]},
	{"v": "v0.62", "notes": ["PWA 업데이트 배너 — 새 버전이 준비되면 '탭하여 업데이트' 배너 표시. 게임 중 갑작스런 강제 새로고침(런 날아감) 제거, 원할 때 적용"]},
	{"v": "v0.61", "notes": ["마력탄이 보이게 수정 — 견습 스킬이 즉시 명중 대신 가까운 적에게 발사체가 날아가 적중(시각 피드백 복원)"]},
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
var auto_card := false  ## 카드 드래프트 10초 후 자동선택 토글 — 영속
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

func set_auto_card(b: bool) -> void:
	auto_card = b
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
		auto_card = cf.get_value("settings", "auto_card", false)
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
	cf.set_value("settings", "auto_card", auto_card)
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
