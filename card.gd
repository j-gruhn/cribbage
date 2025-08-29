extends Area2D

@export var code: String = ""   # two-character card code (e.g. "AC", "TD")

var sprite: Sprite2D
var overlay: ColorRect
var rank1: RichTextLabel
var rank2: RichTextLabel

@onready var game = get_node("/root/Game")
@onready var table_button = get_node("/root/Game/Table/Button")
@onready var cards_player_node = get_node("/root/Game/Cards_Player")

var selected: bool

var card_scene = preload("res://card.tscn")

signal card_clicked

## assigning suits to red and black colors
const SUIT_DICT: Dictionary = {
	'C': ['club', '100101'],
	'D': ['diamond', 'a81717'],
	'H': ['heart', 'a81717'],
	'S': ['spade', '100101']
}

func _ready():
	sprite = $SuitSprite
	overlay = $Overlay
	rank1 = $RankLabel1
	rank2 = $RankLabel2
	
	sprite.visible = true
	rank1.visible = false
	rank2.visible = false
	overlay.color = Color(0, 0, 0, 0.7) # semi-transparent black
	overlay.visible = false
	
	
func show_face():
	## load the card art, fill text boxes, and make visible
	var path = "res://art/%s.png" % SUIT_DICT[code[1]][0]
	var tex = load(path)
	var rank_text: String
	
	if tex == null:
		push_warning("Card image not found: " + path)
	sprite.texture = tex
	
	for rank in [rank1, rank2]:
		rank.clear()
				
		if code[0] == 'T':
			rank_text = ' 10 '
		else:
			rank_text = ' ' + code[0] + ' '
			
		rank.bbcode_text = "[color=#%s]%s[/color]" % [SUIT_DICT[code[1]][1], rank_text]
		rank.visible = true
	
	overlay.visible = false

func show_back():
	var tex = load("res://art/back.png")
	sprite.texture = tex
	overlay.visible = false

## if a card is clicked on during selection of crib cards, only two can be selected and button will be enabled/disabled accordingly
## if a card is clicked on during play, move it to the "played pile" on the left and update the appropriate arrays/nodes
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed() and self.get_parent() == cards_player_node:
		if game.STAGE == 'crib_selection':
			if selected == true:
				self.position += Vector2(0, 50)
				selected = false
				game.CRIB.erase(self.code)
				table_button.disabled = true
			else:
				if game.CRIB.size() < 2:
					self.position += Vector2(0, -50)
					selected = true
					game.CRIB.append(self.code)
					
					if game.CRIB.size() == 2:
						table_button.disabled = false
		if game.STAGE == 'play_cards' and game.PLAYER_TURN == true and overlay.visible == false:
			game.PLAYED_PLAYER.append(self.code)
			game.HAND_PLAYER.erase(self.code)
			self.position = Vector2(game.CARD_X[0] + (game.PLAYED_PLAYER.size() - 1) * 50, game.CARD_Y['Player'])
			self.z_index = game.PLAYED_PLAYER.size() - 1
			
			game.card_was_clicked.emit()
			
