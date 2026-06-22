# 원소 어피니티 — 검증 슬라이스 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** "전문화 vs 생콤보 vs 극콤보" 선택이 재밌는지 검증할 최소 슬라이스 — 어피니티(투자→위력·반응↑) + 빌드 정체성 표시 + 오행 드래프트 갈림길 + 불 FX 진화.

**Architecture:** 마법사 속성=앵커. `build.affinity{속성:값}`을 장착 스킬+캐릭터로 계산(빌드 변경 훅 `rebuild_hit_modifiers`에서 재계산). `eff_power`가 기존 `element_empower`(균열)와 affinity를 합산해 그 속성 스킬 위력↑. 반응(증발·빙결파쇄) 강도도 반응 속성 affinity로 스케일. 빌드 패널에 어피니티 막대+아키타입 라벨, 드래프트는 오행 기반 가중. 불 스킬 FX는 화 affinity 티어로 단계 확대.

**Tech Stack:** Godot 4.6.3, GDScript. 테스트 프레임워크 없음 → 헤드리스 검증(임시 오토로드/print, 검증 후 제거). 최종 재미 판정은 사용자 플레이테스트(체감).

## Global Constraints
- 응답·코드 주석 한국어. 변경 후 `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after N --path .`로 검증.
- 폰트 미지원 기호(⚔·⟡·⚡) 금지 — UI엔 텍스트/지원 기호(▶·★·●·▮)만.
- GPU 파티클·셰이더 금지. FX는 거버너 tier·MAX_FX 예산 내.
- `affinity`는 `element_empower`(균열)와 **별도 dict** — eff_power에서 합산(균열 보너스 안 깨지게).
- 게임플레이 의도 변경(밸런스) 포함. 동작 보존 아님(`_card_synergy` 재작성).
- 성공 판정 = 사용자 플레이테스트("전문화/생콤보/극콤보가 고민되나, FX 진화가 보이나"). 헤드리스는 *작동*만 검증.

---

## File Structure
- `data/build_state.gd` — `affinity: Dictionary` 필드 추가.
- `scenes/player/player.gd` — 어피니티 상수·`recompute_affinity()`·`rebuild_hit_modifiers`에서 호출·`eff_power`에 affinity 합산·아키타입 헬퍼.
- `scenes/combat/skill_executor.gd` — 증발·빙결파쇄 강도를 반응 속성 affinity로 스케일·불 FX를 화 affinity 티어로 확대.
- `scenes/main/main.gd` — `cards_panel`에 어피니티 막대+아키타입 라벨, `_card_synergy` 오행 기반 재작성, 드래프트 카드 미리보기에 속성 태그.

---

## Phase 1 — 어피니티 코어

### Task 1: affinity 필드 + 계산 + eff_power 합산

**Files:**
- Modify: `data/build_state.gd`
- Modify: `scenes/player/player.gd` (상수, `recompute_affinity`, `rebuild_hit_modifiers`, `eff_power`)

**Interfaces:**
- Produces: `build.affinity: Dictionary` ({element:float}), `Player.recompute_affinity() -> void`, `Player.ANCHOR_AFFINITY`/`PER_SKILL_AFFINITY` 상수. eff_power가 affinity 반영.

- [ ] **Step 1: build_state에 affinity 필드 추가**

`data/build_state.gd`의 `element_empower` 선언 아래에 추가:
```gdscript
var affinity: Dictionary = {}  ## [어피니티] {속성:값} — 장착 스킬+앵커로 계산. eff_power·반응 강도·FX 티어에 반영
```

- [ ] **Step 2: player에 어피니티 상수 + 계산 함수 추가**

`scenes/player/player.gd` 상단 상수 영역에:
```gdscript
const ANCHOR_AFFINITY := 0.30   ## 마법사 속성(앵커) 기본 어피니티
const PER_SKILL_AFFINITY := 0.20  ## 장착 스킬 1개당 그 속성 어피니티 가산
```
그리고 함수 추가(아무 곳, 예: `rebuild_hit_modifiers` 위):
```gdscript
## [어피니티] 장착 스킬+앵커로 affinity 재계산. 빌드 변경 시(rebuild_hit_modifiers) 호출.
func recompute_affinity() -> void:
	build.affinity.clear()
	if character:
		build.affinity[character.element] = ANCHOR_AFFINITY
	for s in skills:
		var e: String = SkillLib.DEFS.get(s.id, {}).get("element", "")
		if e != "":
			build.affinity[e] = float(build.affinity.get(e, 0.0)) + PER_SKILL_AFFINITY
```

- [ ] **Step 3: rebuild_hit_modifiers에서 호출**

`func rebuild_hit_modifiers() -> void:` 본문 첫 줄에 추가:
```gdscript
	recompute_affinity()
```

- [ ] **Step 4: eff_power에 affinity 합산**

`scenes/player/player.gd`의 eff_power에서 element_empower 블록을 교체:
```gdscript
	var bonus: float = float(build.element_empower.get(elem, 0.0)) + float(build.affinity.get(elem, 0.0))
	if bonus != 0.0:
		p *= 1.0 + bonus
```
(기존 `if build.element_empower.has(elem): p *= 1.0 + float(build.element_empower[elem])` 대체)

- [ ] **Step 5: 헤드리스 검증**

임시 오토로드 `test_aff.gd`(루트, 검증 후 삭제)로 화염술사(메테오) 시작 + 물 스킬 추가해 affinity 확인:
```gdscript
extends Node
func _ready():
	await get_tree().process_frame
	GameState.game_mode="endless"; GameState.start_wave=1
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	await get_tree().create_timer(1.0).timeout
	var pl = get_tree().current_scene.get_node("Player")
	print("[AFF] 시작 affinity=", pl.build.affinity)   # 앵커 속성 0.3 예상
	pl.skills.append(pl._make_skill("freeze","서리",12.0,9.0,0.0,0))
	pl.recompute_affinity()
	print("[AFF] freeze 추가 후=", pl.build.affinity)   # water 0.2 추가 예상
	var fs = pl.skills[0]
	print("[AFF] eff_power(고유스킬) affinity 반영=", pl.eff_power(fs))
	get_tree().quit()
```
등록(`project.godot` [autoload]에 `TestAff="*res://test_aff.gd"`) 후:
Run: `/opt/homebrew/bin/godot --headless --fixed-fps 60 --quit-after 200 --path . 2>&1 | grep -E "AFF|SCRIPT ERROR"`
Expected: 앵커 속성 affinity 0.3, freeze 추가 후 water=0.2(+앵커), eff_power가 affinity만큼↑. 에러 없음.

- [ ] **Step 6: 임시물 제거 + 커밋**

`rm test_aff.gd`, project.godot의 TestAff 줄 제거. 파싱 재확인.
```bash
git add data/build_state.gd scenes/player/player.gd
git commit -m "어피니티 1단계: build.affinity 계산(앵커+스킬) + eff_power 합산

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

### Task 2: 반응 강도를 affinity로 스케일

**Files:**
- Modify: `scenes/combat/skill_executor.gd` (`_apply_element_reactions` 증발·빙결파쇄)

**Interfaces:**
- Consumes: `player.build.affinity`, `_hit_ctx.dealt`.
- Produces: 증발·빙결파쇄 피해가 반응 속성 affinity에 비례.

- [ ] **Step 1: 증발·빙결파쇄에 affinity 배수 적용**

`_apply_element_reactions`의 두 분기를 수정:
```gdscript
	if element == "water" and e.is_burning():  # 증발(수극화): 화상 소모 + 광역. 물 어피니티로 강화
		var pos: Vector2 = e.global_position
		var aff: float = float(player.build.affinity.get("water", 0.0))
		e.consume_burn()
		e.take_percent_damage(REACTION_HP_PCT)
		_explode(pos, _hit_ctx.dealt * (1.5 + aff), element)
	elif element == "earth" and e.is_slowed():  # 빙결파쇄(토극수): 추가타 + 복리관통. 흙 어피니티로 강화
		var aff2: float = float(player.build.affinity.get("earth", 0.0))
		e.take_damage(_hit_ctx.dealt * (1.0 + aff2))
		if is_instance_valid(e):
			e.take_percent_damage(REACTION_HP_PCT)
```

- [ ] **Step 2: 파싱 + 발동 검증**

임시 오토로드로 물 어피니티 높은 빌드에서 증발 피해가 커지는지(affinity 0 vs 0.6 비교) print. (Task 1 패턴 재사용 — 적에 화상 부여 후 `_apply_element_reactions(e,"water")` 전후 hp 차이를 affinity 0/0.6에서 비교.)
Run: 헤드리스, `[RX]` print로 affinity↑ 시 증발 피해↑ 확인. `SCRIPT ERROR` 없음.

- [ ] **Step 3: 임시물 제거 + 커밋**
```bash
git add scenes/combat/skill_executor.gd
git commit -m "어피니티 1단계: 증발·빙결파쇄 강도를 반응 속성 affinity로 스케일

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

## Phase 2 — 빌드 정체성 표시 + 드래프트 갈림길 (검증의 핵심)

### Task 3: 어피니티 막대 + 아키타입 라벨 (빌드 패널)

**Files:**
- Modify: `scenes/player/player.gd` (아키타입 판정 헬퍼)
- Modify: `scenes/main/main.gd` (`cards_panel`/빌드 표시에 어피니티 섹션)

**Interfaces:**
- Consumes: `build.affinity`.
- Produces: `Player.archetype_label() -> String`("화염 전문화" / "화염+물 콤보" / ""), 빌드 패널의 어피니티 표시.

- [ ] **Step 1: 아키타입 라벨 헬퍼(player)**

```gdscript
## [어피니티] 현재 빌드 아키타입 라벨. 최고 어피니티 속성 = 전문화, 0.4↑ 둘 이상 = 콤보.
func archetype_label() -> String:
	var hi := ""
	var hi_v := 0.0
	var second := ""
	for e in build.affinity:
		var v: float = build.affinity[e]
		if v > hi_v:
			second = hi; hi = e; hi_v = v
		elif second == "" or v > float(build.affinity.get(second, 0.0)):
			if e != hi: second = e
	if hi == "":
		return ""
	if second != "" and float(build.affinity.get(second, 0.0)) >= 0.4:
		return "%s+%s 콤보" % [ElementLib.display_name(hi), ElementLib.display_name(second)]
	return "%s 전문화" % ElementLib.display_name(hi)
```

- [ ] **Step 2: 빌드 패널에 어피니티 막대 + 라벨 추가**

`scenes/main/main.gd`의 빌드 패널 구성부(`cards_list`에 카드 행 추가하는 곳, `_show_cards`/패널 빌드 함수)에서, 카드 목록 위에 어피니티 섹션을 넣는다. cards_list가 채워지는 함수 시작부에 추가:
```gdscript
	# [어피니티] 아키타입 + 속성별 막대
	cards_list.add_child(_section_header("빌드 — %s" % ($Player.archetype_label() if $Player.archetype_label() != "" else "미정")))
	for e in ["fire", "water", "wood", "metal", "earth"]:
		var v: float = float($Player.build.affinity.get(e, 0.0))
		if v <= 0.0:
			continue
		var bars := int(round(v / 0.2))  # 0.2당 한 칸
		cards_list.add_child(_section_sub("%s  %s  (%.0f%%)" % [ElementLib.display_name(e), "▮".repeat(bars), v * 100.0], ElementLib.color(e)))
```
(이미 있는 `_section_header`/`_section_sub` 헬퍼 재사용. 함수 위치는 cards_list 비우고 다시 채우는 곳 — 기존 패턴 따라.)

- [ ] **Step 3: 헤드리스 검증(패널 빌드 에러 없음) + 시각 스폿**

Run: 홈→플레이→빌드 패널 열기 경로 헤드리스 로드, 파싱·로드 에러 0. `archetype_label`이 빈 빌드/스킬 추가 후 올바른 문자열 반환을 print로 확인.

- [ ] **Step 4: 커밋**
```bash
git add scenes/player/player.gd scenes/main/main.gd
git commit -m "어피니티 2단계: 빌드 패널에 어피니티 막대 + 아키타입 라벨

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

### Task 4: 드래프트 갈림길 — `_card_synergy` 오행 기반 재작성

**Files:**
- Modify: `scenes/main/main.gd` (`_card_synergy`)

**Interfaces:**
- Consumes: `build.affinity`, 카드의 `grant_skill_id`(→ SkillLib.DEFS element), 오행 생/극 관계.
- Produces: 드래프트가 전문화(앵커 심화) + 생/극 콤보 상대를 의미 있게 가중.

- [ ] **Step 1: 오행 관계 상수 추가(main 또는 ElementLib)**

`scenes/main/main.gd` 상단에:
```gdscript
const SHENG := {"wood":"fire","fire":"earth","earth":"metal","metal":"water","water":"wood"}  # 상생: key가 value를 生
const KE := {"wood":"earth","earth":"water","water":"fire","fire":"metal","metal":"wood"}      # 상극: key가 value를 剋
```

- [ ] **Step 2: `_card_synergy` 재작성**

기존 `_card_synergy` 본문(제거된 카드 참조 포함)을 교체:
```gdscript
## 드래프트 가중치 — 어피니티+오행. 앵커 심화(전문화) + 생/극 콤보 상대 스킬을 선호.
func _card_synergy(card: CardData) -> float:
	var pl = $Player
	var m := 1.0
	var aff: Dictionary = pl.build.affinity
	# 최고 어피니티 속성(현재 주력)
	var top := ""
	var top_v := 0.0
	for e in aff:
		if float(aff[e]) > top_v:
			top_v = float(aff[e]); top = e
	# 스킬 카드: 그 스킬의 속성으로 전문화/콤보 판정
	if card.grant_skill_id != "":
		var ce: String = SkillLib.DEFS.get(card.grant_skill_id, {}).get("element", "")
		if ce != "" and top != "":
			if ce == top:
				m *= 1.8  # 전문화 심화
			elif ce == SHENG.get(top, "") or ce == KE.get(top, ""):
				m *= 1.6  # 생/극 콤보 상대(증폭/폭발 길)
		if _has_skill(card.grant_skill_id) and pl.can_evolve(card.grant_skill_id):
			m *= 1.5  # 진화 임박 마무리
		elif pl.skills.size() < 3:
			m *= 1.3
	# 스킬 스케일·행동 카드는 보유 스킬 많을수록 가치↑
	if card.skill_power_bonus > 0.0:
		m *= 1.0 + 0.25 * pl.skills.size()
	if card.skill_radius_bonus > 0.0 or card.extra_targets_bonus > 0 or card.pierce_bonus > 0:
		m *= 1.4
	return m
```

- [ ] **Step 3: 드래프트 카드에 속성 태그/미리보기(선택, 가벼우면 포함)**

`card_select`가 스킬 카드 속성을 이미 표시(v3.93 `_skill_style`)하므로 추가 최소. 부족하면 카드 설명에 "→ 화염 전문화 / 증발 콤보 열림" 한 줄 — 단순하면 포함, 복잡하면 별도.

- [ ] **Step 4: 헤드리스 검증 — 가중 방향**

임시 오토로드로 화 어피니티 높은 빌드에서 `_draw_cards`를 여러 번 돌려, **불 스킬·생극 상대(흙/물) 스킬이 무관 속성보다 자주 뽑히는지** 카운트.
Run: 헤드리스, `[DRAFT]` 카운트로 앵커·콤보 카드 빈도↑ 확인. 제거된 카드 참조 0(파싱 에러 없음).

- [ ] **Step 5: 커밋**
```bash
git add scenes/main/main.gd
git commit -m "어피니티 2단계: _card_synergy 오행 기반 재작성(전문화·생극 콤보 가중)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```

---

## Phase 3 — 가시적 진화 FX (불)

### Task 5: 화 affinity 티어로 불 폭발 FX 확대

**Files:**
- Modify: `scenes/combat/skill_executor.gd` (불 FX play 호출 — meteor `_drop_aoe`, inferno)

**Interfaces:**
- Consumes: `player.build.affinity["fire"]`.
- Produces: 불 affinity 티어(≥0.4/≥0.7/≥1.0 → ×1/1.25/1.5)에 따라 불 폭발 FX 크기 확대.

- [ ] **Step 1: 화 affinity 티어 헬퍼**

`skill_executor.gd`에:
```gdscript
## [어피니티] 화 affinity → FX 배율(가시적 진화). 0.4/0.7/1.0 경계.
func _fire_fx_scale() -> float:
	var a: float = float(player.build.affinity.get("fire", 0.0))
	if a >= 1.0: return 1.5
	if a >= 0.7: return 1.3
	if a >= 0.4: return 1.15
	return 1.0
```

- [ ] **Step 2: inferno·meteor 불 폭발에 배율 적용**

inferno 분기의 `xfx.play(FX_EXPLOSION_EXT, 8, er * 2.2, 60.0, Color.WHITE, 8)`를:
```gdscript
				xfx.play(FX_EXPLOSION_EXT, 8, er * 2.2 * _fire_fx_scale(), 60.0, Color.WHITE, 8)
```
그리고 `_drop_aoe`의 폭발이 불일 때만 배율(element=="fire"일 때). `_drop_aoe` 내 `fx.play(FX_EXPLOSION_EXT, 8, radius * 2.2, ...)`를:
```gdscript
				var fscale := _fire_fx_scale() if element == "fire" else 1.0
				fx.play(FX_EXPLOSION_EXT, 8, radius * 2.2 * fscale, 60.0, Color.WHITE, 8)
```

- [ ] **Step 3: 헤드리스 검증 — 티어 전환**

임시 오토로드로 화 affinity 0 / 0.7 / 1.0에서 `_fire_fx_scale()` 반환값(1.0/1.3/1.5) + 메테오 시전 시 pixel_fx 노드의 scale 차이를 print.
Run: 헤드리스, `[FXTIER]` print로 affinity↑ 시 배율↑ 확인. `SCRIPT ERROR` 없음.

- [ ] **Step 4: 임시물 제거 + 커밋 + 버전·배포**

```bash
git add scenes/combat/skill_executor.gd
git commit -m "어피니티 3단계: 화 affinity 티어로 불 폭발 FX 확대(가시적 진화)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01LLGW4otvFtWFeiGMmUiXQX"
```
그 후 `GameState.VERSION` 올리고 패치노트 추가 + 웹 빌드·푸시(자동 배포) → **사용자 폰 플레이테스트로 재미 판정**.

---

## Self-Review (작성자 체크)

**스펙 커버리지:**
- §3.1 어피니티 코어(앵커+스킬, element_empower 합산, 반응 스케일) → Task 1·2 ✓
- §3.3 빌드 정체성 표시 → Task 3 ✓
- §3.4 드래프트 갈림길(오행 가중, _card_synergy 재작성) → Task 4 ✓
- §3.2 가시적 진화 FX(불) → Task 5 ✓
- §4 제외(궁극기·5속성FX·진화재편) → 계획에 없음 ✓
- §5 성공=플레이테스트 → Task 5 끝 명시 ✓

**플레이스홀더 스캔:** Task 3 Step 2의 "함수 위치는 기존 패턴 따라", Task 4 Step 3의 "단순하면 포함"은 구현 재량 여지(코드는 제시). 그 외 모든 코드 단계 실제 GDScript 제시. 수치(0.3/0.2/티어 0.4·0.7·1.0/배율)는 튜닝 기본값.

**타입 일관성:** `build.affinity`(Dictionary), `recompute_affinity()`, `archetype_label()`, `_fire_fx_scale()`, `SHENG`/`KE`, `ANCHOR_AFFINITY`/`PER_SKILL_AFFINITY` — 정의(Task1·3·4·5)와 사용 일치. `SkillLib.DEFS[id].element`·`ElementLib.color/display_name`·`_section_header`/`_section_sub`·`_make_skill`·`can_evolve`·`_has_skill`은 기존 실존 심볼.

**주의(실행 시):**
- Task 3 Step 2는 빌드 패널이 "cards_list를 비우고 다시 채우는" 정확한 함수를 찾아 그 시작부에 삽입(실행자가 `_show_cards`류 확인).
- `affinity`와 `element_empower`(균열) 합산이 eff_power에서 정상인지(이중적용 아님) 확인.
- 반응 스케일·FX 배율은 헤드리스로 *작동*만; 밸런스·체감은 플레이테스트.

## 다음 (검증 통과 시, 별도 계획)
궁극기 변신(전문화/콤보 캡스톤) · 5속성 FX 진화 · 기존 진화(EVOLVE_BRANCHES) 어피니티 구동 재편 · 금극목(금속 반응 복원). 설계 스펙: `docs/superpowers/specs/2026-06-22-element-affinity-design.md`
