class_name HitModifierLib
extends RefCounted
## 적중 효과 전략(Strategy) 라이브러리.
## 각 모디파이어는 '한 가지' 동적 효과만 책임(SRP)지며, on_pre_damage/on_hit/on_kill 3단계 훅으로
## SkillExecutor의 명중 파이프라인에 끼어든다. 신규 행동(유도·분열 등) 추가 = 클래스 1개 + build_for 1줄.
##
## 성능(Performance): 모디파이어는 build_for로 카드/유물 획득 시 1회만 생성(매 적중 할당 없음).
## 활성 효과만 목록에 담아 핫패스 반복 횟수를 줄이고, 수치는 p.build에서 실시간 조회해
## (값이 바뀌어도 재생성 불필요) 재구성 빈도를 낮춘다. GDScript엔 인터페이스가 없어 가상 메서드로 에뮬레이트.

## 추상 베이스(Abstract Base) — 모든 모디파이어의 공통 계약(contract)
class Base extends RefCounted:
	var p  ## 플레이어 참조(효과 수치 실시간 조회)
	func _init(player) -> void:
		p = player
	func on_pre_damage(_ctx) -> void: pass  ## 피해 산정 전 배율 가감(격노·치명)
	func on_hit(_ctx) -> void: pass         ## 피해 적용 후 적 생존 시(상태 부여·격발)
	func on_kill(_ctx) -> void: pass        ## 이 명중으로 처치 시(처치 폭발)

## 격노의 룬(유물): 저체력 시 피해 증폭
class Berserk extends Base:
	func on_pre_damage(ctx) -> void:
		if p.hp < p.max_hp * RelicLib.BERSERK_HP_RATIO:
			ctx.damage *= RelicLib.berserk_mult(p.relic_levels["berserk"])

## 치명타(캐릭터 패시브): 확률적 피해 배수
class Crit extends Base:
	func on_pre_damage(ctx) -> void:
		if randf() < p.character.passive_crit_chance:
			ctx.damage *= p.character.passive_crit_mult
			ctx.is_crit = true

## 파쇄(Frostbite): 둔화/빙결 적에게 추가 일격
class Frostbite extends Base:
	func on_hit(ctx) -> void:
		if ctx.was_slowed:
			ctx.enemy.take_damage(ctx.dealt * p.build.frostbite)

## 기폭(Detonate): 화상 적 명중 시 화상을 소모하고 광역 폭발
class Detonate extends Base:
	func on_hit(ctx) -> void:
		if ctx.was_burning:
			ctx.enemy.consume_burn()
			ctx.executor._explode(ctx.pos, ctx.dealt * p.build.detonate_burn, ctx.element)

## 부여: 화상(카드)
class ApplyBurn extends Base:
	func on_hit(ctx) -> void:
		ctx.enemy.apply_burn(RelicLib.RELIC_BURN_DPS, RelicLib.RELIC_BURN_DUR)

## 부여: 둔화(카드)
class ApplySlow extends Base:
	func on_hit(ctx) -> void:
		ctx.enemy.apply_slow(0.6, 2.0)

## 점화의 룬(유물): 명중 시 레벨별 화상
class Ignite extends Base:
	func on_hit(ctx) -> void:
		ctx.enemy.apply_burn(RelicLib.burn_dps(p.relic_levels["ignite"]), RelicLib.RELIC_BURN_DUR)

## 즉사(수확): 체력 임계 이하 적 처형(빌드·유물 중 큰 임계 적용)
class Execute extends Base:
	func on_hit(ctx) -> void:
		var thr: float = p.build.execute_threshold
		if p.relic_levels.has("execute"):
			thr = maxf(thr, RelicLib.execute_threshold(p.relic_levels["execute"]))
		if thr > 0.0 and ctx.enemy.hp <= ctx.enemy.max_hp * thr:
			ctx.enemy.take_damage(ctx.enemy.hp)

## 넉백: 기지에서 밀어냄(거대 타입 면역). 처형 등으로 이미 죽었으면 건너뜀.
class Knockback extends Base:
	func on_hit(ctx) -> void:
		var e = ctx.enemy
		if p.build.knockback > 0.0 and is_instance_valid(e) and e.hp > 0.0 and not e.is_huge:
			e.position.y -= p.build.knockback

## 처치 폭발: 이 명중으로 죽으면 주변 광역(직접 피해라 재귀 폭주 없음)
class Explode extends Base:
	func on_kill(ctx) -> void:
		ctx.executor._explode(ctx.pos, ctx.dealt * p.build.explode_power, ctx.element)

## 플레이어의 현재 빌드/유물/캐릭터로 활성 모디파이어 목록을 '기존 _skill_hit 분기 순서대로' 구성.
## (순서가 동작 보존의 핵심 — 격노→치명 / 파쇄→기폭→화상→둔화→점화→즉사→넉백 / 처치폭발)
static func build_for(p) -> Array:
	var mods: Array = []
	if p.relic_levels.has("berserk"): mods.append(Berserk.new(p))
	if p.character and p.character.passive_crit_chance > 0.0: mods.append(Crit.new(p))
	if p.build.frostbite > 0.0: mods.append(Frostbite.new(p))
	if p.build.detonate_burn > 0.0: mods.append(Detonate.new(p))
	if p.build.apply_burn: mods.append(ApplyBurn.new(p))
	if p.build.apply_slow: mods.append(ApplySlow.new(p))
	if p.relic_levels.has("ignite"): mods.append(Ignite.new(p))
	if p.build.execute_threshold > 0.0 or p.relic_levels.has("execute"): mods.append(Execute.new(p))
	if p.build.knockback > 0.0: mods.append(Knockback.new(p))
	if p.build.explode_power > 0.0: mods.append(Explode.new(p))
	return mods
