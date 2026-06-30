class_name BuildPanel
extends RefCounted
## 인게임 '내 빌드/내 카드' 뷰 — HUD '내 카드' 버튼 + 일시정지 패널(빌드 요약·스킬 수치·획득 카드 목록).
## main.gd에서 분리. 카드 획득 이력(_picked_*)도 여기서 보유(뷰의 주 소비자라서) — main 흐름은 record()로 적립,
## 결과 화면은 total_count()/kind_count()로 조회. host(main) 노드를 받아 $HUD에 UI를 짓고 $Player를 참조한다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const RARITY_COLORS := {
	"legendary": Color(1.0, 0.62, 0.32), "epic": Color(0.8, 0.52, 1.0), "rare": Color(1.0, 0.84, 0.4),
	"uncommon": Color(0.56, 0.86, 0.55), "common": Color(0.62, 0.72, 0.88),
}
const RARITY_BADGE := {"legendary": "전설", "epic": "영웅", "rare": "희귀", "uncommon": "고급", "common": "일반"}

var _host: Node     # main (get_tree·game_over 접근)
var _hud: Node      # $HUD (UI 부모)
var _player: Node   # $Player (빌드·스킬 조회)

# 카드 획득 이력(이번 런 '내 카드' 목록용 모델)
var _picked_count: Dictionary = {}   # {카드이름: 획득 횟수}
var _picked_rarity: Dictionary = {}  # {카드이름: rarity}
var _picked_order: Array = []        # 처음 획득한 순서(표시 순서)

# 패널 노드 참조
var cards_button: Button             # HUD '내 카드' 버튼
var cards_panel: Control             # 획득 카드 패널(스크롤)
var cards_list: VBoxContainer        # 카드 행 컨테이너
var cards_count_label: Label         # "총 N장 · M종"

## 카드 획득 1건 기록 (이번 런 '내 카드' 리스트용)
func record(card) -> void:
	var nm: String = card.card_name
	if not _picked_count.has(nm):
		_picked_order.append(nm)
		_picked_rarity[nm] = card.rarity
	_picked_count[nm] = int(_picked_count.get(nm, 0)) + 1

## [이어하기] 카드 획득 이력 직렬화/복원 — 런 스냅샷에 포함.
func snapshot_history() -> Dictionary:
	return {"count": _picked_count.duplicate(true), "order": _picked_order.duplicate(true), "rarity": _picked_rarity.duplicate(true)}

func restore_history(d: Dictionary) -> void:
	_picked_count = (d.get("count", {}) as Dictionary).duplicate(true)
	_picked_order = (d.get("order", []) as Array).duplicate(true)
	_picked_rarity = (d.get("rarity", {}) as Dictionary).duplicate(true)

## 결과 화면용 — 총 획득 장수
func total_count() -> int:
	var total := 0
	for v in _picked_count.values():
		total += int(v)
	return total

## 결과 화면용 — 획득 종류 수
func kind_count() -> int:
	return _picked_order.size()

## 패널이 열려 있나 (입력 게이트용)
func is_open() -> bool:
	return cards_panel.visible

## '내 카드' 버튼 + 스크롤 패널을 코드로 구성 (host의 $HUD에 추가)
func build(host: Node) -> void:
	_host = host
	_hud = host.get_node("HUD")
	_player = host.get_node("Player")
	cards_button = Button.new()
	cards_button.text = "내 카드"
	cards_button.add_theme_font_override("font", FONT)
	cards_button.add_theme_font_size_override("font_size", 22)
	cards_button.anchor_left = 1.0
	cards_button.anchor_right = 1.0
	cards_button.grow_horizontal = 0
	cards_button.offset_left = -126.0
	cards_button.offset_top = 120.0
	cards_button.offset_right = -16.0
	cards_button.offset_bottom = 164.0
	_hud.add_child(cards_button)
	cards_button.pressed.connect(open)

	cards_panel = Control.new()
	cards_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # 정지 중에도 동작
	cards_panel.visible = false
	cards_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(cards_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	cards_panel.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -290.0
	panel.offset_right = 290.0
	panel.offset_top = -430.0
	panel.offset_bottom = 430.0
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.12, 0.11, 0.16, 0.98)
	pstyle.set_corner_radius_all(14)
	pstyle.set_content_margin_all(20)
	pstyle.set_border_width_all(2)
	pstyle.border_color = Color(0.4, 0.4, 0.5)
	panel.add_theme_stylebox_override("panel", pstyle)
	cards_panel.add_child(panel)

	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 12)
	panel.add_child(center)
	var title := Label.new()
	title.text = "내 빌드"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 36)
	center.add_child(title)
	cards_count_label = Label.new()
	cards_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_count_label.add_theme_font_override("font", FONT)
	cards_count_label.add_theme_font_size_override("font_size", 18)
	cards_count_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	center.add_child(cards_count_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(520, 600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(scroll)
	cards_list = VBoxContainer.new()
	cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_list.add_theme_constant_override("separation", 6)
	scroll.add_child(cards_list)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(220, 54)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 24)
	UIKit.style_button(close, Color(0.55, 0.62, 0.78))  # 내 빌드 패널 닫기 버튼 통일
	close.pressed.connect(_close)
	center.add_child(close)

## 획득 카드 패널 열기 (현재까지 고른 카드 리스트 갱신 후 표시·일시정지)
func open() -> void:
	if cards_panel.visible:  # 이미 열려 있으면 무시(중복 방지) — 드래프트 중에도 열람 허용
		return
	for ch in cards_list.get_children():
		ch.queue_free()
	# [어피니티] 빌드 아키타입 + 속성별 막대 — "내 빌드가 무엇인지" 한눈에
	var arch: String = _player.archetype_label()
	cards_list.add_child(_section_header("빌드 — %s" % (arch if arch != "" else "미정")))
	for ae in ["fire", "water", "wood", "metal", "earth"]:
		var av: float = float(_player.build.affinity.get(ae, 0.0))
		if av <= 0.0:
			continue
		var bars: int = int(round(av / 0.2))
		cards_list.add_child(_section_sub("%s  %s  (%d%%)" % [ElementLib.display_name(ae), "▮".repeat(bars), int(round(av * 100.0))], ElementLib.color(ae)))
	# 보유 스킬 — 실효 수치(피해·쿨·사거리·대상). 스킬 수치는 여기 말고는 볼 곳이 없어 정리해 보여줌.
	if not _player.skills.is_empty():
		cards_list.add_child(_section_header("보유 스킬"))
		var elem: String = _player.character.element
		cards_list.add_child(_section_sub("%s 속성으로 적중 — 극하면 ×1.5 / 당하면 ×0.7" % ElementLib.display_name(elem), ElementLib.color(elem)))
		cards_list.add_child(_section_sub("연사·쿨이 최대치에 닿으면 초과분은 위력으로 전환 — 아래 '연사+N%' 표시", Color(0.7, 0.85, 1.0)))
		for s in _player.skills:
			cards_list.add_child(_skill_stat_row(s))
		cards_list.add_child(_section_header("획득 카드"))
	var total := 0
	# 등급별 분류: 높은 등급(전설→일반) 순으로 묶고, 같은 등급 안에서는 획득 순. 등급 바뀌면 구분 헤더.
	var rank := {"legendary": 4, "epic": 3, "rare": 2, "uncommon": 1, "common": 0}
	var order: Array = _picked_order.duplicate()
	order.sort_custom(func(a, b):
		var ra: int = rank.get(_picked_rarity.get(a, "common"), 0)
		var rb: int = rank.get(_picked_rarity.get(b, "common"), 0)
		if ra != rb:
			return ra > rb
		return _picked_order.find(a) < _picked_order.find(b))
	var cur_rarity := ""
	for nm in order:
		var r: String = _picked_rarity.get(nm, "common")
		if r != cur_rarity:
			cur_rarity = r
			cards_list.add_child(_section_sub(RARITY_BADGE.get(r, "일반"), RARITY_COLORS.get(r, Color.WHITE)))
		var cnt: int = _picked_count[nm]
		total += cnt
		cards_list.add_child(_card_row(nm, cnt, r))
	if _picked_order.is_empty():
		var empty := _label("아직 획득한 카드가 없습니다", 20, Color(0.7, 0.7, 0.75))
		cards_list.add_child(empty)
	cards_count_label.text = "총 %d장 · %d종" % [total, _picked_order.size()]
	cards_panel.show()
	_host.get_tree().paused = true

## 공통 라벨 — 공용 UIKit.label에 위임(로컬 단축 별칭)
func _label(text: String, size: int, color: Color) -> Label:
	return UIKit.label(text, size, color)

## 섹션 헤더(금색) — '내 카드' 패널 안 구분용
func _section_header(text: String) -> Label:
	var l := _label(text, 22, Color(1.0, 0.86, 0.4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 스크롤 입력 방해 금지
	return l

## 섹션 부제(작은 안내 줄)
func _section_sub(text: String, color: Color) -> Label:
	var l := _label(text, 15, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 보유 스킬 한 줄: 이름[티어] + 실효 수치(피해·쿨·사거리·대상/범위)
func _skill_stat_row(s: Dictionary) -> Label:
	var pl = _player
	if s.id == "barrier_droid":  # 지속형 동반자 — 캐스트 수치(피해/쿨/사거리)가 무의미
		return _build_stat_label("%s\n   비행체 %d기 · 적탄 소멸 · 평타 보조 사격" % [s.name, int(s.get("count", 2))])
	var dmg := int(round(pl.eff_power(s)))
	var cd: float = pl.eff_cooldown(s)
	var rng := int(SkillLib.SKILL_RANGE.get(s.id, 0))
	var cnt := int(s.get("count", 0))
	var ext: int = pl.build.extra_targets  # 다발: 표적형 스킬 추가 표적(실제 시전에 반영됨 → 표시도 합산)
	var eff_cnt := cnt + ext
	var rad := int(round(pl.eff_radius(s)))
	# 융단폭격(v1.66~)은 단일 거대 돌 — count·다발은 폭발 반경으로 환산(executor와 동일 식)
	var barrage_r := int(minf(pl.eff_radius(s) * (1.4 + 0.1 * float(maxi(eff_cnt - 3, 0))), pl.MAX_SKILL_RADIUS))
	var shape := ""
	match s.id:
		"bolts":   shape = "가까운 %d명%s" % [eff_cnt, ("(+다발%d)" % ext) if ext > 0 else ""]
		"chain":   shape = "%d명 연쇄%s" % [eff_cnt, ("(+다발%d)" % ext) if ext > 0 else ""]
		"barrage": shape = "거대 돌·반경 %d" % barrage_r
		"meteor":  shape = "반경 %d 광역" % rad
		"freeze":  shape = "전체 둔화"
		"thorns":  shape = "반경 %d 장판" % rad
		_:         shape = ("%d발" % eff_cnt) if cnt > 0 else (("반경 %d" % rad) if rad > 0 else "광역")
	var tier := int(s.get("tier", 1))
	var name_txt: String = s.name + ("  [%d티어]" % tier if tier > 1 else "")
	var fov: float = pl.fire_overflow_mult(s)
	var fr_note: String = ("  · 연사+%d%%" % int(round((fov - 1.0) * 100.0))) if fov > 1.005 else ""
	return _build_stat_label("%s\n   피해 %s · 쿨 %.1f초 · 사거리 %d · %s%s" % [name_txt, NumFmt.compact(dmg), cd, rng, shape, fr_note])

## 보유 스킬 행 라벨(공통 스타일)
func _build_stat_label(text: String) -> Label:
	var l := _label(text, 17, Color(0.9, 0.92, 0.98))
	l.custom_minimum_size = Vector2(500, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 카드 한 줄: [희귀도 뱃지] 이름 ··· ×횟수 (희귀도 색)
func _card_row(nm: String, cnt: int, rar: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(500, 0)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 스크롤 입력 방해 금지
	var col: Color = RARITY_COLORS.get(rar, Color.WHITE)
	var badge := _label(RARITY_BADGE.get(rar, "일반"), 16, col)
	badge.custom_minimum_size = Vector2(52, 0)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var name_lbl := _label(nm, 22, col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)
	if cnt > 1:
		var cnt_lbl := _label("×%d" % cnt, 22, Color(0.95, 0.95, 1.0))
		cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cnt_lbl)
	return row

func _close() -> void:
	cards_panel.hide()
	if not _host.game_over:  # 게임오버 중엔 멈춤 유지(사망 후 빌드 회고 가능)
		_host.get_tree().paused = false

func _on_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_close()
