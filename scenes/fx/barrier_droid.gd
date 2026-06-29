extends Node2D
## 수호 비행체(Guardian Drone) — 마법사 주위를 공전(orbit)하며
##  ① 근접 반경의 적탄(enemy_bolts)을 소멸시키고(탄막 통제·방어 정체성)
##  ② 가까운 적에게 평타 보조 사격을 한다(마법사 평타를 거드는 소형 드론).
## 지속형 동반자(persistent companion): 쿨다운 캐스트가 아니라 매 프레임 동작 — player._sync_barrier_droid가 생성/갱신.
##
## Performance:
##  - 적탄 소멸은 매 프레임(탄막 통제). enemy_bolts 그룹 1회 순회 × 드론 수(보통 2~5).
##  - 평타 보조는 FIRE_INTERVAL 주기로만 적을 탐색(매 프레임 아님). 발사체는 host 풀/캡이 자동 제한.
##  - 드론 위치는 공전각 _angle 하나로 파생(노드 N개를 따로 두지 않음).

const BLOCK_POP := preload("res://scenes/fx/block_pop.gd")  ## 적탄 차단 보호막 링(직관적 표시)
const CLEAR_RADIUS := 28.0     ## 드론이 적탄을 소멸시키는 근접 반경(px)
const FIRE_INTERVAL := 0.7     ## 평타 보조 사격 주기(s, 드론별)

var _player
var _count: int = 2
var _radius: float = 95.0
var _ang_speed: float = 2.0   ## 공전 각속도(rad/s)
var _power: float = 10.0      ## DEFS 전달값(현재 사격은 평타 피해 비례 — 보존만)
var _col: Color = Color(0.7, 0.85, 1.0)
var _angle: float = 0.0
var _fire_t: float = 0.0
var _t: float = 0.0  ## 글로우 펄스용 누적 시간

func _ready() -> void:
	z_index = 6  # 적·발사체 위에 그려지도록

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
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = FIRE_INTERVAL
		_fire_assist()          # 평타 보조 사격(주기)

## 드론 근접의 적탄을 소멸(상쇄).
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

## 각 드론이 가장 가까운 적에게 평타 보조 사격 1발(마법사 평타를 거든다 — 약화된 평타).
func _fire_assist() -> void:
	if not is_instance_valid(_player):
		return
	for i in _count:
		var dpos := global_position + _drone_offset(i)
		var target = _nearest_enemy(dpos)
		if target != null:
			_player.fire_assist(dpos, target)

## 위치에서 가장 가까운 살아있는 적(없으면 null).
func _nearest_enemy(from: Vector2):
	var best = null
	var best_d := INF
	for e in EnemyCache.all():
		if not is_instance_valid(e) or e.hp <= 0.0:
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d; best = e
	return best

func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(1, 1, 1, 0.07), 1.5, true)  # 공전 궤도(은은한 흰빛)
	for i in _count:
		_draw_drone(_drone_offset(i))

## 하얀 소형 드론 — 흰 본체 + 좌우 로터 암 + 청색 센서(절차적 그리기, 외부 스프라이트 없음).
func _draw_drone(c: Vector2) -> void:
	var r := 7.0
	for s in [-1.0, 1.0]:  # 좌우 로터 암(드론 실루엣)
		var tip := c + Vector2(s * (r + 5.0), -r * 0.5)
		draw_line(c, tip, Color(1, 1, 1, 0.85), 2.0)
		draw_circle(tip, 2.6, Color(1, 1, 1, 0.9))   # 로터
	draw_circle(c, r + 2.0, Color(1, 1, 1, 0.22))     # 소프트 글로우
	draw_circle(c, r, Color(0.97, 0.98, 1.0, 0.97))   # 흰 본체
	draw_circle(c, r * 0.42, Color(0.3, 0.7, 1.0, 0.95))  # 중앙 청색 센서(눈)
