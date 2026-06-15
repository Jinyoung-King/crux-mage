extends Area2D
## 위에서 스폰되어 아래(플레이어 쪽)로 직진하는 적.

signal died(pos: Vector2, color: Color, size: float, tex: Texture2D, coins: int, kind: String)
signal reached_player(contact_damage: float, pos: Vector2)
signal summon(data: EnemyData, count: int, pos: Vector2)
signal ranged_attack(damage: float, from_pos: Vector2, count: int, spread_deg: float, bolt_scale: float)
signal charge_hit(damage: float)  ## 보스 돌진이 플레이어에 닿을 때

const ELEMENT_AURA := preload("res://scenes/fx/element_aura.gd")  ## 속성 표시 오라
const HUGE_PCT_RESIST := 0.2  ## 거대(보스)는 %체력 피해를 이 비율로만 받음(보스전 트리비얼화 방지)

@export var max_hp: float = 30.0
@export var speed: float = 60.0  ## 이동 속도(px/s)
@export var contact_damage: float = 10.0  ## 플레이어 도달 시 입히는 피해

var hp: float
var goal_y: float = 2000.0  ## 이 y까지 내려오면 플레이어에 도달 (스폰 시 main이 설정)
var effect_color := Color(0.85, 0.25, 0.25)  ## 사망 파편 색 (setup에서 지정)
var body_size := 36.0  ## 파편 양 계산용 (setup에서 지정)
# 패턴 상태 (setup에서 지정)
var zigzag_amplitude := 0.0
var zigzag_period := 2.0
var split_count := 0
var split_enemy: EnemyData
var base_x := 0.0  ## 지그재그 기준 x
var zig_t := 0.0
# 상태이상 (패시브) — StatusEffects 컴포넌트에 위임. 외부는 apply_burn/apply_slow/is_burning 등으로 접근.
var status := StatusEffects.new()
var _tint := Color.WHITE  ## 상태 색조 (화상/둔화)
var _flashing := false    ## 피격 플래시 중에는 색조 덮어쓰기 보류
var sprite_scale := 3.0   ## 스프라이트 표시 배율 (size/텍스처폭, 등장 연출이 참조)
# HP바 (중간보스·보스 전용)
const HP_BAR_W := 60.0
var hp_fill: ColorRect
# 특수공격 (중간보스·보스): 텔레그래프 + 탄막 + 돌진 (setup에서 지정)
var display_name := ""
var telegraph_time := 0.0
var _telegraphing := false  ## 예고 중에는 색조 덮어쓰기 보류
enum Charge { NONE, DIVING, RETURNING }
var charge_state := Charge.NONE
var charge_speed := 0.0
var charge_damage := 0.0
var charge_home_y := 0.0  ## 돌진 시작 y(복귀 목표)
# 보호막 (수호 마왕): 활성 시 플레이어 탄을 hp 대신 흡수
var shield_duration := 0.0
var shield_heal := 0.0
var shield_active := false
var shield_hp_cur := 0.0
var shield_hp_max := 0.0
var shield_time_left := 0.0
var shield_node: ColorRect
# 엘리트 수식어 (무한 모드 잡몹): 처치 시 줄 코인
var coin_value := 1
var dmg_scale := 1.0  ## 무한 모드 피해 배율 (접촉·탄막·돌진에 적용)
var element := ""  ## 오행 속성 (발사체 상성 판정용)
var kind_key := ""  ## 적 종류 키(.tres 파일명) — 도감 처치 집계용
var attack_range := 0.0  ## 원거리 사거리(기지까지 세로 거리). 0=무제한
var is_huge := false  ## 거대 타입(보스·중간보스) — 넉백 면역
# 광폭화(보스): 체력이 enrage_below 이하로 떨어지면 1회 광폭(속도·공격↑ + 붉게)
var enrage_below := 0.0
var enrage_speed_mult := 1.6
var enrage_attack_mult := 1.5
var _enraged := false

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	base_x = position.x
	# 등장 팝인 연출 (최종 배율 sprite_scale로 튀어오름)
	$Sprite2D.scale = Vector2(sprite_scale * 0.4, sprite_scale * 0.4)
	create_tween().tween_property($Sprite2D, "scale", Vector2(sprite_scale, sprite_scale), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 스폰 시 적 종류 데이터 적용 (add_child 전에 호출할 것)
## hp_scale: 무한 모드 체력 배율
func setup(data: EnemyData, hp_scale: float = 1.0, dscale: float = 1.0, elite: Dictionary = {}) -> void:
	dmg_scale = dscale
	max_hp = data.hp * hp_scale
	speed = data.speed
	contact_damage = data.contact_damage
	effect_color = data.effect_color
	body_size = data.size
	coin_value = data.coin_value  # 데이터 기반 코인 (엘리트면 아래에서 덮어씀)
	element = data.element  # 오행 속성 (상성)
	kind_key = data.resource_path.get_file().get_basename()  # 도감 집계 키
	zigzag_amplitude = data.zigzag_amplitude
	zigzag_period = data.zigzag_period
	split_count = data.split_count
	split_enemy = data.split_enemy
	if data.summon_interval > 0.0:
		var t := Timer.new()
		t.wait_time = data.summon_interval
		t.autostart = true  # 트리 진입 시 자동 시작
		t.timeout.connect(_on_summon_timer.bind(data))
		add_child(t)
	display_name = data.display_name
	telegraph_time = data.telegraph_time
	if data.attack_interval > 0.0:
		attack_range = data.attack_range
		var at := Timer.new()
		at.wait_time = data.attack_interval
		at.autostart = true
		at.timeout.connect(_on_ranged_timer.bind(data))
		add_child(at)
	if data.charge_interval > 0.0:
		charge_speed = data.charge_speed
		charge_damage = data.charge_damage * dmg_scale
		var ct := Timer.new()
		ct.wait_time = data.charge_interval
		ct.autostart = true
		ct.timeout.connect(_on_charge_timer)
		add_child(ct)
	if data.shield_interval > 0.0:
		shield_hp_max = data.shield_hp * hp_scale  # 보호막도 무한 스케일과 함께 커짐
		shield_duration = data.shield_duration
		shield_heal = data.shield_heal
		var st := Timer.new()
		st.wait_time = data.shield_interval
		st.autostart = true
		st.timeout.connect(_on_shield_timer)
		add_child(st)
	enrage_below = data.enrage_below
	enrage_speed_mult = data.enrage_speed_mult
	enrage_attack_mult = data.enrage_attack_mult
	# 엘리트 수식어(무한 모드 잡몹): 스탯 배수·보너스 코인·색 (main이 결정해 전달)
	if not elite.is_empty():
		coin_value = elite.get("coins", 1)
		max_hp *= elite.get("hp_mul", 1.0)
		speed *= elite.get("speed_mul", 1.0)
		contact_damage *= elite.get("contact_mul", 1.0)
		body_size *= elite.get("size_mul", 1.0)
		effect_color = elite.get("color", effect_color)
	contact_damage *= dmg_scale  # 무한 모드 피해 상승 (흡혈로 스테이지가 안 끝나는 현상 방지)
	$Sprite2D.texture = data.sprite
	# 표시 배율 = 크기/텍스처폭 (엘리트 거대 수식어면 body_size가 커져 함께 확대)
	sprite_scale = body_size / float(data.sprite.get_width())
	$Sprite2D.scale = Vector2(sprite_scale, sprite_scale)
	# 충돌 모양은 인스턴스 간 공유되므로 새로 만들어 크기 적용
	var shape := RectangleShape2D.new()
	shape.size = Vector2(body_size, body_size)
	$CollisionShape2D.shape = shape
	if element != "":
		_build_element_ring()  # 속성 색 테두리(상성 식별)
	is_huge = data.show_hp_bar  # 거대 타입(보스·중간보스)
	if data.show_hp_bar:
		_build_hp_bar(body_size)
	if not elite.is_empty():
		_build_elite_aura(elite.get("color", Color.WHITE))

## 머리 위 HP바 생성 (중간보스·보스). 스프라이트 위에 그려지도록 마지막에 add.
func _build_hp_bar(enemy_size: float) -> void:
	var top := -enemy_size / 2.0 - 16.0
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(HP_BAR_W + 4.0, 10.0)
	bg.position = Vector2(-(HP_BAR_W + 4.0) / 2.0, top - 2.0)
	add_child(bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.9, 0.2, 0.2)
	hp_fill.size = Vector2(HP_BAR_W, 6.0)
	hp_fill.position = Vector2(-HP_BAR_W / 2.0, top)
	add_child(hp_fill)

## 속성 색 테두리: 본체 뒤에 속성 색 사각을 본체보다 크게 깔아 가장자리가 속성 색으로 보이게(상성 식별).
## $Sprite2D.modulate(피격 플래시·화상/둔화 색조)와 무관하게 항상 속성 색을 유지한다.
func _build_element_ring() -> void:
	var aura := ELEMENT_AURA.new()
	# 오행별 외곽 모양: 불=삼각·물=원·나무=오각·쇠=마름모(4각)·흙=육각
	var sides: int = {"fire": 3, "water": 0, "wood": 5, "metal": 4, "earth": 6}.get(element, 0)
	aura.setup(ElementLib.color(element), sides, body_size * 0.72)
	add_child(aura)
	move_child(aura, 0)  # 본체 스프라이트 뒤에 그려지도록

## 엘리트 오라: 몹 스프라이트의 '모양'(알파)만 빌려 수식어 색의 단색 실루엣을 만들고,
## 8방향으로 살짝 밀어 본체 뒤에 깔아 몹을 감싸는 빛나는 외곽선을 만든다(은은한 맥동).
func _build_elite_aura(color: Color) -> void:
	# 텍스처 RGB는 버리고 알파(모양)만 써서 단색으로 칠하는 셰이더 (모듈레이트는 빨강을 청록으로 못 바꿈)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform vec4 aura : source_color = vec4(1.0);\nvoid fragment() {\n\tCOLOR = vec4(aura.rgb, aura.a * COLOR.a * texture(TEXTURE, UV).a);\n}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("aura", color)
	var aura := Node2D.new()
	var off := maxf(5.0, body_size * 0.13)
	var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1, 1).normalized(), Vector2(1, -1).normalized(),
		Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized()]
	for d in dirs:
		var ghost := Sprite2D.new()
		ghost.texture = $Sprite2D.texture
		ghost.scale = $Sprite2D.scale
		ghost.texture_filter = $Sprite2D.texture_filter
		ghost.material = mat  # 8장이 같은 색 → 머티리얼 공유
		ghost.position = d * off
		aura.add_child(ghost)
	aura.modulate.a = 0.75  # 전체 투명도(맥동이 조절)
	add_child(aura)
	move_child(aura, 0)  # 본체 스프라이트 뒤에 그려지도록 맨 앞 인덱스로
	# 은은한 맥동 (노드에 묶인 트윈 → 적이 죽으면 자동 종료)
	var tw := aura.create_tween().set_loops()
	tw.tween_property(aura, "modulate:a", 0.95, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(aura, "modulate:a", 0.5, 0.55).set_trans(Tween.TRANS_SINE)

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return  # 이미 사망/도달 처리된 적
	# 화상 도트 (패시브) — 컴포넌트가 타이머 관리, 이번 프레임 피해만 반환
	var burn_dmg := status.tick_burn(delta)
	if burn_dmg > 0.0:
		hp -= burn_dmg
		if hp <= 0.0:
			_die()
			return
	if enrage_below > 0.0 and not _enraged and hp <= max_hp * enrage_below:
		_enrage()  # 저체력 광폭(보스)
	# 보호막 지속시간: 시간 내 안 깨지면 회복하고 해제 (버스트 못 넣으면 처치 지연)
	if shield_active:
		shield_time_left -= delta
		if shield_time_left <= 0.0:
			_resolve_shield_survived()
	# 돌진 중에는 일반 하강·도달 판정을 건너뛰고 돌진 이동만 처리
	if charge_state != Charge.NONE:
		_process_charge(delta)
		_update_visuals()
		return
	# 둔화 적용 이동 (컴포넌트가 둔화 타이머 관리)
	var spd := status.apply_move(delta, speed)
	position.y += spd * delta
	if zigzag_amplitude > 0.0:
		zig_t += delta
		position.x = clampf(base_x + sin(zig_t * TAU / zigzag_period) * zigzag_amplitude, 30.0, 690.0)
	_update_visuals()
	if position.y >= goal_y:
		hp = 0.0  # 도달한 적은 이후 피격/사망 처리에서 제외
		reached_player.emit(contact_damage, global_position)
		queue_free()

## 상태 색조(피격 플래시·예고 중이 아닐 때만) + HP바 갱신 — 일반 이동·돌진 공통
func _update_visuals() -> void:
	_update_tint()
	if not _flashing and not _telegraphing:
		$Sprite2D.modulate = _tint
	if hp_fill:
		hp_fill.size.x = HP_BAR_W * maxf(hp / max_hp, 0.0)

## 돌진 이동: 아래로 내려가 goal_y에 닿으면 피해를 주고 복귀
func _process_charge(delta: float) -> void:
	if charge_state == Charge.DIVING:
		position.y += charge_speed * delta
		if position.y >= goal_y:
			position.y = goal_y
			charge_hit.emit(charge_damage)
			charge_state = Charge.RETURNING
	elif charge_state == Charge.RETURNING:
		position.y -= charge_speed * delta
		if position.y <= charge_home_y:
			position.y = charge_home_y
			charge_state = Charge.NONE

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return  # 같은 프레임에 여러 발 맞았을 때 중복 사망 처리 방지
	_flash()
	# 보호막 활성 시: 탄을 hp 대신 보호막이 먼저 흡수, 깨지면 초과분만 본체로
	if shield_active:
		shield_hp_cur -= amount
		if shield_hp_cur > 0.0:
			_update_shield_visual()
			return
		amount = -shield_hp_cur  # 초과 피해
		_break_shield()
	hp -= amount
	if hp <= 0.0:
		_die()

## 최대(또는 현재) 체력 비례 절대 피해 — 복리로 두꺼워진 적을 확정적으로 깎는다(anti-tank, 복리 관통).
## 거대(보스) 타입은 HUGE_PCT_RESIST로 크게 감쇠해 보스전이 무의미해지지 않게 한다.
## @param pct 0~1 비율 / @param of_max true=최대체력 기준(기본), false=현재체력 기준
## Performance: take_damage 1회만 호출(추가 노드/탐색 없음) — O(1).
func take_percent_damage(pct: float, of_max: bool = true) -> void:
	if hp <= 0.0 or pct <= 0.0:
		return
	var amt: float = (max_hp if of_max else hp) * pct
	if is_huge:
		amt *= HUGE_PCT_RESIST
	take_damage(amt)

## 상태이상 위임 래퍼 — 외부 호출부(main·relic·projectile·freeze)는 그대로 enemy를 통해 접근
func apply_burn(dps: float, dur: float) -> void:
	status.apply_burn(dps, dur)

func apply_slow(factor: float, dur: float) -> void:
	status.apply_slow(factor, dur)

func is_burning() -> bool:
	return status.is_burning()

func is_slowed() -> bool:
	return status.is_slowed()

## 화상 소모(격발: 기폭)
func consume_burn() -> void:
	status.consume_burn()

## 저체력 광폭(보스): 속도·접촉/탄막 피해 강화 + 붉은 기 + 잠깐 부풀어오르는 연출. 1회만.
func _enrage() -> void:
	_enraged = true
	speed *= enrage_speed_mult
	contact_damage *= enrage_attack_mult
	dmg_scale *= enrage_attack_mult  # 탄막 피해(data.attack_damage × dmg_scale)도 강화
	modulate = Color(1.4, 0.85, 0.85)  # 노드 전체에 붉은 기(스프라이트 상태 색조와 곱)
	var tw := create_tween()
	tw.tween_property($Sprite2D, "scale", Vector2(sprite_scale * 1.25, sprite_scale * 1.25), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property($Sprite2D, "scale", Vector2(sprite_scale, sprite_scale), 0.2)

## 사망 처리 (피격사·화상사 공통)
func _die() -> void:
	# 분열: 처치로 죽을 때만 (도달로 빠지면 분열 없음). died보다 먼저 emit해야
	# 마지막 적이 분열할 때 웨이브 클리어가 새끼 생성 전에 판정되는 것을 막는다.
	if split_count > 0 and split_enemy != null:
		summon.emit(split_enemy, split_count, global_position)
	died.emit(global_position, effect_color, body_size, $Sprite2D.texture, coin_value, kind_key)
	queue_free()

func _on_summon_timer(data: EnemyData) -> void:
	if hp > 0.0:
		summon.emit(data.summon_enemy, data.summon_count, global_position)

## 원거리 공격 타이머: 예고가 있으면 예고 후 발사, 없으면 즉시 발사(마술사)
func _on_ranged_timer(data: EnemyData) -> void:
	if hp <= 0.0 or _busy():
		return  # 사망/예고·돌진 진행 중이면 이번 발사는 건너뜀
	if not _in_attack_range():
		return  # 화면 밖(위) 또는 사거리 밖이면 발사 안 함
	if telegraph_time > 0.0:
		_telegraph(_emit_barrage.bind(data))
	else:
		_emit_barrage(data)

## 마탄 발사(단발 또는 부채꼴). main이 시그널을 받아 실제 마탄을 생성
func _emit_barrage(data: EnemyData) -> void:
	if hp <= 0.0:
		return
	ranged_attack.emit(data.attack_damage * dmg_scale, global_position, data.attack_count, data.attack_spread_deg, data.attack_bolt_scale)

## 돌진 타이머: 예고 후 돌진 시작(예고·돌진 진행 중이면 건너뜀)
func _on_charge_timer() -> void:
	if hp <= 0.0 or _busy():
		return
	_telegraph(_start_dive)

func _start_dive() -> void:
	if hp <= 0.0:
		return
	charge_home_y = position.y
	charge_state = Charge.DIVING

## 특수공격 예고: telegraph_time 동안 붉게 번쩍·움찔한 뒤 then 실행.
## 타이밍은 노드에 묶인 트윈의 finished로 — 적이 예고 중 죽으면 트윈이 자동 종료돼 then이 불리지 않음.
func _telegraph(then: Callable) -> void:
	_telegraphing = true
	var warn := Color(2.6, 1.3, 1.3)
	var half := telegraph_time / 2.0
	var blink := create_tween().set_loops(2)  # 색 깜빡(연출)
	blink.tween_property($Sprite2D, "modulate", warn, half * 0.5)
	blink.tween_property($Sprite2D, "modulate", _tint, half * 0.5)
	var pulse := sprite_scale * 1.18
	var flinch := create_tween()  # 움찔(부풀었다 복귀) — 이 트윈의 finished로 타이밍 제어
	flinch.tween_property($Sprite2D, "scale", Vector2(pulse, pulse), half).set_trans(Tween.TRANS_SINE)
	flinch.tween_property($Sprite2D, "scale", Vector2(sprite_scale, sprite_scale), half).set_trans(Tween.TRANS_SINE)
	flinch.finished.connect(func():
		_telegraphing = false
		if hp > 0.0:
			then.call())

## 예고·돌진이 진행 중이면 다른 특수공격을 시작하지 않도록
func _busy() -> bool:
	return _telegraphing or charge_state != Charge.NONE

## 원거리 발사 가능 여부: 화면 안에 충분히 들어왔고(상단 밖 제외) + 사거리(기지까지 세로) 이내
func _in_attack_range() -> bool:
	if global_position.y < 40.0:
		return false  # 화면 밖(위) 또는 진입 직후엔 발사 안 함
	if attack_range > 0.0 and (goal_y - global_position.y) > attack_range:
		return false  # 사거리 밖(기지에서 너무 멀리 위)
	return true

## 보호막 타이머: 예고 후 보호막 전개 (예고·돌진 중이거나 이미 보호막이 있으면 건너뜀)
func _on_shield_timer() -> void:
	if hp <= 0.0 or _busy() or shield_active:
		return
	_telegraph(_raise_shield)

func _raise_shield() -> void:
	if hp <= 0.0:
		return
	shield_active = true
	shield_hp_cur = shield_hp_max
	shield_time_left = shield_duration
	var s := body_size * 1.5
	shield_node = ColorRect.new()
	shield_node.color = Color(0.3, 0.8, 1.0, 0.45)
	shield_node.size = Vector2(s, s)
	shield_node.position = Vector2(-s / 2.0, -s / 2.0)
	shield_node.pivot_offset = Vector2(s / 2.0, s / 2.0)
	shield_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shield_node)
	# 팝인 (노드에 묶인 트윈이라 보호막이 곧 깨져도 안전)
	shield_node.scale = Vector2(0.6, 0.6)
	shield_node.create_tween().tween_property(shield_node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 보호막이 시간 내 격파됨 — 본체 노출
func _break_shield() -> void:
	shield_active = false
	if shield_node:
		shield_node.queue_free()
		shield_node = null

## 보호막이 시간 내 안 깨짐 — 회복하고 해제 (버스트 실패 시 압박)
func _resolve_shield_survived() -> void:
	shield_active = false
	if shield_node:
		shield_node.queue_free()
		shield_node = null
	hp = minf(hp + shield_heal, max_hp)

## 보호막 잔량에 따라 투명도 갱신 (탄을 맞을수록 옅어짐)
func _update_shield_visual() -> void:
	if shield_node and shield_hp_max > 0.0:
		var frac := clampf(shield_hp_cur / shield_hp_max, 0.0, 1.0)
		shield_node.color.a = 0.15 + 0.35 * frac

## 상태이상에 따른 색조: 화상=주황 끼, 둔화=푸른 끼, 둘 다면 혼합
func _update_tint() -> void:
	var c := Color.WHITE
	if status.is_burning():
		c *= Color(1.5, 0.7, 0.45)
	if status.is_slowed():
		c *= Color(0.6, 0.8, 1.4)
	_tint = c

## 피격 플래시: 밝게 번쩍였다가 현재 상태 색조로 복귀
func _flash() -> void:
	_flashing = true
	$Sprite2D.modulate = Color(3.0, 3.0, 3.0)
	var tw := create_tween()
	tw.tween_property($Sprite2D, "modulate", _tint, 0.12)
	tw.finished.connect(func(): _flashing = false)
