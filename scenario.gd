extends CanvasLayer

@onready var game = get_node("/root/Game")
@onready var cards_player_node = get_node("/root/Game/Cards_Player")
@onready var cards_scenario_node = $Cards_Scenario

var card_scene = preload("res://card.tscn")


func _ready():
	game.prep_playing_field()
	
	var x_offset: int = 0
	var y_offset: int = 0
	
	for i in game.DECK:
		var scenario_card = card_scene.instantiate()
		scenario_card.code = i
		scenario_card.scale = Vector2(0.6, 0.6)
		cards_scenario_node.add_child(scenario_card)
		scenario_card.position = Vector2(75 + 65 * x_offset, 200 + 100 * y_offset)
		scenario_card.show_face()
		scenario_card.selected = false
		
		x_offset += 1
		if x_offset == 13:
			x_offset = 0
			y_offset += 1
			
	$Button_Calc.disabled = true
		

func _on_toggle_crib_recipient_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$Label_CribRecipient.text = 'Computer Crib'
		game.PLAYER_DEALER = false
	else:
		$Label_CribRecipient.text = 'Player Crib'
		game.PLAYER_DEALER = true
		
func _on_button_calc_pressed() -> void:
	game.get_crib_hint(true)
	
func _on_button_exit_pressed() -> void:
	game.discard_all_cards()
	_on_button_reset_all_pressed()
	game.button_was_clicked.emit()
	
	game.PLAYER_DEALER = null
	
func _on_button_reset_selection_pressed() -> void:
	for i in cards_scenario_node.get_children():
		i.selected = false
		i.overlay.visible = false
	
	game.HAND_PLAYER = []
	$Button_Calc.disabled = true
	
func _on_button_reset_all_pressed() -> void:
	_on_button_reset_selection_pressed()
	$GameLog.text = ''
	
