## full disclosure, the Help section was mostly written by Claude AI because I didn't feel like figuring out how to get the
## instructions window to work.  Instructions were written by me, though

extends CanvasLayer

@onready var game = get_node("/root/Game")
@onready var cards_player_node = get_node("/root/Game/Cards_Player")

var card_scene = preload("res://card.tscn")
var help_dialog: AcceptDialog

func _ready():
	game.prep_playing_field()
	game.shuffle_deck()
	display_menu_cards()
	
	create_help_dialog()

func display_menu_cards():
	## menu was looking a little bare, so I replicated this logic from the game.gd script to show six random cards along the bottom of the screen
	var HAND_PLAYER = game.DECK_SHUFFLED.slice(0,6)
	
	for i in range(HAND_PLAYER.size()):
		var card = card_scene.instantiate()
		card.code = HAND_PLAYER[i]
		cards_player_node.add_child(card)
		card.position = Vector2(game.CARD_X[i]  + 165, game.CARD_Y['Player'])
		card.show_face()
		card.selected = false

func _on_button_pressed() -> void:
	game.discard_all_cards()
	game.button_was_clicked.emit()
	
func create_help_dialog():
	print("Creating help dialog...")
	help_dialog = AcceptDialog.new()
	help_dialog.title = "Cribbage Instructions"
	help_dialog.dialog_close_on_escape = true
	help_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	
	# Set dialog size
	help_dialog.min_size = Vector2i(650, 450)
	
	# Create instructions directly without ScrollContainer
	var instructions = RichTextLabel.new()
	instructions.bbcode_enabled = true
	instructions.custom_minimum_size = Vector2(600, 400)
	instructions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instructions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	instructions.text = """
[font_size=18][b]Objective[/b][/font_size]
Be the first player to reach 121 points.

[font_size=16][b]How to Play:[/b][/font_size]
Both players cut the deck to determine the first dealer. Cards are ranked from Ace (lowest) through Kind (highest). Low card wins the cut.

Each player is dealt six cards, and each selects two cards to be thrown into the dealer's crib. The non-dealer cuts the deck, and the dealer reveals
the next card and places it face up on the table. If the revealed card is a Jack, the dealer earns two points (Heels).

Play starts with the non-dealer.  Each player plays one card at a time to increase the running total.
	- Aces: 1 point
	- 10 through King: 10 points
	- All other cards have points equal to their pips

The running total cannot exceed 31 points. If a player does not have any card that can be played, the other player continues to lay down cards until
they can no longer play. The player that played the last card scores 1 point (Go), the running total is reset to zero, and play resumes with the other player.
This continues until each player has played all four cards.

[font_size=16][b]Scoring (In Play):[/b][/font_size]
	- Running total hits 15 or 31:  2 points
	- Pair:  2 points
	- 3 of a kind:  6 points
	- 4 of a kind: 12 points
	- Run of 3 or more: 1 point per card
		- A run only applies on cards played consecutively, but the ranks do not need to be played sequentially
	- Go: 1 point
	- Last card: 1 point
		- Last card played in the entire round

Once all cards have been played, each players tallies up the points of their five cards (four cards in hand, plus community card that was revealed
at the beginning of the round). Hands are scored in the following order:
	- Non-dealer player
	- Dealer
	- Crib
	
[font_size=16][b]Scoring (End of Round):[/b][/font_size]
	- Fifteen: 2 points for each combination of cards summing to 15
	- Pairs: 2 points
	- 3 of a kind: 6 points
	- 4 of a kind: 12 points
	- Runs of 3 or more: 1 point per card
	- Flush: 4 points if all cards in hand are the same suit, +1 if community card also matches
		- Four card flushes are not counted in the crib
	- Nobs: 1 point
		- Jack suit matches suit of community card

All computer hands and points in play are pegged automatically, but the player must submit their own score for each hand. If you overcount your hand,
you will receive the correct amount of points and the computer player will receive 2 points. If you undercount your hand, you will receive your submitted
score and the computer will receive the difference (Muggins).

[font_size=16][b]Controls:[/b][/font_size]
- Left click to select cards and click buttons
- Type numbers and press Enter to submit scores
"""

	help_dialog.add_child(instructions)
	
	# Add to the current scene
	add_child(help_dialog)
	print("Help dialog added to scene")

func _on_help_button_pressed():
	if help_dialog:
		help_dialog.popup_centered()
