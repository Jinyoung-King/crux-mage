extends Node2D
## 방어형 비행체(Void Barrier Droid) — 마법사 주위를 공전(orbit)하며 적탄(enemy_bolts)을 소멸시키고
## 공전 반경 안의 적에게 지속 피해(tick)를 준다. 고정형 마법사의 탄막 통제·근접 그라인드·생존 보조.
## 지속형 동반자(persistent companion): 쿨다운 캐스트가 아니라 매 프레임 동작 — player._sync_barrier_droid가 생성/갱신.
##
## Performance considerations:
##  - 적탄 소멸은 매 프레임(탄막 통제 목적). enemy_bolts 그룹 1회 순회 × 드론 수(보통 2~5). 화면 탄이 줄어 전체 부하↓.
##  - 적 지속 피해는 TICK_INTERVAL 주기로만 enemies 그룹을 순회(매 프레임 아님)해 O(N) 탐색 빈도를 낮춘다.
##  - 드론 위치는 공전각 _angle 하나로 파생(노드 N개를 따로 두지 않음) — 할당/노드 비용 0.

const BLOCK_POP := preload("res://scenes/fx/block_pop.gd")  ## 적탄 차단 보호막 링(직관적 표시)
const FX_METAL := preload("res://assets/sprites/fx_metal.png")  ## 드론 외형 — 외부 금속 스프라이트(DevWizard Magic Sparks, CC0)
const CLEAR_RADIUS := 28.0   ## 드론이 적탄을 소멸시키는 근접 반경(px)
const TICK_INTERVAL := 0.4   ## 적 지속 피해 주기(s)
const TICK_RADIUS := 60.0    ## 드론 주변 피해 반경(px) — 적이 더 잘 닿도록 확대(v2.4)
const DPS_FACTOR := 0.6      ## tick 피해 = build.damage × DPS_FACTOR × (power/10) × skill_power_mult — 빌드·스킬위력 비례

var _player
var _count: int = 2
var _radius: float = 95.0
var _ang_speed: float = 2.0   ## 공전 각속도(rad/s)
var _power: float = 10.0
var _col: Color = Color(0.7, 0.85, 1.0)
var _angle: float = 0.0
var _tick_t: float = 0.0
var _t: float = 0.0  ## 글로우 펄스용 누적 시간

func _ready() -> void:
	z_index = 6  # 적·발사체 위에 그려지도록
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 외부 픽셀 시트 선명하게

## 보유 스킬 사전(s)으로 비행체 파라미터 갱신 — 획득/진화 시 player가 호출. 티어↑ → 공전 가속.
func configure(player_ref, s: Dictionary) -> void:
	_player = player_ref
	var tier: int = int(s.get("tier", 1))
	_count = maxi(1, int(s.get("count", 2)))
	_radius = float(s.get("radius", 95.0))
	_power = float(s.get("power", 10.0))
	_ang_speed = 2.0 + 0.25 * float(tier - 1)
	if _player and _player.character:
		_col = ElementLib.color(_player.character.element)
	queue_redraw()

## i번째 드론의 로컬 오프셋(공전 좌표). 전역 좌표 = global_position + 오프셋.
func _drone_offset(i: int) -> Vector2:
	var a: float = _angle + TAU * float(i) / float(_count)
	return Vector2(cos(a), sin(a)) * _radius

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _player.hp <= 0.0:
		return
	_angle = fposmod(_angle + _ang_speed * delta, TAU)
	_t += delta
	queue_redraw()
	_clear_enemy_bolts()       # 탄막 통제(매 프레임)
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = TICK_INTERVAL
		_damage_enemies()

## 드론 근접의 적탄을 소멸(상쇄). 오브젝트 풀 도입 전까지 queue_free로 수명 종료(3단계에서 풀 반환으로 교체 예정).
func _clear_enemy_bolts() -> void:
	for b in get_tree().get_nodes_in_group("enemy_bolts"):
		if not is_instance_valid(b):
			continue
		for i in _count:
			if (global_position + _drone_offset(i)).distance_to(b.global_position) <= CLEAR_RADIUS:
				_block_fx(b.global_position)  # 막은 자리에 차단 스파크
				b.queue_free()
				break

## 적탄을 막은 위치에 청색 보호막 링(직관적 차단 표시 — '막혔다'가 한눈에)
func _block_fx(pos: Vector2) -> void:
	var pop = BLOCK_POP.new()
	get_tree().current_scene.add_child(pop)
	pop.global_position = pos

## 드론 반경 안의 적에게 주기당 피해(상성 적용). build.damage × 스킬위력 비례 → 스킬 빌드 후반에도 유효.
func _damage_enemies() -> void:
	# v2.4: skill_power_mult 반영 — 스킬 위력 카드·특성(주문력)·유물 투자가 비행체에도 적용(다른 스킬과 동일).
	var per_tick: float = _player.build.damage * DPS_FACTOR * (_power / 10.0) * _player.build.skill_power_mult * TICK_INTERVAL
	if per_tick <= 0.0:
		return
	var elem: String = _player.character.element if _player.character else ""
	for e in EnemyCache.all():
		if not is_instance_valid(e) or e.hp <= 0.0:
			continue
		for i in _count:
			if (global_position + _drone_offset(i)).distance_to(e.global_position) <= TICK_RADIUS:
				e.take_damage(per_tick * ElementLib.multiplier(elem, e.element))
				break

func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(_col.r, _col.g, _col.b, 0.10), 1.5, true)  # 공전 궤도(은은)
	# 드론 본체 — 외부 금속 스프라이트(시트의 한 프레임)
	var fw := FX_METAL.get_width() / 6.0    # 프레임 폭(96/6=16)
	var fh := float(FX_METAL.get_height())   # 16
	var src := Rect2(2.0 * fw, 0.0, fw, fh)  # 형성된 금속 프레임(고정)
	var dsz := 30.0                          # 화면상 드론 크기
	for i in _count:
		var off := _drone_offset(i)
		draw_texture_rect_region(FX_METAL, Rect2(off - Vector2(dsz, dsz) * 0.5, Vector2(dsz, dsz)), src)
