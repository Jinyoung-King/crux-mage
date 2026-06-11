extends Control
## 웨이브 클리어 후 카드 중 1장을 고르는 UI. 선택하면 card_chosen을 쏘고 닫힌다.

signal card_chosen(card)

@onready var buttons: Array = [$Center/Cards/Card1, $Center/Cards/Card2, $Center/Cards/Card3]

var shown_cards: Array = []

func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(_on_button_pressed.bind(i))

## cards(CardData 배열, 최대 3장)를 버튼에 채우고 표시
func open(cards: Array) -> void:
	shown_cards = cards
	for i in buttons.size():
		var btn: Button = buttons[i]
		if i < cards.size():
			var is_rare: bool = cards[i].rarity == "rare"
			btn.text = "%s%s\n%s" % ["★ " if is_rare else "", cards[i].card_name, cards[i].description]
			btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4) if is_rare else Color(1, 1, 1))
			btn.visible = true
		else:
			btn.visible = false
	show()

func _on_button_pressed(index: int) -> void:
	hide()
	card_chosen.emit(shown_cards[index])
