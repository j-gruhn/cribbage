extends CanvasLayer

@onready var game = get_node("/root/Game")
@onready var cards_player_node = get_node("/root/Game/Cards_Player")

func _ready():
	# Debug prints
	print("Player color string: ", game.PLAYER_COLOR['Player'])
	print("Computer color string: ", game.PLAYER_COLOR['Computer'])
	
	var player_color = Color("#" + game.PLAYER_COLOR['Player'])
	var computer_color = Color("#" + game.PLAYER_COLOR['Computer'])
	
	print("Player Color object: ", player_color)
	print("Computer Color object: ", computer_color)
	
	$Label_Player.add_theme_color_override("font_color", player_color)
	$Label_Computer.add_theme_color_override("font_color", computer_color)
	$Score_Player.add_theme_color_override("font_color", player_color)
	$Score_Computer.add_theme_color_override("font_color", computer_color)
	
	# Debug - check if override was applied
	print("Label_Player color override: ", $Label_Player.get_theme_color("font_color"))
	
	$ScoreEntry.text_changed.connect(_on_score_text_changed)
	$ScoreEntry.text_submitted.connect(_on_score_submitted)
	
	$ScoreEntry.visible = false
	$Label_ScoreEntry.visible = false
	

func _on_button_pressed() -> void:
	if $Button.text == "Deal":
		$Button.visible = false
	if $Button.text.ends_with('crib'):
		var children = cards_player_node.get_children()
		for i in range(children.size() - 1, -1, -1):
			var child = children[i]
			if child.selected == true:
				game.HAND_PLAYER.erase(child.code)
				cards_player_node.remove_child(child)
				child.queue_free()
	if $Button.text == "OK":
		pass
	if $Button.text == "Play again":
		game.GAME_OVER = false
	
func _on_score_text_changed(new_text: String):
	var filtered_text = ''
	for character in new_text:
		if character.is_valid_int():
			filtered_text += character
	
	if filtered_text != new_text:
		$ScoreEntry.text = filtered_text
		$ScoreEntry.caret_column = filtered_text.length()
	
func _on_score_submitted(text: String):
	var score = int(text) if text != '' else 0
