extends Node2D
## 도감 '이펙트 보기' — 스킬 연출을 중심점에서 반복 재생(데미지·타겟팅 없는 시각 전용 미리보기).
## 실제 전투 FX 씬을 그대로 재사용 → 인게임과 동일한 룩. (확장: 스킬별 시그니처를 _play_once의 match에 추가)

const SKILL_RING := preload("res://scenes/fx/skill_ring.gd")
const DEATH_BURST := preload("res://scenes/fx/death_burst.tscn")
const PIXEL_FX := preload("res://scenes/fx/pixel_fx.gd")
const FX_EXPLOSION_FIRE := preload("res://assets/sprites/fx_explosion_fire.png")
const FX_EXPLOSION_EXT := preload("res://assets/sprites/fx_ext_explosion.png")  # 불바다: 외부 CC0 팩(비교용)
const FALLING_SKILL := preload("res://scenes/fx/falling_skill.gd")
const THORN_ERUPT := preload("res://scenes/fx/thorn_erupt.gd")
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
		"inferno":  # 외부 CC0 팩 폭발(유성=절차 생성과 비교)
			_ring(col)
			var xfx = PIXEL_FX.new()
			add_child(xfx)
			xfx.play(FX_EXPLOSION_EXT, 10, _radius * 2.2, 60.0, Color.WHITE, 5)
		"barrage", "rockfall":
			_falling(col, _elem, false)   # 바위 낙하 → 폭발 링
		"thorns":
			_burst(col); _ring(col)
			var th = THORN_ERUPT.new(); add_child(th); th.setup(_radius)
		_:
			_ring(col); _burst(col)        # 공통: 속성별 링 버스트 + 파편

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
		_ring(col)
		_burst(col)
		if pixel:
			var fx = PIXEL_FX.new()
			add_child(fx)
			fx.play(FX_EXPLOSION_FIRE, 9, _radius * 2.2, 26.0)
		if is_instance_valid(m):
			m.queue_free())
