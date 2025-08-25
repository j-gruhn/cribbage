extends CanvasLayer

@onready var game = get_node("/root/Game")
@onready var cards_player_node = get_node("/root/Game/Cards_Player")

func _ready():
	$Score_Player.text = "0"
	$Score_Computer.text = "0"
	
	#test_score()
	
func test_score():
	update_score($Score_Player, 2)
	update_game_log($Score_Player, 'Fifteen')
	
func update_score(player, score):
	var current_score: int
	var new_score: int
	
	current_score = int(player.text)
	new_score = current_score + score
	player.text = str(new_score)
	
func update_game_log(player, reason):
	$Log_PointHistory.text += 'Fifteen (+2)'
	$Log_PointHistory.text += '\n'


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
