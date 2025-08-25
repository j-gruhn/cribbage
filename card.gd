extends Area2D

@export var code: String = ""   # two-character card code (e.g. "AC", "TD")

var sprite: Sprite2D
var overlay: ColorRect

@onready var game = get_node("/root/Game")
@onready var table_button = get_node("/root/Game/Table/Button")
@onready var cards_player_node = get_node("/root/Game/Cards_Player")

var selected: bool

var card_scene = preload("res://card.tscn")

signal card_clicked

func _ready():
	sprite = $Sprite2D
	overlay = $Overlay
	
	sprite.visible = true
	overlay.color = Color(0, 0, 0, 0.7) # semi-transparent black
	overlay.visible = false
	

func show_face():
	var path = "res://art/%s.png" % code
	var tex = load(path)
	if tex == null:
		push_warning("Card image not found: " + path)
	sprite.texture = tex
	overlay.visible = false

func show_back():
	var tex = load("res://art/back.png")
	sprite.texture = tex
	overlay.visible = false

#func select():
	#overlay.visible = true
#
#func deselect():
	#overlay.visible = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed() and self.get_parent() == cards_player_node:
		if game.STAGE == 'crib_selection':
			if selected == true:
				sprite.position += Vector2(0, 50)
				selected = false
				game.CRIB.erase(self.code)
				table_button.disabled = true
			else:
				if game.CRIB.size() < 2:
					sprite.position += Vector2(0, -50)
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
			
