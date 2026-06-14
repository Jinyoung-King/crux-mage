extends Control
## 장비 강화 화면: 마법사를 골라, 5개 장비(지팡이·로브·부츠·반지·부적)를 코인으로 강화한다.
## 각 장비는 기존 영구 강화(공격력·체력·연사·흡혈·추가카드)를 시각화한 것 — 데이터는 GameState.upgrades(캐릭터별).

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const EQUIP_SLOT := preload("res://scenes/ui/equip_slot.gd")

# 장비 ↔ 강화 id 매핑 (표시 이름·도형·색·페이퍼돌 위치). 위치는 doll(480×360) 기준.
const EQUIP := [
	{"id": "damage",     "equip": "마력 지팡이", "kind": "staff",  "color": Color(0.96, 0.42, 0.36), "pos": Vector2(36, 14)},
	{"id": "max_hp",     "equip": "수호 로브",   "kind": "robe",   "color": Color(0.4, 0.82, 0.72),  "pos": Vector2(348, 14)},
	{"id": "fire_rate",  "equip": "신속 부츠",   "kind": "boots",  "color": Color(0.96, 0.86, 0.42), "pos": Vector2(20, 214)},
	{"id": "lifesteal",  "equip": "흡혈 반지",   "kind": "ring",   "color": Color(0.92, 0.42, 0.72), "pos": Vector2(192, 252)},
	{"id": "extra_card", "equip": "예지 부적",   "kind": "amulet", "color": Color(0.66, 0.5, 0.96),  "pos": Vector2(364, 214)},
]

@onready var root: VBoxContainer = $Root

var unlocked_chars: Array = []   # 해금된 캐릭터(선택기 순환 대상)
var char_pos: int = 0            # unlocked_chars 내 현재 위치
var slots: Dictionary = {}       # id → EquipSlot 노드
var sel_id: String = "damage"    # 현재 선택된 장비

# 동적 생성 노드 참조
var char_icon: TextureRect
var char_name_lbl: Label
var mastery_lbl: Label
var mage_doll: TextureRect
var detail_name: Label
var detail_effect: Label
var detail_next: Label
var buy_button: Button
var coin_label: Label

func _ready() -> void:
	Music.play_menu()
	for c in GameState.characters:
		if GameState.is_unlocked(c):
			unlocked_chars.append(c)
	if unlocked_chars.is_empty():
		unlocked_chars = [GameState.characters[0]]
	char_pos = maxi(unlocked_chars.find(GameState.selected), 0)
	GameState.selected = unlocked_chars[char_pos]
	_build_ui()
	_refresh()

func _build_ui() -> void:
	root.add_theme_constant_override("separation", 12)
	root.add_child(_label("장비 강화", 38, Color(0.95, 0.96, 1.0), true))

	# 캐릭터 선택기: ◀ [도트 + 이름] ▶
	var sel := HBoxContainer.new()
	sel.alignment = BoxContainer.ALIGNMENT_CENTER
	sel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sel.add_theme_constant_override("separation", 16)
	var prev := _nav_button("◀")
	prev.pressed.connect(_cycle_char.bind(-1))
	sel.add_child(prev)
	var cbox := VBoxContainer.new()
	cbox.alignment = BoxContainer.ALIGNMENT_CENTER
	char_icon = TextureRect.new()
	char_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	char_icon.custom_minimum_size = Vector2(64, 64)
	char_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cbox.add_child(char_icon)
	char_name_lbl = _label("", 24, Color.WHITE, true)
	cbox.add_child(char_name_lbl)
	sel.add_child(cbox)
	var nxt := _nav_button("▶")
	nxt.pressed.connect(_cycle_char.bind(1))
	sel.add_child(nxt)
	root.add_child(sel)

	mastery_lbl = _label("", 18, Color(0.8, 0.85, 0.95), true)
	root.add_child(mastery_lbl)

	# 페이퍼돌: 중앙 마법사 도트 + 주위 장비 슬롯 5개
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(480, 360)
	doll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(doll)
	mage_doll = TextureRect.new()
	mage_doll.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mage_doll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mage_doll.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mage_doll.size = Vector2(132, 132)
	mage_doll.position = Vector2(174, 96)
	mage_doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(mage_doll)
	for d in EQUIP:
		var slot: Control = EQUIP_SLOT.new()
		slot.setup(d["id"], d["kind"], d["color"])
		slot.position = d["pos"]
		slot.tapped.connect(_on_slot_tapped)
		doll.add_child(slot)
		slots[d["id"]] = slot

	# 상세 패널
	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.16, 0.15, 0.2, 0.95)
	pstyle.set_corner_radius_all(10)
	pstyle.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	detail_name = _label("", 26, Color.WHITE, true)
	detail_effect = _label("", 19, Color(0.85, 0.88, 0.96), true)
	detail_next = _label("", 17, Color(0.6, 0.85, 0.65), true)
	pv.add_child(detail_name)
	pv.add_child(detail_effect)
	pv.add_child(detail_next)
	buy_button = Button.new()
	buy_button.custom_minimum_size = Vector2(260, 54)
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_button.add_theme_font_override("font", FONT)
	buy_button.add_theme_font_size_override("font_size", 22)
	buy_button.pressed.connect(_on_buy)
	pv.add_child(buy_button)
	panel.add_child(pv)
	root.add_child(panel)

	# 코인 + 뒤로
	coin_label = _label("", 22, Color(0.98, 0.85, 0.4), true)
	root.add_child(coin_label)
	var back := Button.new()
	back.custom_minimum_size = Vector2(220, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 22)
	back.text = "뒤로"
	back.pressed.connect(_on_back)
	root.add_child(back)

func _label(text: String, size: int, color: Color, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _nav_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56, 64)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 28)
	return b

func _cycle_char(dir: int) -> void:
	char_pos = (char_pos + dir + unlocked_chars.size()) % unlocked_chars.size()
	GameState.selected = unlocked_chars[char_pos]
	_refresh()

func _on_slot_tapped(id: String) -> void:
	sel_id = id
	_refresh()

func _on_buy() -> void:
	if GameState.buy_upgrade(sel_id):
		_refresh()

## 강화 레벨 → 등급(0~5). 무한 강화 항목도 구간으로 등급화.
func _tier(lv: int) -> int:
	if lv <= 0: return 0
	if lv <= 2: return 1
	if lv <= 5: return 2
	if lv <= 9: return 3
	if lv <= 15: return 4
	return 5

## 현재 누적 보너스 표기 문자열
func _bonus_str(id: String) -> String:
	var bonus := GameState.upgrade_value(id)
	if id == "fire_rate": return "%.1f" % bonus
	if id == "lifesteal": return str(int(round(bonus * 100.0)))
	return str(int(bonus))

func _refresh() -> void:
	var c: CharacterData = GameState.selected
	char_icon.texture = c.mage_sprite
	mage_doll.texture = c.mage_sprite
	char_name_lbl.text = c.display_name
	char_name_lbl.add_theme_color_override("font_color", c.accent_color)
	mastery_lbl.text = "숙련 Lv %d · 전투력 +%d%%" % [GameState.char_level(c), int(round((GameState.mastery_mult(c) - 1.0) * 100.0))]
	coin_label.text = "보유 코인 %s" % NumFmt.compact(GameState.coins)
	for d in EQUIP:
		var id: String = d["id"]
		var lv := GameState.upgrade_level(id)
		slots[id].set_state(lv, _tier(lv), id == sel_id, GameState.can_buy(id))
	_refresh_detail()

func _refresh_detail() -> void:
	var def := GameState.upgrade_def(sel_id)
	var vis: Dictionary = {}
	for d in EQUIP:
		if d["id"] == sel_id:
			vis = d
	var lv := GameState.upgrade_level(sel_id)
	var mx := int(def.get("max", 0))
	var lv_str: String = ("Lv %d / %d" % [lv, mx]) if mx >= 0 else ("Lv %d" % lv)
	detail_name.text = "%s  (%s)" % [vis["equip"], lv_str]
	detail_name.add_theme_color_override("font_color", vis["color"])
	detail_effect.text = "%s  현재 +%s%s" % [def["name"], _bonus_str(sel_id), def["suffix"]]
	var cost := GameState.next_cost(sel_id)
	if cost < 0:
		detail_next.text = "최대 강화 완료"
		buy_button.text = "MAX"
		buy_button.disabled = true
	else:
		var per: float = def.get("per", 0.0)
		var next_str: String
		if sel_id == "lifesteal": next_str = "+%d%%" % int(round(per * 100.0))
		elif sel_id == "fire_rate": next_str = "+%.1f" % per
		else: next_str = "+%d" % int(per)
		detail_next.text = "다음 레벨: %s%s" % [next_str, def["suffix"]]
		buy_button.text = "강화  %s 코인" % NumFmt.compact(cost)
		buy_button.disabled = not GameState.can_buy(sel_id)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
