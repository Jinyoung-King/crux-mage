class_name CardPool
extends RefCounted
## 카드 풀 + 드래프트 뽑기 로직. main.gd에서 분리(드래프트 '흐름'은 main에 남고, 여기는 '무엇을 뽑나'만).
## 빌드/스킬 조회 대상 플레이어 노드를 _init로 주입받아 참조한다(소유 아님).

const RARITY_WEIGHT := {"common": 3.0, "uncommon": 1.7, "rare": 1.0, "epic": 0.45, "legendary": 0.22}  # 등장 가중치(고급<희귀<영웅<전설 순 희소)

var _player: Node  # 빌드/스킬 조회 대상(main의 $Player)

# 전체 카드 풀(.tres 인스턴스). 키스톤은 keystone 필드로 구분된다.
var pool: Array = [
	preload("res://resources/cards/card_damage_up.tres"),
	preload("res://resources/cards/card_fire_rate.tres"),
	preload("res://resources/cards/card_heal.tres"),
	preload("res://resources/cards/card_damage_big.tres"),
	preload("res://resources/cards/card_fire_rate_big.tres"),
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
	preload("res://resources/cards/card_skill_thorns.tres"),
	preload("res://resources/cards/card_skill_inferno.tres"),
	preload("res://resources/cards/card_skill_rockfall.tres"),
	preload("res://resources/cards/card_skill_glacier.tres"),
	preload("res://resources/cards/card_skill_fireball.tres"),  # [화] 화염구
	preload("res://resources/cards/card_skill_tide.tres"),      # [수] 해일
	preload("res://resources/cards/card_skill_spores.tres"),    # [목] 포자 구름
	preload("res://resources/cards/card_skill_shrapnel.tres"),  # [금] 비도 난사
	preload("res://resources/cards/card_skill_quake.tres"),     # [토] 지진
	preload("res://resources/cards/card_explode.tres"),
	preload("res://resources/cards/card_explode_big.tres"),
	preload("res://resources/cards/card_multi_target.tres"),
	preload("res://resources/cards/card_volley.tres"),
	preload("res://resources/cards/card_zealot.tres"),
	preload("res://resources/cards/card_overload.tres"),
	preload("res://resources/cards/card_echo.tres"),
	preload("res://resources/cards/card_skill_barrier_droid.tres"),
	preload("res://resources/cards/card_pierce.tres"),
	preload("res://resources/cards/card_field.tres"),
	preload("res://resources/cards/card_reaper.tres"),
	preload("res://resources/cards/card_berserker.tres"),
	preload("res://resources/cards/card_pantheon.tres"),
	preload("res://resources/cards/card_key_lance.tres"),       # [키스톤] 관통 폭풍
	preload("res://resources/cards/card_key_overgrowth.tres"),  # [키스톤] 장판 군주
	preload("res://resources/cards/card_key_reaper.tres"),      # [키스톤] 처형 연쇄
	preload("res://resources/cards/card_key_overload.tres"),    # [키스톤] 원소 폭주
	preload("res://resources/cards/card_key_echo.tres"),        # [키스톤] 메아리 군주
]

func _init(player: Node) -> void:
	_player = player

## 풀에서 희귀도 가중치로 count장 중복 없이 뽑기. rare_only면 희귀+, keystone_only면 키스톤만.
func draw(count: int, rare_only: bool = false, exclude: Array = [], legendary_only: bool = false, keystone_only: bool = false) -> Array:
	var p := pool.filter(is_useful)
	if keystone_only:  # [키스톤-스파인] 키스톤만 — 런 시작에 빌드 정체성을 먼저 정하게
		p = p.filter(func(c): return c.keystone != "")
	elif legendary_only:
		var leg := p.filter(func(c): return c.rarity == "legendary")  # 갈림길 도전: 전설 확정
		if not leg.is_empty():
			p = leg  # 전설이 없으면(필터 고갈) 희귀+로 폴백
		else:
			p = p.filter(func(c): return c.rarity in ["rare", "epic", "legendary"])
	elif rare_only:
		p = p.filter(func(c): return c.rarity in ["rare", "epic", "legendary"])  # 보스 보상: 희귀+ 확정
	if not exclude.is_empty():
		var trimmed := p.filter(func(c): return not exclude.has(c))
		if not trimmed.is_empty():
			p = trimmed  # 현재 표시 중인 카드 제외(중복 회피). 비면 제외 무시(풀 고갈 방지)
	var picked: Array = []
	while picked.size() < count and not p.is_empty():
		var total := 0.0
		for c in p:
			total += _weight(c)
		var r := randf() * total
		for c in p:
			r -= _weight(c)
			if r <= 0.0:
				picked.append(c)
				p.erase(c)
				break
	return picked

## 현재 빌드에서 의미 있는 카드인지 — 죽은 픽(조건 미충족 시너지 등)을 드래프트에서 제외
func is_useful(card: CardData) -> bool:
	if card.keystone != "":  # [키스톤] 이미 보유한 키스톤은 드래프트에서 제외(중복 방지)
		var b = _player.build
		if card.keystone == "pierce_chain" and b.keystone_pierce_chain: return false
		if card.keystone == "persist_field" and b.keystone_persist_field: return false
		if card.keystone == "execute_chain" and b.keystone_execute_chain: return false
		if card.keystone == "overload" and b.keystone_overload: return false
		if card.keystone == "echo" and b.keystone_echo: return false
		return true
	if card.grant_skill_id != "":
		var owned: bool = _has_skill(card.grant_skill_id)
		var evolvable: bool = owned and _player.can_evolve(card.grant_skill_id)
		if _player.skills.size() >= _player.MAX_SKILL_SLOTS:
			if not evolvable:
				return false  # 슬롯 가득 — 보유 중 '풀업 아닌'(업그레이드 가능한) 스킬만 노출
		elif owned and not evolvable:
			return false  # 슬롯 여유라도 이미 최고 단계인 보유 스킬은 중복(낭비) 제외
	if (card.skill_radius_bonus > 0.0 or card.grant_ground_field) and not _has_radius_skill():
		return false  # 범위 스킬(메테오/융단폭격)이 없으면 범위 강화·장판 무의미
	if card.skill_radius_bonus > 0.0 and _radius_all_capped():
		return false  # 모든 범위 스킬이 이미 범위 상한 도달 → 범위 강화 무의미(중복=낭비)
	if card.fire_rate_bonus > 0.0 and _player.fire_rate_all_capped():
		return false  # 모든 스킬이 초과연사 위력 환산 상한(+75%) 도달 → 연사 강화 무의미
	if card.execute_threshold_bonus > 0.0 and _player.build.execute_threshold > 0.0:
		return false  # 처형(수확자) 카드는 1회면 충분 — 중복 가치 미미·과도한 즉사 누적 방지
	if card.extra_targets_bonus > 0 and not _has_count_skill():
		return false  # 표적형 스킬이 없으면 다발 무의미
	if card.pierce_bonus > 0 and not _has_bolts_skill():
		return false  # 마력탄 스킬이 없으면 관통 무의미(발사체 전용)
	if card.heal > 0.0 and _player.hp >= _player.max_hp:
		return false  # 만피에 회복 카드 금지
	if card.max_hp_bonus < 0.0 and _player.max_hp + card.max_hp_bonus < 30.0:
		return false  # 트레이드오프로 체력이 너무 낮아지면 제외
	# (v1.89) 부여형 카드(화염/서리 각인·메아리·장판)는 중복 시 누적(레벨↑) → 더는 제외하지 않음.
	return true

## 드로우 가중치 = 희귀도 가중치 × 빌드 시너지 × (스탯 강등) × (키스톤 보강)
func _weight(card: CardData) -> float:
	if card.keystone != "":
		return 6.0 * _synergy(card)  # [키스톤] 검증 슬라이스 — 자주 등장(추후 희귀하게 튜닝)
	var w: float = RARITY_WEIGHT.get(card.rarity, 3.0) * _synergy(card)
	if is_pure_stat(card):
		w *= 0.15  # [키스톤-스파인] 순수 스탯카드 대폭 강등 — 빌드의 주인공은 키스톤, 스탯은 조연
	w *= _keystone_affinity(card)  # 보유 키스톤을 보강하는 카드면 자주 등장(런이 첫 선택을 중심으로 흐르게)
	return w

## [스마트 자동픽] 후보 중 '가장 좋은' 카드 = 희귀도↑·빌드 시너지·키스톤 우선. (드로우 가중치 _weight와 반대 방향:
## _weight는 등장 확률이라 흔할수록 높지만, 여기선 가치가 높을수록 큰 값.) 자동선택이 무작위 대신 이걸 고른다.
func best_pick(cards: Array) -> CardData:
	var best: CardData = null
	var best_v := -1.0
	for c in cards:
		var v := pick_value(c)
		if v > best_v:
			best_v = v; best = c
	return best

## 카드 가치 점수(자동픽용) — 희귀도 등급 + 키스톤 최우선 + 빌드 시너지·키스톤 강화 반영.
func pick_value(card: CardData) -> float:
	var rank := {"legendary": 5.0, "epic": 4.0, "rare": 3.0, "uncommon": 2.0, "common": 1.0}
	var v: float = rank.get(card.rarity, 1.0)
	if card.keystone != "":
		v += 10.0  # 키스톤은 빌드 정체성 — 제시되면 최우선 픽
	v *= _synergy(card)            # 스킬·속성 시너지
	v *= _keystone_affinity(card)  # 보유 키스톤을 강화하는 카드 우대
	return v

## 순수 스탯 카드 = 키스톤·스킬·행동·원소·표적 효과 없이 숫자(공/연사/방/체력)만 올리는 카드.
## 키스톤-스파인 실험에서 이런 카드는 "제일 큰 숫자 줍기"의 원흉 → 대폭 강등 대상.
func is_pure_stat(card: CardData) -> bool:
	if card.keystone != "" or card.grant_skill_id != "" or card.heal > 0.0:
		return false
	# 빌드를 가르는 효과가 하나라도 있으면 순수 스탯이 아님
	if card.skill_power_bonus != 0.0 or card.skill_radius_bonus != 0.0: return false
	if card.explode_power_bonus != 0.0 or card.extra_targets_bonus != 0: return false
	if card.projectile_count_bonus != 0 or card.damage_per_target_bonus != 0.0: return false
	if card.pierce_bonus != 0 or card.knockback_bonus != 0.0: return false
	if card.grant_burn or card.grant_slow or card.grant_echo or card.grant_ground_field: return false
	if card.detonate_burn_bonus != 0.0 or card.frostbite_bonus != 0.0 or card.execute_threshold_bonus != 0.0: return false
	return true  # 남은 효과는 damage/fire_rate/defense/max_hp 뿐 → 순수 스탯

## 보유 키스톤을 강화하는 카드면 가중치 배율↑ (런이 첫 선택을 중심으로 흐르게).
func _keystone_affinity(card: CardData) -> float:
	var b = _player.build
	var m := 1.0
	if b.keystone_pierce_chain:  # 관통 폭풍 = 관통·다중표적·평타 위력 보강
		if card.pierce_bonus > 0 or card.projectile_count_bonus > 0 or card.extra_targets_bonus > 0:
			m *= 4.0
		elif card.damage_bonus > 0.0:
			m *= 2.0  # 평타 스케일은 관통 빌드 핵심(순수스탯 강등을 일부 상쇄)
	if b.keystone_persist_field:  # 장판 군주 = 장판·범위·폭발 보강
		if card.grant_ground_field or card.skill_radius_bonus > 0.0 or card.explode_power_bonus > 0.0:
			m *= 4.0
	if b.keystone_execute_chain:  # 처형 연쇄 = 처형·폭발 보강
		if card.execute_threshold_bonus > 0.0 or card.explode_power_bonus > 0.0:
			m *= 4.0
	if b.keystone_overload:  # 원소 폭주 = 화상·둔화·격발·파쇄 보강
		if card.grant_burn or card.grant_slow or card.detonate_burn_bonus > 0.0 or card.frostbite_bonus > 0.0:
			m *= 4.0
	if b.keystone_echo:  # 메아리 군주 = 스킬 위력·스킬 획득 보강
		if card.skill_power_bonus > 0.0 or card.grant_skill_id != "":
			m *= 3.0
	return m

## 드래프트 가중치 — 어피니티 기반. 앵커 심화(전문화) vs 반응 콤보 상대(다른 속성)로 분기.
## (쓸모없는 카드는 is_useful이 이미 제외하므로 여기선 '얼마나 잘 맞는가'만 가산)
func _synergy(card: CardData) -> float:
	var pl = _player
	var m := 1.0
	var skills_n: int = pl.skills.size()
	# 최고 어피니티 속성(현재 주력)
	var top := ""
	var top_v := 0.0
	for e in pl.build.affinity:
		if float(pl.build.affinity[e]) > top_v:
			top_v = float(pl.build.affinity[e]); top = e
	# 스킬 카드: 그 스킬 속성으로 전문화/콤보 판정
	if card.grant_skill_id != "":
		var ce: String = SkillLib.DEFS.get(card.grant_skill_id, {}).get("element", "")
		if ce != "" and top != "":
			if ce == top:
				m *= 1.8  # 전문화 심화(앵커 속성)
			elif ElementLib.REACTION_PARTNER.get(top, []).has(ce):
				m *= 1.6  # 반응 콤보 상대(증발 등 — 극)
			else:
				m *= 1.2  # 그 외 분기
		if _has_skill(card.grant_skill_id) and pl.can_evolve(card.grant_skill_id):
			m *= 1.5  # 진화 임박 마무리
		elif skills_n < 3:
			m *= 1.3
	# 스킬 스케일·행동 카드 — 보유 스킬 많을수록 가치↑
	if card.skill_power_bonus > 0.0:
		m *= 1.0 + 0.25 * skills_n
	if card.skill_radius_bonus > 0.0 or card.extra_targets_bonus > 0 or card.pierce_bonus > 0:
		m *= 1.4
	return m

# --- 스킬 보유/상한 조회 (드래프트 유용성 판정 전용) ---

func _has_radius_skill() -> bool:
	for s in _player.skills:
		if s.radius > 0.0:
			return true
	return false

## 보유한 모든 범위 스킬이 이미 범위 상한(MAX_SKILL_RADIUS)에 도달했나 — 그러면 범위 카드는 무의미.
func _radius_all_capped() -> bool:
	var mult: float = _player.build.skill_radius_mult
	var found := false
	for s in _player.skills:
		if s.radius > 0.0:
			found = true
			if s.radius * mult < _player.MAX_SKILL_RADIUS:
				return false  # 아직 상한 미달 범위 스킬 존재 → 범위 카드 유효
	return found  # 범위 스킬이 있고 전부 상한이면 true(=범위 강화 무의미)

## 보유 스킬 중 표적형(마력탄·융단·체인 — count 사용) 스킬이 있나
func _has_count_skill() -> bool:
	for s in _player.skills:
		if s.id in ["bolts", "barrage", "chain", "shrapnel"]:
			return true
	return false

## 마력탄(발사체) 스킬을 보유했나 — 관통 카드 유효성 (관통은 발사체에만 적용)
func _has_bolts_skill() -> bool:
	for s in _player.skills:
		if s.id == "bolts":
			return true
	return false

## 해당 스킬을 이미 보유했나 (스킬 슬롯 필터용)
func _has_skill(id: String) -> bool:
	for s in _player.skills:
		if s.id == id:
			return true
	return false
