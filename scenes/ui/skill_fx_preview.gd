extends Node2D
## 도감 '이펙트 보기' — 스킬 연출을 중심점에서 반복 재생(데미지·타겟팅 없는 시각 전용 미리보기).
## 실제 전투 FX 씬을 그대로 재사용 → 인게임과 동일한 룩. (확장: 스킬별 시그니처를 _play_once의 match에 추가)

const SKILL_RING := preload("res://scenes/fx/skill_ring.gd")
const DEATH_BURST := preload("res://scenes/fx/death_burst.tscn")
const PIXEL_FX := preload("res://scenes/fx/pixel_fx.gd")
const FX_EXPLOSION_EXT := preload("res://assets/sprites/fx_cm_explosion.png")  # 폭발(외부 CC0 — CodeManu, 8x8=64프레임) — 유성·불바다 공용. 이펙트 통일(2026-06-18)
const FALLING_SKILL := preload("res://scenes/fx/falling_skill.gd")
const THORN_ERUPT := preload("res://scenes/fx/thorn_erupt.gd")
const FX_WATER := preload("res://assets/sprites/fx_cm_water.png")  # 물(빙하·서리) — CodeManu 19_freezing, CC0, 10x10=100프레임. 이펙트 통일(2026-06-18)
const FX_WOOD := preload("res://assets/sprites/thorn_arrow.png")    # 가시 화살 발사체 미리보기 — 날카로운 화살(단일 프레임)
const FX_CM_WOOD := preload("res://assets/sprites/fx_cm_wood.png")  # 가시밭 AoE — CodeManu 17_felspell, CC0, 10x10=100프레임. 이펙트 통일(2026-06-18)
const KNIFE := preload("res://assets/sprites/knife.png")  # 비도 — 날아가는 칼
const LOOP := 1.7  ## 반복 주기(초)

var _id := ""
var _elem := ""
var _radius := 80.0
var _t := 0.0

func setup(id: String, def: Dictionary) -> void:
	_id = id
	_elem = str(def.get("element", ""))
	_radius = maxf(float(def.get("radius", 0.0)), 72.0)  # 반경0 스킬도 보이게 하한
	_t = LOOP  # 진입 즉시 1회 재생

func _process(delta: float) -> void:
	_t += delta
	if _t >= LOOP:
		_t = 0.0
		_play_once()

func _play_once() -> void:
	var col: Color = ElementLib.color(_elem)
	match _id:
		"meteor":
			_falling(col, "fire", true)   # 운석 낙하 → 픽셀 폭발(절차 생성)
		"inferno":  # 외부 픽셀 폭발
			var xfx = PIXEL_FX.new()
			add_child(xfx)
			xfx.play(FX_EXPLOSION_EXT, 8, _radius * 2.2, 60.0, Color.WHITE, 8)
		"barrage", "rockfall":
			_falling(col, _elem, true)    # 바위 낙하 → 외부 폭발(폭격 임팩트)
		"chain":  # 비도 — 날아가는 칼이 적에서 적으로 튕기며 강철 궤적
			var pts := [Vector2(0, -10), Vector2(72, -52), Vector2(-52, 30)]
			var blade := Sprite2D.new()
			blade.texture = KNIFE
			blade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			blade.scale = Vector2(2.6, 2.6)
			blade.position = Vector2(0, 130)
			add_child(blade)
			var ctw := blade.create_tween()
			var prev := Vector2(0, 130)
			for pt in pts:
				var sf: Vector2 = prev
				var st: Vector2 = pt
				ctw.tween_callback(_face_blade.bind(blade, sf, st))
				ctw.tween_property(blade, "position", st, 0.08)
				ctw.tween_callback(_slash.bind(sf, st))
				prev = pt
			ctw.tween_callback(blade.queue_free)
		"glacier":  # 외부 물 FX(DevWizard CC0)
			var gfx = PIXEL_FX.new(); add_child(gfx); gfx.play(FX_WATER, 10, _radius * 2.0, 60.0, Color.WHITE, 10)
		"freeze":  # 외부 물 FX(중앙 대형)
			var ffx = PIXEL_FX.new(); add_child(ffx); ffx.play(FX_WATER, 10, 200.0, 60.0, Color.WHITE, 10)
		"thorns":  # 가시 솟구침 + 외부 자연 FX
			var th = THORN_ERUPT.new(); add_child(th); th.setup(_radius)
			var nfx = PIXEL_FX.new(); add_child(nfx); nfx.play(FX_CM_WOOD, 10, _radius * 1.4, 60.0, Color.WHITE, 10)
		"bolts":  # 가시 화살 — 외부 식물 발사체가 날아가는 모습(인게임 렌더와 동일)
			_projectiles()
		_:
			_burst(col)        # 공통: 파편(원형 링 제거)

## 가시 화살 발사체 미리보기 — 인게임 fire_skill_bolt와 동일 스프라이트/회전으로 부채꼴 발사(아래→위)
func _projectiles() -> void:
	var n := 3
	for i in n:
		var spr := Sprite2D.new()
		spr.texture = FX_WOOD
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(2.4, 2.4)
		var start := Vector2((i - (n - 1) / 2.0) * 26.0, 150.0)
		var target := Vector2((i - (n - 1) / 2.0) * 90.0, -160.0)
		spr.position = start
		spr.rotation = (target - start).angle()  # 인게임과 동일(회전 보정 없음 — 도감에서 방향 확인 가능)
		add_child(spr)
		var tw := spr.create_tween()
		tw.tween_property(spr, "position", target, 0.5)
		tw.tween_callback(func() -> void:
			if is_instance_valid(spr):
				spr.queue_free())

func _ring(col: Color) -> void:
	var r = SKILL_RING.new()
	add_child(r)
	r.setup(_radius, col, _elem)

func _burst(col: Color) -> void:
	var b = DEATH_BURST.instantiate()
	b.color = col
	b.amount = 44
	b.lifetime = 0.85
	add_child(b)

## 하늘에서 낙하 → 도달 시 폭발(픽셀 또는 링). 인게임 _drop_aoe와 동일한 룩.
func _falling(col: Color, elem: String, pixel: bool) -> void:
	var m = FALLING_SKILL.new()
	m.position = Vector2(0, -320)
	add_child(m)
	m.setup(col, 44.0, elem)
	var tw := m.create_tween()
	tw.tween_property(m, "position", Vector2.ZERO, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_burst(col)
		if pixel:
			var fx = PIXEL_FX.new()
			add_child(fx)
			fx.play(FX_EXPLOSION_EXT, 8, _radius * 2.2, 60.0, Color.WHITE, 8)  # 유성도 외부 폭발로 통일(인게임 일치)
		if is_instance_valid(m):
			m.queue_free())

## 비도 연쇄 칼날 궤적(강철 2겹, 잔광 후 자멸) — 미리보기 전용
func _slash(from: Vector2, to: Vector2) -> void:
	for spec in [[6.0, Color(0.62, 0.66, 0.78, 0.4)], [2.6, Color(0.95, 0.97, 1.0, 0.98)]]:
		var ln := Line2D.new()
		ln.points = PackedVector2Array([from, to])
		ln.width = spec[0]
		ln.default_color = spec[1]
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(ln)
		var t := ln.create_tween()
		t.tween_property(ln, "modulate:a", 0.0, 0.4)
		t.tween_callback(ln.queue_free)

func _face_blade(blade, from: Vector2, to: Vector2) -> void:
	if is_instance_valid(blade):
		blade.rotation = (to - from).angle()
