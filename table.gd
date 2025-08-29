## there's a lot more going on in this scene than there probably should be
## looking at the 2D view of this scene is a mess, and in the future I would split it up to make it easier to work with
## it all seems to be working fine, though

extends CanvasLayer

@onready var game = get_node("/root/Game")
@onready var menu = get_node("/root/Game/Menu")
@onready var cards_player_node = get_node("/root/Game/Cards_Player")

func _ready():

	var player_color = Color("#" + game.PLAYER_COLOR['Player'])
	var computer_color = Color("#" + game.PLAYER_COLOR['Computer'])
	
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
	
## one main button, action varies based on the current text of the button
func _on_button_pressed() -> void:
	if $Button.text == "Play":
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
		$Button.visible = false
		game.button_was_clicked.emit()
	
func _on_button_quit_pressed() -> void:
	game.GAME_OVER = true
	$Button_Quit.visible = false
	game.button_was_clicked.emit()
	
## I honestly think these next two functions might not be used at all, though this first one may be what is
## preventing the user for entering anything besides an integer of length 2
## I'm just going to leave them both in to be safe
func _on_score_text_changed(new_text: String):
	var filtered_text = ''
	for character in new_text:
		if character.is_valid_int():
			filtered_text += character
	
	if filtered_text != new_text:
		$ScoreEntry.text = filtered_text
		$ScoreEntry.caret_column = filtered_text.length()
	
func _on_score_submitted(text: String):
	pass


func _on_help_button_pressed() -> void:
	menu._on_help_button_pressed()
