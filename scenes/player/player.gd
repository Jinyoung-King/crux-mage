extends Node2D
## 고정 위치에서 가장 가까운 적들을 자동 조준해 발사하는 마법사. 이동/입력 없음.

signal fired(projectile)
signal hp_changed(hp: float, max_hp: float)
signal died
signal skill_cast(data: Dictionary)  ## 액티브 스킬 발동 — {id,power,radius,count,element} (main이 효과 처리)
signal took_damage(amount: float)  ## 받는 피해 (빨간 데미지 숫자 표시용)

const BARRIER_DROID := preload("res://scenes/fx/barrier_droid.gd")  ## 방어형 비행체(지속형 동반자)
const SKILL_BOLT_TEX := preload("res://assets/sprites/bolt_skill.png")  ## (구) 마력탄 절차 발사체 — 가시 화살은 외부 시트로 대체
const KNIFE := preload("res://assets/sprites/knife.png")  ## 비도술사(금속) 평타 = 투척 단검
const THORN_ARROW := preload("res://assets/sprites/thorn_arrow.png")  ## 가시 화살 스킬 = 날카로운 화살
const PLAIN_BOLT := preload("res://assets/sprites/bolt_dot.png")  ## 평타 공용 초소형 점(8px, 초경량 — 스킬 발사체와 명확히 구분)
const FOCUS_SPREAD := PI / 90.0  ## 표적보다 발사 수가 많을 때 같은 표적에 겹쳐 쏘는 발사의 부채 각(≈2°)
const BASIC_ATTACK_MULT := 0.04  ## 평타 피해 = effective_damage()의 이 비율(약한 베이스라인 — 스킬 쿨과 별개로 연사 주기마다)
const DRONE_ASSIST_MULT := 0.6   ## 수호 비행체 평타 보조 사격 = 평타 피해의 이 비율(드론별·약화 보조)
const MAX_SKILL_SLOTS := 5  ## 스킬 슬롯 제한(캐릭터 고유 1 포함) — 다 쓰기 방지·슬롯 차면 진화 유도. v1.95 4→5(원소 균열 몰빵 여유, 성능은 발사체/FX 상한이 보장)
const EVOLVE_COST := 3  ## 같은 스킬 카드를 이만큼 모으면 1단계 진화(분기 선택)
const ANCHOR_AFFINITY := 0.30   ## [어피니티] 마법사 속성(앵커) 기본 어피니티
const PER_SKILL_AFFINITY := 0.20  ## [어피니티] 장착 스킬 1개당 그 속성 어피니티 가산
# [능동] 시그니처 스킬 — 자동 시전과 별개로 플레이어가 '직접 조준·발동'하는 한 방.
# 자동은 '최대 처치(밀집)'를 노리지만, 시그니처는 사람이 '돌파 위협'을 끊는 방어 트리아지용(자동이 못 하는 결정).
const SIGNATURE_POWER_MULT := 2.5  ## 시그니처 기본 위력 배수(자동 스킬보다 강함)
const SIGNATURE_RADIUS_MULT := 1.4 ## 범위 배수(eff_radius에서 MAX_SKILL_RADIUS로 클램프)
const SIG_MAX := 2.0               ## 충전 상한(1.0=발동 가능, 1.0~2.0=과충전 구간)
const SIG_KILL_GAIN := 0.16        ## 처치당 충전(≈7킬에 발동 가능) — 공격적으로 잡을수록 빨리 참
const SIG_PASSIVE := 0.07          ## 초당 시간 충전(킬 없어도 ≈14초면 발동) — 막힘 방지
## 주력 속성 → 시그니처 스킬 id(보유 스킬과 무관하게 속성이 부여; 전부 조준 지점에 시전)
const SIGNATURE_SKILL := {"fire": "inferno", "water": "glacier", "wood": "thorns", "metal": "chain", "earth": "barrage"}
var signature_charge := 0.0        ## 충전량(0~SIG_MAX). 1.0↑ 발동 가능, 초과분=과충전(늦게 쏠수록 강함)
var sig_charge_mult := 1.0         ## [모디파이어] 충전 속도 배율(런 모디파이어가 설정 — '응축' 등)

@export var max_hp: float = 100.0

var build: BuildState
var hp: float
var character: CharacterData
var lifesteal := 0.0  ## 입힌 피해의 흡혈 비율 (영구 강화)
var relic_levels := {}  ## 이번 런 보유 유물 {id: level} (GameState에서 복사 — 보유분 전부 적용, 레벨=강화)
var skills: Array = []  ## 보유 스킬 목록(각 dict: id/name/cooldown/power/radius/count/cd_left). [0]=캐릭터 고유, 이후=카드 획득
var skills_paused := false  ## 카드 선택(드래프트/상점) 중 스킬 쿨타임 정지
var _barrier_droid: Node2D  ## 방어형 비행체 동반자(barrier_droid 스킬 보유 시 생성) — 쿨캐스트 아님
var hit_modifiers: Array = []  ## 활성 적중 전략(HitModifierLib) — 빌드/유물/캐릭터 변경 시 rebuild_hit_modifiers()로 재구성
var host  ## main 참조(발사체 풀 acquire_projectile 호출용) — main._ready에서 주입
var reverse_aim := false  ## [리버스] true면 위로 오는 몹을 향해 조준 리드를 위쪽으로

## 빌드·유물·캐릭터가 바뀔 때마다 활성 적중 전략 목록을 다시 구성(매 적중이 아닌 변경 시 1회)
func rebuild_hit_modifiers() -> void:
	recompute_affinity()  # [어피니티] 빌드 변경 시 재계산
	hit_modifiers = HitModifierLib.build_for(self)

## [어피니티] 장착 스킬+앵커로 affinity 재계산. 빌드 변경 시(rebuild_hit_modifiers) 호출.
func recompute_affinity() -> void:
	build.affinity.clear()
	if character:
		build.affinity[character.element] = ANCHOR_AFFINITY
	for s in skills:
		var e: String = SkillLib.DEFS.get(s.id, {}).get("element", "")
		if e != "":
			build.affinity[e] = float(build.affinity.get(e, 0.0)) + PER_SKILL_AFFINITY

## [어피니티] 현재 빌드 아키타입 라벨. 최고 어피니티=전문화, 2위가 0.4↑면 콤보.
func archetype_label() -> String:
	var sorted: Array = build.affinity.keys()
	sorted.sort_custom(func(a, b): return float(build.affinity[a]) > float(build.affinity[b]))
	if sorted.is_empty():
		return ""
	var hi: String = sorted[0]
	if sorted.size() >= 2 and float(build.affinity[sorted[1]]) >= 0.4:
		return "%s+%s 콤보" % [ElementLib.display_name(hi), ElementLib.display_name(sorted[1])]
	return "%s 전문화" % ElementLib.display_name(hi)

## 유물 획득 (중복 없음)
func grant_relic(id: String, level: int = 1) -> void:
	relic_levels[id] = level
	# 스탯형 신규 유물은 보유 즉시 빌드에 반영(기존 BuildState 처리점 재활용)
	match id:
		"bulwark": build.defense += 2.0 * level       # 방벽: 받는 피해 감소
		"twin":    build.extra_targets += level        # 쌍둥이: 표적형 스킬 추가 표적
		"vamp":    lifesteal += 0.03 * level            # 흡혈
		"swift":   build.fire_rate += 0.3 * level       # 신속: 연사↑ → 쿨 단축
		"split":   build.explode_power += 0.3 * level   # 분열: 처치 폭발
		"giant":
			var add := 20.0 * level                     # 거인: 최대 체력↑(현재 체력도 함께)
			max_hp += add
			hp += add
	rebuild_hit_modifiers()  # 유물 변경 반영

func _process(delta: float) -> void:
	if relic_levels.has("regen") and hp > 0.0 and hp < max_hp:
		heal(RelicLib.regen_per_sec(relic_levels["regen"]) * delta)  # 재생의 룬(레벨별)
	if hp > 0.0 and signature_charge < SIG_MAX:
		signature_charge = minf(signature_charge + SIG_PASSIVE * sig_charge_mult * delta, SIG_MAX)  # [능동] 시그니처 시간 충전(주력은 처치 충전)
	# 액티브 스킬: 보유 스킬마다 독립 쿨타임으로 자동 발동 (연사 스탯이 모든 쿨타임 단축)
	if hp > 0.0 and not skills_paused:
		for s in skills:  # 모든 모드 자동 시전(저편 수동은 v3.24에서 되돌림 — 코드는 main에 보존)
			if s.id == "barrier_droid":
				continue  # 지속형 동반자 — 쿨캐스트 아님(_barrier_droid 노드가 매 프레임 자동 동작)
			s.cd_left -= delta
			if s.cd_left <= 0.0:
				if _has_target_in_range(s):
					_cast_skill(s)
					s.cd_left = eff_cooldown(s)
				else:
					s.cd_left = 0.0  # 사거리 내 적이 없으면 시전 보류(쿨 0 유지 → 적 등장 즉시 발동, 낭비 방지)

@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	hp = max_hp
	build = BuildState.new()  # 런타임 생성 (.tres 직접 참조 금지)
	attack_timer.timeout.connect(_on_attack_timer_timeout)  # 평타(약한 기본 공격) 재도입 — 연사 연동, 스킬 쿨과 별개

## 선택 캐릭터의 무기·기본 빌드·외형 적용 (게임 시작 시 main이 호출)
func apply_character(c: CharacterData) -> void:
	character = c
	# 캐릭터 기본 빌드 + 영구 강화(메타) 보너스 가산
	var mastery := GameState.mastery_mult(c)  # 캐릭터 숙련도: 공격력·체력 +2%/레벨
	build.damage = (c.base_damage + GameState.upgrade_value("damage", c) + GameState.kill_bonus_damage()) * mastery * GameState.trait_damage_mult()
	build.fire_rate = c.base_fire_rate + GameState.upgrade_value("fire_rate", c) + GameState.trait_fire_rate_add()
	build.projectile_count = c.base_projectile_count
	build.defense = GameState.upgrade_value("defense", c)  # 방어력 강화(모자) — 받는 피해 감소(카드·방벽 룬은 이후 가산)
	build.skill_power_mult = 1.0 + GameState.trait_value("spell")   # 주문력 특성(스킬 위력) — 카드는 이후 가산
	build.skill_radius_mult = 1.0 + GameState.trait_value("reach")  # 광역 특성(스킬 범위)
	max_hp = (max_hp + GameState.upgrade_value("max_hp", c) + GameState.kill_bonus_hp()) * mastery * GameState.trait_hp_mult()  # 기본 100 + 강화 + 처치업적, 숙련·특성 배율
	hp = max_hp
	lifesteal = GameState.upgrade_value("lifesteal", c) + GameState.trait_lifesteal_add()
	attack_timer.wait_time = 1.0 / maxf(build.fire_rate, 0.1)  # 평타 발사 주기 = 현재 연사(연사 카드/특성/룬이 평타도 가속)
	attack_timer.start()  # 평타 재가동
	skills.clear()
	if c.skill_id != "":  # 캐릭터 고유 스킬을 슬롯 0으로
		skills.append(_make_skill(c.skill_id, c.skill_name, c.skill_cooldown, c.skill_power, c.skill_radius, c.skill_count))
	$Sprite2D.texture = c.mage_sprite
	rebuild_hit_modifiers()  # 캐릭터(치명타 패시브 등) 반영
	_sync_barrier_droid()    # 새 캐릭터(비행체 없음) — 기존 동반자 정리

## 웨이브 시작 시 패시브 회복 (견습 마법사)
func on_wave_start() -> void:
	if character and character.passive_wave_heal > 0.0 and hp < max_hp:
		hp = minf(hp + character.passive_wave_heal, max_hp)
		hp_changed.emit(hp, max_hp)

## 시너지 반영 실효 데미지: 기본 + (동시 표적당 데미지 × 동시 표적 수)
func effective_damage() -> float:
	var d := build.damage + build.damage_per_target * build.projectile_count
	if relic_levels.has("berserk") and hp < max_hp * RelicLib.BERSERK_HP_RATIO:
		d *= RelicLib.berserk_mult(relic_levels["berserk"])  # 격노의 룬(레벨별)
	return d

## 스킬 인스턴스 생성 (시작 시 쿨타임만큼 충전 필요)
func _make_skill(id: String, nm: String, cd: float, pwr: float, rad: float, cnt: int) -> Dictionary:
	var s := {"id": id, "name": nm, "cooldown": cd, "power": pwr, "radius": rad, "count": cnt, "cd_left": 0.0, "tier": 1, "stacks": 0}
	s.cd_left = eff_cooldown(s)
	return s

## 같은 계열 스킬 재획득 → 한 단계 진화(현재 스탯에 배율/가산). 최고 티어면 false 반환(새 인스턴스로 누적).
func _evolve_skill(id: String) -> bool:
	var evos: Array = SkillLib.EVOLVE.get(id, [])
	for s in skills:
		if s.id == id and s.tier - 1 < evos.size():  # tier1 → evos[0]이 다음 단계
			var e: Dictionary = evos[s.tier - 1]
			s.tier += 1
			s.name = e.name
			s.count += int(e.get("count", 0))
			s.cooldown *= float(e.get("cd_mult", 1.0))
			s.power *= float(e.get("power_mult", 1.0))
			s.radius *= float(e.get("radius_mult", 1.0))
			return true
	return false

## 이 스킬을 보유 중이고 아직 더 진화할 수 있는지(최고 단계 미도달). 드래프트 노출 판정용.
func can_evolve(id: String) -> bool:
	var evos: Array = SkillLib.EVOLVE.get(id, [])
	for s in skills:
		if s.id == id and s.tier - 1 < evos.size():
			return true
	return false

## 같은 스킬 카드 1장 적립(진화 진행). 매 픽 소폭 강화로 죽은 픽 방지. 임계(EVOLVE_COST) 도달 시 true(=진화 준비).
func add_skill_stack(id: String) -> bool:
	for s in skills:
		if s.id == id:
			s.power *= 1.08  # 누적 중에도 조금씩 강해짐
			s["stacks"] = int(s.get("stacks", 0)) + 1
			_sync_barrier_droid()  # 스택으로 위력 변동 → 비행체 dps 갱신(미보유면 무동작)
			return s["stacks"] >= EVOLVE_COST and can_evolve(id)
	return false

## 고른 진화 분기를 적용 — 단계↑·스택 리셋·분기 효과(강화/속성결합/행동결합). 빌드 플래그 변경 시 모디파이어 재구성.
func evolve_branch(id: String, branch: Dictionary) -> void:
	for s in skills:
		if s.id == id:
			s.tier += 1
			s["stacks"] = 0
			s.name = branch.get("name", s.name)
			s.power *= float(branch.get("power_mult", 1.0))
			s.count += int(branch.get("count_add", 0))
			s.radius *= float(branch.get("radius_mult", 1.0))
			match branch.get("kind", ""):
				"element":
					if branch.get("grant", "") == "burn": build.apply_burn = true; build.burn_level += 1
					elif branch.get("grant", "") == "slow": build.apply_slow = true; build.slow_level += 1
				"behavior":
					match branch.get("behavior", ""):
						"pierce": build.pierce += int(branch.get("amount", 1))
						"ground_field": build.ground_field = true; build.field_level += 1
						"extra_targets": build.extra_targets += int(branch.get("amount", 1))
						"explode": build.explode_power += float(branch.get("amount", 0.3))
			rebuild_hit_modifiers()
			_sync_barrier_droid()  # 진화로 비행체 파라미터 갱신
			return

## 보유 스킬에서 id를 찾아 반환(없으면 빈 사전)
func _find_skill(id: String) -> Dictionary:
	for s in skills:
		if s.id == id:
			return s
	return {}

## 저편 로드아웃: SkillLib 정의로 스킬을 추가 장착(시그니처와 중복이면 무시).
func grant_beyond_skill(id: String) -> void:
	if not _find_skill(id).is_empty():
		return  # 이미 보유(고유 스킬과 중복)
	var d: Dictionary = SkillLib.DEFS.get(id, {})
	if d.is_empty():
		return
	skills.append(_make_skill(id, d.get("name", id), d.get("cooldown", 5.0), d.get("power", 10.0), d.get("radius", 0.0), int(d.get("count", 0))))

## 방어형 비행체 동반자 생성/갱신/제거 — barrier_droid 스킬 보유 상태에 동기화(획득·진화·캐릭터 변경 시).
func _sync_barrier_droid() -> void:
	var s := _find_skill("barrier_droid")
	if s.is_empty():
		if is_instance_valid(_barrier_droid):
			_barrier_droid.queue_free()
		_barrier_droid = null
		return
	if not is_instance_valid(_barrier_droid):
		_barrier_droid = BARRIER_DROID.new()
		add_child(_barrier_droid)
	_barrier_droid.configure(self, s)

## 스킬 사거리 내에 살아있는 적이 하나라도 있는지 (executor._enemies_in_range와 동일 기준)
func _has_target_in_range(s: Dictionary) -> bool:
	var rng: float = SkillLib.SKILL_RANGE.get(s.id, 99999.0)
	for e in EnemyCache.all():
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= rng:
			return true
	return false

## 스킬 발동: 실효 위력/범위를 풀어 main에 전달. aim_pos가 주어지면(저편 수동) 그 좌표를 조준점으로 전달.
func _cast_skill(s: Dictionary, aim_pos: Vector2 = Vector2.INF) -> void:
	_skill_pose()  # 시전 포즈(위로 쭉 뻗으며 번쩍)
	var data := {
		"id": s.id,
		"name": s.name,
		"power": eff_power(s),
		"radius": eff_radius(s),
		"count": s.count,
		"element": SkillLib.DEFS.get(s.id, {}).get("element", character.element if character else ""),  # 스킬 자체 속성(시전자 속성 아님) — 색·상성 통일
	}
	if aim_pos != Vector2.INF:
		data["aim"] = aim_pos  # 수동 조준점 — skill_executor가 군집 자동조준 대신 이 좌표를 중심으로
	skill_cast.emit(data)
	if build.echo:  # 메아리: 0.25초 뒤 재시전(누적 시 위력↑, 재귀 없음 — _cast_skill 안 거침)
		var echo_data := data.duplicate()
		echo_data["power"] = data["power"] * build.echo_power()
		get_tree().create_timer(0.25).timeout.connect(func() -> void:
			if hp > 0.0:
				skill_cast.emit(echo_data))

## 저편 수동 시전: 준비된 스킬(idx)을 지정 좌표에 시전. aim은 스킬 사거리로 클램프(밸런스 유지). 성공 시 true.
func cast_skill_manual(idx: int, aim: Vector2) -> bool:
	if idx < 0 or idx >= skills.size():
		return false
	var s: Dictionary = skills[idx]
	if s.id == "barrier_droid" or s.cd_left > 0.0:
		return false  # 지속형이거나 아직 쿨 중
	var rng: float = SkillLib.SKILL_RANGE.get(s.id, 99999.0)
	var clamped: Vector2 = global_position + (aim - global_position).limit_length(rng)  # 사거리 밖이면 경계로
	_cast_skill(s, clamped)
	s.cd_left = eff_cooldown(s)
	return true

## [능동] 현재 주력(최고 어피니티) 속성 — 시그니처가 이 속성으로 결정됨(없으면 캐릭터 앵커 속성)
func signature_element() -> String:
	var top: String = character.element if character else ""
	var top_v := 0.0
	for e in build.affinity:
		if float(build.affinity[e]) > top_v:
			top_v = float(build.affinity[e]); top = e
	return top

func signature_ready() -> bool:
	return signature_charge >= 1.0 and hp > 0.0

## [능동] 처치 시 시그니처 충전 — 공격적으로 잡을수록 빨리 참(인게이지 보상). main._on_enemy_died에서 호출.
func gain_signature_charge() -> void:
	if hp > 0.0:
		signature_charge = minf(signature_charge + SIG_KILL_GAIN * sig_charge_mult, SIG_MAX)

## [능동] 시그니처 시전: 준비됐으면 주력 속성 스킬을 aim 지점에 시전(자동 스킬과 별개). 성공 시 true.
## 위력·범위·연출은 _cast_skill/eff_power(어피니티 반영)를 그대로 재사용 — 강한 한 방으로 합성한 스킬 dict를 넘긴다.
func cast_signature(aim: Vector2) -> bool:
	if not signature_ready():
		return false
	var elem: String = signature_element()
	var id: String = SIGNATURE_SKILL.get(elem, "inferno")
	var def: Dictionary = SkillLib.DEFS.get(id, {})
	if def.is_empty():
		return false
	var over: float = clampf(signature_charge, 1.0, SIG_MAX)  # 1.0~2.0 — 과충전(늦게 쏠수록 큼)
	var pmul: float = SIGNATURE_POWER_MULT * (1.0 + (over - 1.0) * 0.9)  # 과충전 위력 최대 +90%
	var rmul: float = SIGNATURE_RADIUS_MULT * (1.0 + (over - 1.0) * 0.3)  # 과충전 범위 +30%
	var sig := {
		"id": id,
		"name": def.get("name", "시그니처"),
		"power": float(def.get("power", 10.0)) * pmul,
		"radius": float(def.get("radius", 100.0)) * rmul,
		"count": int(def.get("count", 1)),
	}
	var rng: float = SkillLib.SKILL_RANGE.get(id, 99999.0)
	var clamped: Vector2 = global_position + (aim - global_position).limit_length(rng)  # 사거리 밖이면 경계로
	_cast_skill(sig, clamped)  # 위력·범위·포즈·연출 재사용(aim 좌표로 군집 자동조준 대체)
	signature_charge = 0.0  # 발동 시 충전 소진
	return true

## 쿨 하한을 넘긴 '초과 연사'를 위력으로 환산하는 비율 / 그 보너스 상한(+75%) — 평타 없는 구조에서 연사가 죽지 않게.
const OVERFLOW_TO_DMG := 0.5
const OVERFLOW_DMG_CAP := 0.75

## 하한 적용 전 '원시' 쿨타임 (연사에 반비례)
func _raw_cooldown(s: Dictionary) -> float:
	if character == null or character.base_fire_rate <= 0.0 or build.fire_rate <= 0.0:
		return s.cooldown
	return s.cooldown * character.base_fire_rate / build.fire_rate

## 실효 쿨타임: 원시 쿨(연사↑이면 ↓), 단 기본쿨의 60%(최소 2초) 밑으론 안 내려감 — 강력·광역 스킬 난사 방지.
func eff_cooldown(s: Dictionary) -> float:
	return maxf(_raw_cooldown(s), maxf(2.0, s.cooldown * 0.6))

## 쿨 하한을 넘어선 초과 연사를 위력 배율로 환산(>=1.0). 하한 도달 후에도 연사 카드·특성·룬이 위력으로 계속 기여.
func fire_overflow_mult(s: Dictionary) -> float:
	var floor_cd: float = maxf(2.0, s.cooldown * 0.6)
	var raw: float = _raw_cooldown(s)
	if raw >= floor_cd:
		return 1.0  # 아직 하한 미달 — 연사가 쿨 단축에 쓰이는 중
	return 1.0 + minf((floor_cd / raw - 1.0) * OVERFLOW_TO_DMG, OVERFLOW_DMG_CAP)

## 보유한 모든 스킬이 이미 '초과 연사 → 위력' 환산 상한(+75%)에 도달했나 — 그러면 연사 카드는 무의미.
## (인게임 연사 카드는 쿨 단축+초과위력에만 쓰임 — 평타 속도는 캐릭터 셋업 고정이라 카드론 영향 없음)
func fire_rate_all_capped() -> bool:
	if skills.is_empty():
		return false
	for s in skills:
		if fire_overflow_mult(s) < 1.0 + OVERFLOW_DMG_CAP - 0.001:
			return false  # 아직 연사가 쿨 단축/위력 환산으로 더 기여할 스킬 존재
	return true

## 실효 위력 = 기본위력 × (현재공격력/기본공격력) × 강화% × 초과연사보너스 — 공격력·강화·숙련·초과연사가 모든 스킬을 키움
func eff_power(s: Dictionary) -> float:
	var p: float = s.power * build.skill_power_mult
	if character != null and character.base_damage > 0.0:
		p = s.power * (build.damage / character.base_damage) * build.skill_power_mult
	var elem: String = SkillLib.DEFS.get(s.id, {}).get("element", "")  # 균열 + 어피니티: 속성 일치 스킬 위력↑
	var bonus: float = float(build.element_empower.get(elem, 0.0)) + float(build.affinity.get(elem, 0.0))
	if bonus != 0.0:
		p *= 1.0 + bonus
	return p * fire_overflow_mult(s)

## 범위 상한 — 범위 카드·진화로 광역이 화면 전체를 도배하면 렉↑·밀집타겟팅 무의미·재미↓.
## 이 선까지만 커지게 제한(반경 0인 스킬=마력탄·비도·서리는 영향 없음).
const MAX_SKILL_RADIUS := 200.0

func eff_radius(s: Dictionary) -> float:
	return minf(s.radius * build.skill_radius_mult, MAX_SKILL_RADIUS)

## 주 스킬(슬롯0) 충전 진행도 0~1 (HUD 게이지용)
func skill_ratio() -> float:
	if skills.is_empty():
		return 0.0
	return cd_ratio(skills[0])

## 개별 스킬 충전 진행도 0~1 (스킬별 게이지용)
func cd_ratio(s: Dictionary) -> float:
	var cd := eff_cooldown(s)
	return clampf(1.0 - s.cd_left / cd, 0.0, 1.0) if cd > 0.0 else 1.0

## 스킬 발사체 1발: 예측 조준으로 target에 마력탄을 쏨(위력=dmg). 평타 패시브/유물 미적용 — 순수 스킬.
## fired 신호로 main이 사운드·데미지숫자 연결 + Projectiles에 추가. 상성/사망연출은 발사체가 자체 처리.
## target=적이면 예측 조준(자동), aim_point가 주어지면(저편 미사일 조준) 그 지점 방향으로 직선 발사.
func fire_skill_bolt(target, dmg: float, elem: String, aim_point: Vector2 = Vector2.INF) -> void:
	var p = host.acquire_projectile()
	if p == null:
		return  # 발사체 풀/캡 초과 — 드랍
	var spr: Sprite2D = p.get_node("Sprite2D")
	spr.texture = THORN_ARROW  # 가시 화살 — 날카로운 화살 스프라이트(단일 프레임)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 픽셀 선명
	spr.modulate = Color.WHITE  # 원색 유지
	spr.scale = Vector2(2.6, 2.6)  # 12px → 보이게 확대
	p.element = elem  # 스킬 속성으로 상성 판정(시전자 속성 아님)
	p.enable_trail()  # 스킬 마력탄: 속성색 꼬리 잔광(평타는 없음)
	if character:
		p.crit_chance = character.passive_crit_chance
		p.crit_mult = character.passive_crit_mult
	p.position = global_position
	if aim_point != Vector2.INF:
		p.direction = (aim_point - global_position).normalized()  # 저편 조준: 지정 방향으로 직선 발사
	else:
		# 적이 아래로 이동 중이므로 비행시간만큼 앞질러 예측 조준
		var flight_time: float = global_position.distance_to(target.global_position) / p.speed
		var predicted: Vector2 = target.global_position + (Vector2.UP if reverse_aim else Vector2.DOWN) * target.speed * flight_time
		p.direction = (predicted - global_position).normalized()
	p.rotation = p.direction.angle()
	if relic_levels.has("berserk") and hp < max_hp * RelicLib.BERSERK_HP_RATIO:
		dmg *= RelicLib.berserk_mult(relic_levels["berserk"])  # 격노의 룬(레벨별)
	p.damage = dmg
	p.lifesteal = lifesteal  # 흡혈은 acquire에서 dealt→_on_lifesteal 1회 연결됨(방출은 lifesteal>0일 때만)
	if build.apply_burn:
		p.burn_dps = maxf(p.burn_dps, RelicLib.RELIC_BURN_DPS * build.burn_mult())  # 부여: 화상(누적 강화)
		p.burn_duration = maxf(p.burn_duration, RelicLib.RELIC_BURN_DUR + build.burn_dur_add())
	if build.apply_slow:
		p.slow_factor = build.slow_factor_card()  # 부여: 둔화(누적 강화)
		p.slow_duration = build.slow_dur_card()
	_apply_relics_to(p)  # 수확·연쇄·점화의 룬을 발사체에 적용
	if build.execute_threshold > 0.0:
		p.execute_threshold = maxf(p.execute_threshold, build.execute_threshold)  # 수확자 카드
	p.pierce = build.pierce  # 관통: 마력탄이 적을 꿰뚫음
	fired.emit(p)

func _on_attack_timer_timeout() -> void:
	if hp <= 0.0 or skills_paused:
		return  # 사망·카드선택 중엔 평타 정지
	var shots := 1  # 평타는 항상 1발(projectile_count는 스킬·시너지용 — 서리마도사 3발 평타 방지)
	var targets := _nearest_enemies(shots)  # 가까운 순 최대 shots명
	if targets.is_empty():
		return
	_recoil()
	# 발사 수가 표적보다 많으면 남는 발사를 기존 표적에 집중사격(낭비 방지).
	# 같은 표적에 겹치는 발사는 살짝 부채꼴로 흩뿌려 시각 구분 + 인근 적 산탄 효과.
	for i in shots:
		var target = targets[i % targets.size()]
		var dup := i / targets.size()  # 같은 표적에 몇 번째 발사인지(0=첫 발)
		var offset := 0.0
		if dup > 0:
			var mag: float = ((dup + 1) / 2) * FOCUS_SPREAD
			offset = mag if dup % 2 == 1 else -mag
		_fire_at(target, offset)

## 발사 반동: 살짝 눌렸다가 복귀
func _recoil() -> void:
	$Sprite2D.scale = Vector2(3.4, 2.6)
	create_tween().tween_property($Sprite2D, "scale", Vector2(3, 3), 0.12)

## 스킬 시전 포즈: 위로 쭉 뻗었다 탄성 복귀 + 잠깐 번쩍(마법 시전 느낌)
func _skill_pose() -> void:
	var spr := $Sprite2D
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(2.6, 3.6), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "scale", Vector2(3, 3), 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var fl := create_tween()
	fl.tween_property(spr, "modulate", Color(1.6, 1.6, 1.9), 0.08)
	fl.tween_property(spr, "modulate", Color(1, 1, 1), 0.26)

## 가까운 순으로 최대 count명의 적을 반환
func _nearest_enemies(count: int) -> Array:
	var enemies := EnemyCache.all().duplicate()  # 정렬하므로 공유 스냅샷 복제(원본 변형 금지)
	enemies.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return enemies.slice(0, count)

## 적 도달 등으로 피해를 받음
func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return  # 사망 후 같은 프레임에 도달한 적의 중복 피해 방지
	amount = maxf(amount - build.defense, 1.0)  # 방어력: 받는 피해 감소(최소 1)
	took_damage.emit(amount)  # 받는 피해 숫자 표시
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()

## 카드 보너스를 빌드에 적용
func apply_card(card: CardData) -> void:
	if card.grant_skill_id != "":  # 스킬 카드 — 보유 시 진화, 없으면 슬롯 여유 시에만 새 스킬
		if not _evolve_skill(card.grant_skill_id):
			var d: Dictionary = SkillLib.DEFS.get(card.grant_skill_id, {})
			if not d.is_empty() and skills.size() < MAX_SKILL_SLOTS:
				skills.append(_make_skill(card.grant_skill_id, d.name, d.cooldown, d.power, d.radius, d.count))
	build.damage += card.damage_bonus
	build.fire_rate += card.fire_rate_bonus  # 평타 아님 — 스킬 쿨타임 감소에 반영
	build.projectile_count += card.projectile_count_bonus
	build.damage_per_target += card.damage_per_target_bonus
	build.defense += card.defense_bonus
	build.skill_power_mult += card.skill_power_bonus
	build.skill_radius_mult += card.skill_radius_bonus
	build.explode_power += card.explode_power_bonus  # 처치 폭발
	build.extra_targets += card.extra_targets_bonus   # 다발(추가 표적)
	if card.grant_burn:
		build.apply_burn = true   # 부여: 화상
		build.burn_level += 1     # 누적: 중복할수록 화상 강화
	if card.grant_slow:
		build.apply_slow = true   # 부여: 둔화
		build.slow_level += 1     # 누적: 중복할수록 둔화 강화
	build.detonate_burn += card.detonate_burn_bonus  # 격발: 기폭
	build.frostbite += card.frostbite_bonus          # 격발: 파쇄
	if card.grant_echo:
		build.echo = true   # 메아리
		build.echo_level += 1  # 누적: 중복할수록 재시전 위력↑
	build.knockback += card.knockback_bonus  # 넉백
	if card.grant_ground_field:
		build.ground_field = true  # 잔류 장판
		build.field_level += 1     # 누적: 중복할수록 장판 피해↑
	build.execute_threshold += card.execute_threshold_bonus  # 수확자(즉사)
	build.pierce += card.pierce_bonus  # 관통(마력탄 꿰뚫기)
	match card.keystone:  # [키스톤] 빌드를 가르는 규칙 변경 — 기존 시스템 강하게 재활용
		"pierce_chain":
			build.keystone_pierce_chain = true
			build.pierce += 2
		"persist_field":
			build.keystone_persist_field = true
			build.ground_field = true
			build.field_level += 1
		"execute_chain":
			build.keystone_execute_chain = true
			build.execute_threshold += 0.18  # 저체력 즉사
			build.explode_power += 0.7        # 처치 시 폭발(연쇄)
		"overload":  # [키스톤] 원소 폭주 — 화상+둔화 동시 부여로 상시 과부하(기존 반응 시스템 재활용)
			build.keystone_overload = true
			build.apply_burn = true; build.burn_level += 1
			build.apply_slow = true; build.slow_level += 1
		"echo":  # [키스톤] 메아리 군주 — 모든 스킬 강하게 재시전(기존 echo 재활용)
			build.keystone_echo = true
			build.echo = true; build.echo_level += 2
	if card.max_hp_bonus != 0.0:
		max_hp = maxf(max_hp + card.max_hp_bonus, 10.0)  # 트레이드오프로도 최소 10은 보장
		hp = minf(hp, max_hp)
		hp_changed.emit(hp, max_hp)
	if card.heal > 0.0:
		hp = minf(hp + card.heal, max_hp)
		hp_changed.emit(hp, max_hp)
	rebuild_hit_modifiers()  # 빌드 변경 반영
	_sync_barrier_droid()    # 비행체 스킬 획득/변경 반영(미보유면 무동작)
	attack_timer.wait_time = 1.0 / maxf(build.fire_rate, 0.1)  # 연사 변동 → 평타 주기 갱신(다음 주기부터)

func _fire_at(target, aim_offset := 0.0, origin := Vector2.INF, dmg_scale := 1.0) -> void:
	var p = host.acquire_projectile()
	if p == null:
		return  # 발사체 풀/캡 초과 — 드랍(평타는 가장 많이 발사 → 여기서 자주 컷)
	var src: Vector2 = global_position if origin == Vector2.INF else origin  # 발사 원점(드론 보조 사격 시 드론 위치)
	var spr: Sprite2D = p.get_node("Sprite2D")
	if character and character.element == "metal":  # 비도술사: 투척 단검(점 대신 칼날)
		spr.texture = KNIFE
		spr.scale = Vector2(2.0, 2.0)
		spr.modulate = Color.WHITE  # 강철 원색 유지(틴트 안 함)
	else:
		spr.texture = PLAIN_BOLT  # 그 외 평타 = 초소형 점(스킬 발사체와 구분)
		spr.scale = Vector2(1.25, 1.25)  # ~10px
		if character:
			spr.modulate = ElementLib.color(character.element)  # 평타 점에 속성색(약한 정체성)
	if character:
		# 패시브 효과를 발사체에 실어 보냄
		p.element = character.element  # 오행 속성(상성 판정)
		p.crit_chance = character.passive_crit_chance
		p.crit_mult = character.passive_crit_mult
		p.burn_dps = character.passive_burn_dps
		p.burn_duration = character.passive_burn_duration
		p.slow_factor = character.passive_slow_factor
		p.slow_duration = character.passive_slow_duration
		p.chain_count = character.passive_chain_count
		p.chain_factor = character.passive_chain_factor
		p.chain_range = character.passive_chain_range
		p.splash_factor = character.passive_splash_factor
		p.splash_radius = character.passive_splash_radius
	p.position = src  # Projectiles 컨테이너가 원점에 있어 전역 좌표와 동일(드론이면 드론 위치)
	# 적이 아래로 이동 중이므로 비행시간만큼 앞질러 조준 (1회 예측으로 충분)
	var flight_time: float = src.distance_to(target.global_position) / p.speed
	var predicted: Vector2 = target.global_position + (Vector2.UP if reverse_aim else Vector2.DOWN) * target.speed * flight_time
	p.direction = (predicted - src).normalized()
	if aim_offset != 0.0:
		p.direction = p.direction.rotated(aim_offset)  # 집중사격 부채 흩뿌림
	p.rotation = p.direction.angle()
	p.damage = effective_damage() * BASIC_ATTACK_MULT * dmg_scale  # 평타 = 공격력의 일부(드론 보조는 dmg_scale로 약화)
	if build.keystone_pierce_chain:  # [키스톤] 평타가 적을 꿰뚫고 튕긴다(레인 관통 빌드)
		p.pierce += 3
		p.chain_count += 2
		p.chain_factor = maxf(p.chain_factor, 0.55)
		p.chain_range = maxf(p.chain_range, 240.0)
	if host._perf_tier < 2:
		p.enable_trail(true)  # 평타도 은은한 잔광(얇고 짧게) — 저성능 단계에선 생략
	p.lifesteal = lifesteal  # dealt→_on_lifesteal는 acquire에서 1회 연결(방출은 lifesteal>0일 때만)
	_apply_relics_to(p)
	fired.emit(p)

## 수호 비행체 평타 보조: 드론 위치(origin)에서 target에게 약화된 평타 1발(barrier_droid가 호출).
func fire_assist(origin: Vector2, target) -> void:
	if target == null or not is_instance_valid(target):
		return
	_fire_at(target, 0.0, origin, DRONE_ASSIST_MULT)

## 유물 효과를 발사체에 적용 (캐릭터 패시브 위에 가산/강화)
func _apply_relics_to(p) -> void:
	if relic_levels.is_empty():
		return
	if relic_levels.has("execute"):
		p.execute_threshold = RelicLib.execute_threshold(relic_levels["execute"])
	if relic_levels.has("chain"):
		p.chain_count += RelicLib.chain_count(relic_levels["chain"])  # 레벨당 연쇄 +1
		p.chain_factor = maxf(p.chain_factor, RelicLib.RELIC_CHAIN_FACTOR)
		p.chain_range = maxf(p.chain_range, 220.0)
	if relic_levels.has("ignite"):
		p.burn_dps = maxf(p.burn_dps, RelicLib.burn_dps(relic_levels["ignite"]))
		p.burn_duration = maxf(p.burn_duration, RelicLib.RELIC_BURN_DUR)

## 흡혈 회복 (발사체가 적에 피해를 입힐 때마다)
func _on_lifesteal(amount: float) -> void:
	heal(amount)

func heal(amount: float) -> void:
	if hp <= 0.0:
		return  # 사망 후에는 회복 없음
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)
