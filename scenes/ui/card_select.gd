extends Control
## 웨이브 클리어 후 카드 중 1장을 고르는 UI.
## 희귀도에 따라 카드 프레임이 달라진다(일반=강철 테두리 / 희귀=금테+발광).

signal card_chosen(card)
signal reroll_requested  ## 드래프트당 무료 1회 — main이 새 카드를 뽑아 refill
signal view_cards_requested  ## '내 카드 보기' — main이 획득 카드 패널을 연다

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const CARD_ICON := preload("res://scenes/fx/card_icon.gd")
const GOLD := Color(1.0, 0.84, 0.4)       ## 희귀(금)
const STEEL := Color(0.62, 0.72, 0.88)    ## 일반(강철)
const GREEN := Color(0.56, 0.86, 0.55)    ## 고급(초록)
const EPIC := Color(0.8, 0.52, 1.0)       ## 영웅(보라)
const LEGEND := Color(1.0, 0.62, 0.32)    ## 전설(주황)

const AUTO_SECS := 10.0  ## 자동선택까지 대기 시간

@onready var buttons: Array = [$Center/Cards/Card1, $Center/Cards/Card2, $Center/Cards/Card3]
@onready var reroll_button: Button = $Center/RerollButton
@onready var auto_button: Button = $Center/AutoButton
@onready var view_cards_button: Button = $Center/ViewCardsButton

var shown_cards: Array = []
var can_reroll := false
var auto_left := 0.0  ## >0이면 자동선택 카운트다운 진행 중
var picking := false  ## 선택 연출 중(중복 입력 방지)
var shop_costs: Array = []  ## 비어있지 않으면 상점 모드(카드별 코인 비용)
var shop_coins := 0          ## 상점 모드: 현재 보유 코인(구매 가능 판정)
var player                   ## main이 주입 — 보유 스킬의 다음 진화명을 카드 이름에 표시

func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
		buttons[i].mouse_entered.connect(_on_card_hover.bind(i, true))
		buttons[i].mouse_exited.connect(_on_card_hover.bind(i, false))
	reroll_button.pressed.connect(_on_reroll_pressed)
	auto_button.pressed.connect(_on_auto_pressed)
	view_cards_button.pressed.connect(func(): view_cards_requested.emit())

## 호버 시 카드가 살짝 떠오름
func _on_card_hover(i: int, on: bool) -> void:
	if picking or not buttons[i].visible:
		return
	var b: Button = buttons[i]
	b.pivot_offset = b.size / 2.0
	create_tween().tween_property(b, "scale", Vector2(1.06, 1.06) if on else Vector2.ONE, 0.1)

func _process(delta: float) -> void:
	# 드래프트가 떠 있고 자동선택이 켜져 있으면 카운트다운 → 0이면 무작위 선택
	if not (visible and GameState.auto_card and auto_left > 0.0):
		return
	auto_left -= delta
	if auto_left <= 0.0:
		pick_random()
	else:
		_update_auto_label()

## 자동선택 카운트다운 (재)시작 — 켜져 있으면 10초, 꺼져 있으면 정지
func _start_auto() -> void:
	auto_left = AUTO_SECS if GameState.auto_card else 0.0
	_update_auto_label()

func _update_auto_label() -> void:
	if GameState.auto_card:
		auto_button.text = "자동선택: 켜짐 (%d초)" % ceili(auto_left)
	else:
		auto_button.text = "자동선택: 꺼짐"

func _on_auto_pressed() -> void:
	GameState.set_auto_card(not GameState.auto_card)  # 토글 + 영속 저장
	_start_auto()

## cards(CardData 배열, 최대 3장)를 꾸며서 표시 + 리롤 1회 초기화
func open(cards: Array, costs: Array = [], coins: int = 0, title: String = "카드를 선택하세요", allow_reroll: bool = true) -> void:
	picking = false
	shop_costs = costs
	shop_coins = coins
	$Center/Title.text = title
	reroll_button.visible = allow_reroll  # 진화 분기 드래프트는 리롤 없음
	reroll_button.disabled = false
	if costs.is_empty():  # 일반 드래프트 / 진화 분기
		can_reroll = true
		reroll_button.text = "다시 뽑기 (1회)"
	else:  # 상점: 리롤 버튼 → 건너뛰기
		can_reroll = false
		reroll_button.text = "건너뛰기 (다음 웨이브)"
	_render_cards(cards)
	if not costs.is_empty():
		_apply_shop_costs()
	show()
	# 패널 팝
	var center: Control = $Center
	center.pivot_offset = center.size / 2.0
	center.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(center, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if costs.is_empty():
		_start_auto()  # 자동선택은 일반 드래프트만(상점에서 자동구매 방지)
	else:
		auto_left = 0.0
		auto_button.text = "상점 — 코인으로 구매"

## 상점 모드: 각 카드에 비용 표시 + 못 사는 카드 비활성
func _apply_shop_costs() -> void:
	for i in shown_cards.size():
		var btn: Button = buttons[i]
		var cost: int = shop_costs[i]
		var afford: bool = shop_coins >= cost
		btn.disabled = not afford
		var box := btn.get_child(0)  # _style_card가 만든 VBox
		box.add_child(_label("%d 코인" % cost, 17, Color(1.0, 0.85, 0.35) if afford else Color(0.85, 0.42, 0.42)))

## 리롤: 카드만 교체 (리롤 1회는 이미 소진된 상태로 유지)
func refill(cards: Array) -> void:
	_render_cards(cards)
	_start_auto()  # 새 카드이므로 카운트다운 재시작

## 카드 버튼 스타일링 + 순차 등장(딜링 느낌)
func _render_cards(cards: Array) -> void:
	shown_cards = cards
	for i in buttons.size():
		var btn: Button = buttons[i]
		if i < cards.size():
			_style_card(btn, cards[i])
			btn.visible = true
		else:
			btn.visible = false
	for i in cards.size():
		buttons[i].modulate = Color(1, 1, 1, 0)  # 전체 리셋(직전 선택 연출의 흐림/스케일 제거)
		buttons[i].scale = Vector2.ONE
		var t := create_tween()
		t.tween_interval(0.05 + 0.07 * i)
		t.tween_property(buttons[i], "modulate:a", 1.0, 0.18)

func _on_reroll_pressed() -> void:
	if not can_reroll:
		return
	can_reroll = false
	reroll_button.disabled = true
	reroll_button.text = "다시 뽑기 (소진)"
	reroll_requested.emit()

## 카드 한 장을 희귀도에 맞춰 꾸민다 (프레임 + 뱃지/이름/설명)
func _style_card(btn: Button, card) -> void:
	for c in btn.get_children():
		btn.remove_child(c)
		c.queue_free()
	btn.text = ""
	var rarity: String = card.rarity
	var is_skill: bool = card.grant_skill_id != ""
	var elem: String = SkillLib.DEFS.get(card.grant_skill_id, {}).get("element", "") if is_skill else ""
	var skill_framed := is_skill and elem != ""  # 속성 스킬 카드는 희귀도 대신 속성 색 프레임으로 구분
	for state in ["normal", "hover", "pressed", "focus"]:
		var hl: bool = state == "hover" or state == "pressed"
		btn.add_theme_stylebox_override(state, _skill_style(elem, hl) if skill_framed else _card_style(rarity, hl))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 14.0
	box.offset_top = 10.0
	box.offset_right = -14.0
	box.offset_bottom = -10.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)

	var tier := _tier_color(rarity)
	var icon := CARD_ICON.new()  # 카드 종류 아이콘(효과 필드에서 자동 판별)
	icon.custom_minimum_size = Vector2(48, 48) if skill_framed else Vector2(38, 38)  # 스킬 아이콘은 크게 강조
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_kind(_card_icon_kind(card))
	box.add_child(icon)
	if skill_framed:  # 스킬 카드: 속성 배지 + 속성 색 이름. 보유 중이면 진화 진행도(N/3) 표기
		var title: String = SkillLib.DEFS.get(card.grant_skill_id, {}).get("name", card.card_name)
		var tag: String = "★ 스킬"
		if _skill_owned_evolvable(card.grant_skill_id):
			tag = "★ 진화 %d/%d" % [_skill_stacks(card.grant_skill_id), player.EVOLVE_COST]
		box.add_child(_label("%s · %s속성" % [tag, ElementLib.display_name(elem)], 15, ElementLib.color(elem)))
		box.add_child(_label(title, 23, ElementLib.color(elem)))
	else:
		box.add_child(_label(_tier_badge(rarity), 15, tier))
		box.add_child(_label(card.card_name, 23, tier if rarity != "common" else Color(0.95, 0.97, 1.0)))
	var desc_text: String = _skill_detail(card.grant_skill_id) if card.grant_skill_id != "" else card.description
	var desc := _label(desc_text, 16, Color(0.82, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_constant_override("line_spacing", 5)  # 줄간격 ↑ (가독성)
	box.add_child(desc)
	btn.add_child(box)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## 그 스킬을 보유 중이고 더 진화 가능한지(진화 진행도 표기 대상)
func _skill_owned_evolvable(id: String) -> bool:
	return player != null and id != "" and player.can_evolve(id)

## 그 스킬의 현재 진화 스택 수(없으면 0)
func _skill_stacks(id: String) -> int:
	if player == null:
		return 0
	for s in player.skills:
		if s.id == id:
			return int(s.get("stacks", 0))
	return 0

## 스킬 획득 카드: SkillLib.DEFS 수치로 자세한 다줄 설명(데미지·쿨타임·특성·진화 안내)
func _skill_detail(id: String) -> String:
	var d: Dictionary = SkillLib.DEFS.get(id, {})
	if d.is_empty():
		return ""
	var lines: PackedStringArray = []
	if _skill_owned_evolvable(id):
		lines.append("진화 진행 %d/%d — 모으면 진화 분기를 선택합니다." % [_skill_stacks(id), player.EVOLVE_COST])
	else:
		lines.append("%s 스킬을 획득합니다." % d.get("name", "스킬"))
	lines.append("적에게 데미지 %d의 피해를 줍니다." % int(d.get("power", 0)))
	lines.append("%s초의 쿨타임마다 발동됩니다." % _fmt_cd(d.get("cooldown", 0.0)))
	var cnt := int(d.get("count", 0))
	var rad := int(d.get("radius", 0))
	match id:
		"bolts": lines.append("가까운 적 %d명에게 마력탄을 날립니다." % cnt)
		"chain": lines.append("최대 %d명에게 번개가 연쇄됩니다." % cnt)
		"barrage": lines.append("%d곳에 반경 %d의 폭격이 떨어집니다." % [cnt, rad])
		"meteor": lines.append("가장 밀집한 곳에 반경 %d 광역 피해." % rad)
		"freeze": lines.append("화면의 모든 적을 둔화시킵니다.")
		"thorns": lines.append("가장 밀집한 곳에 반경 %d 가시 장판(지속 피해)." % rad)
	lines.append("같은 스킬을 모으면 진화 분기를 선택합니다.")
	return "\n".join(lines)

## 쿨타임 표기: 정수면 정수로, 소수면 한 자리(4.5초 등)
func _fmt_cd(v: float) -> String:
	return str(int(v)) if v == float(int(v)) else "%.1f" % v

## 카드 효과 필드에서 아이콘 종류를 자동 판별(가장 특징적인 효과 우선)
func _card_icon_kind(card) -> String:
	if card.grant_skill_id != "":
		var e: String = SkillLib.DEFS.get(card.grant_skill_id, {}).get("element", "")
		return ("skill_" + e) if e != "" else "skill"
	if card.grant_echo:
		return "skill"
	if card.detonate_burn_bonus > 0.0 or card.explode_power_bonus > 0.0 or card.grant_ground_field:
		return "explode"
	if card.grant_burn:
		return "fire"
	if card.grant_slow or card.frostbite_bonus > 0.0:
		return "frost"
	if card.extra_targets_bonus > 0 or card.pierce_bonus > 0:
		return "multi"
	if card.skill_power_bonus > 0.0 or card.skill_radius_bonus > 0.0:
		return "power"
	if card.execute_threshold_bonus > 0.0:
		return "attack"
	if card.fire_rate_bonus > 0.0:
		return "speed"
	if card.heal > 0.0 or card.defense_bonus > 0.0 or card.max_hp_bonus > 0.0 or card.knockback_bonus > 0.0:
		return "defense"
	if card.damage_bonus > 0.0:
		return "attack"
	return ""

func _tier_color(rarity: String) -> Color:
	match rarity:
		"legendary": return LEGEND
		"epic": return EPIC
		"rare": return GOLD
		"uncommon": return GREEN
		_: return STEEL

func _tier_badge(rarity: String) -> String:
	match rarity:
		"legendary": return "★★★ 전설"
		"epic": return "★★ 영웅"
		"rare": return "★ 희귀"
		"uncommon": return "고급"
		_: return "일반"

## 희귀도별 카드 프레임 StyleBox. hl=true면 호버/눌림 강조 변형.
func _card_style(rarity: String, hl: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if rarity == "legendary":
		sb.bg_color = Color(0.36, 0.22, 0.12) if hl else Color(0.28, 0.16, 0.08)
		sb.border_color = Color(1.0, 0.78, 0.45) if hl else LEGEND
		sb.set_border_width_all(4)
		sb.shadow_color = Color(1.0, 0.6, 0.25, 0.65)  # 주황 발광
		sb.shadow_size = 20
	elif rarity == "epic":
		sb.bg_color = Color(0.30, 0.16, 0.36) if hl else Color(0.23, 0.12, 0.30)
		sb.border_color = Color(0.95, 0.75, 1.0) if hl else EPIC
		sb.set_border_width_all(4)
		sb.shadow_color = Color(0.8, 0.45, 1.0, 0.6)  # 보랏빛 발광
		sb.shadow_size = 16
	elif rarity == "rare":
		sb.bg_color = Color(0.30, 0.23, 0.11) if hl else Color(0.23, 0.17, 0.08)
		sb.border_color = Color(1.0, 0.9, 0.55) if hl else GOLD
		sb.set_border_width_all(3)
		sb.shadow_color = Color(1.0, 0.78, 0.3, 0.5)  # 금빛 발광
		sb.shadow_size = 12
	elif rarity == "uncommon":
		sb.bg_color = Color(0.17, 0.26, 0.17) if hl else Color(0.12, 0.19, 0.12)
		sb.border_color = Color(0.7, 0.95, 0.68) if hl else GREEN
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0.45, 0.75, 0.4, 0.35)
		sb.shadow_size = 8
	else:
		sb.bg_color = Color(0.19, 0.22, 0.30) if hl else Color(0.14, 0.16, 0.22)
		sb.border_color = Color(0.72, 0.82, 0.96) if hl else Color(0.5, 0.6, 0.78)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0.4, 0.5, 0.7, 0.3)
		sb.shadow_size = 6
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb

## 스킬 카드 전용 프레임 — 희귀도 대신 오행 속성 색으로 구분(어두운 속성 배경 + 속성 테두리 + 발광)
func _skill_style(elem: String, hl: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var col := ElementLib.color(elem)
	sb.bg_color = Color(col.r * 0.32, col.g * 0.32, col.b * 0.32, 1.0) if hl else Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 1.0)
	sb.border_color = col.lightened(0.25) if hl else col
	sb.set_border_width_all(4)
	sb.shadow_color = Color(col.r, col.g, col.b, 0.55)
	sb.shadow_size = 18
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb

func _on_button_pressed(index: int) -> void:
	if picking:
		return
	picking = true
	auto_left = 0.0  # 선택됨 — 카운트다운 정지
	reroll_button.disabled = true
	var chosen: Button = buttons[index]
	chosen.pivot_offset = chosen.size / 2.0
	for i in buttons.size():  # 나머지 카드는 흐려짐
		if i != index and buttons[i].visible:
			create_tween().tween_property(buttons[i], "modulate", Color(0.45, 0.45, 0.5, 0.35), 0.18)
	# 선택 카드: 번쩍 + 팝업 후 닫기 → 선택 emit
	var t := create_tween()
	t.tween_property(chosen, "scale", Vector2(1.2, 1.2), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(chosen, "modulate", Color(1.7, 1.7, 1.7, 1.0), 0.13)
	t.tween_property(chosen, "modulate", Color(1, 1, 1, 1), 0.1)
	t.tween_interval(0.04)
	t.tween_callback(func() -> void:
		hide()
		card_chosen.emit(shown_cards[index]))

## 테스트용 자동선택: 정상 선택 경로(hide + emit)와 동일하게 무작위 1장
func pick_random() -> void:
	if not shown_cards.is_empty():
		_on_button_pressed(randi() % shown_cards.size())
