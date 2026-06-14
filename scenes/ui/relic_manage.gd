extends Control
## 유물 뽑기: 코인으로 랜덤 유물을 뽑아 모은다. 중복은 레벨↑로 강화되고, 모은 유물은 전부 적용된다.

const FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const RUNE_ICON := preload("res://scenes/ui/rune_icon.gd")

@onready var coin_label: Label = $Center/CoinLabel
@onready var result_label: Label = $Center/SlotLabel   # 재활용: 뽑기 결과/안내(금색)
@onready var rows: VBoxContainer = $Center/Rows
@onready var roll_button: Button = $Center/SlotButton   # 재활용: 뽑기 버튼
@onready var back_button: Button = $Center/BackButton

var row_labels := {}  # id → Label
var row_icons := {}   # id → RuneIcon

func _ready() -> void:
	$Center/Title.text = "룬 뽑기"
	back_button.pressed.connect(_on_back)
	roll_button.pressed.connect(_on_roll)
	for r in RelicLib.RELICS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		var icon = RUNE_ICON.new()
		icon.setup(r.id, r.get("color", Color.WHITE), true)
		row.add_child(icon)
		var lbl := _label("", 18, Color(0.92, 0.94, 1.0))
		lbl.custom_minimum_size = Vector2(500, 0)
		row.add_child(lbl)
		rows.add_child(row)
		row_labels[r.id] = lbl
		row_icons[r.id] = icon
	result_label.text = "코인으로 룬을 뽑아 모으세요 (중복은 강화)"
	_refresh()

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _on_roll() -> void:
	var res := GameState.roll_relic()
	if res.is_empty():
		result_label.text = "코인이 부족합니다 (%d 필요)" % GameState.current_roll_cost()
		return
	var nm: String = RelicLib.relic_def(res.id).name
	result_label.text = ("%s 획득! (Lv %d)" % [nm, res.level]) if res.is_new else ("%s 강화! (Lv %d)" % [nm, res.level])
	_refresh()

func _refresh() -> void:
	coin_label.text = "보유 코인 %s" % NumFmt.compact(GameState.coins)
	roll_button.text = "룬 뽑기 (%d코인)" % GameState.current_roll_cost()
	roll_button.disabled = not GameState.can_roll_relic()
	for r in RelicLib.RELICS:
		var lv := GameState.relic_level(r.id)
		var lbl: Label = row_labels[r.id]
		row_icons[r.id].setup(r.id, r.get("color", Color.WHITE), lv <= 0)  # 미보유는 흐리게
		if lv > 0:
			lbl.text = "%s  Lv %d  ·  %s" % [r.name, lv, RelicLib.effect_text(r.id, lv)]
			lbl.modulate = Color(1, 1, 1)
		else:
			lbl.text = "%s  (미보유)" % r.name
			lbl.modulate = Color(0.5, 0.5, 0.55)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
