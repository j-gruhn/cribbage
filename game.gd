## a long, unweildy script that handles most of the game logic
## This is my first Godot project, so you will notice some inconsistencies in naming conventions, and I definitely would have restructured it
## differently if I were to build it again today.
## Instead of refactoring, will likely make another card game in the future and apply these lessons there

## In lieu of refactoring, just going to add a bunch of comments throughout the script

extends Node2D

## lots of variables for keeping track of game state, cards played, etc.
var DECK: Array
var DECK_SHUFFLED: Array = []
var CARD_RANK: Dictionary
var CRIB_COMBOS_PLAYER: Array
var CRIB_COMBOS_COMPUTER: Array
var CARD_X: Dictionary
var CARD_Y: Dictionary

var HAND_PLAYER: Array = []
var HAND_COMPUTER: Array = []
var PLAYED_PLAYER: Array = []
var PLAYED_COMPUTER: Array = []
var PLAYED_ALL: Array = []
var PLAYED_ALL_SEQ: Array = []
var CRIB: Array = []
var CARD_CUT: String
var LAST_PLAYED: String
var GAME_OVER: bool = false

var PLAYER_DEALER: Variant = null
var PLAYER_TURN: bool
var turn_display: String:
	get:
		return 'Player' if PLAYER_TURN else 'Computer'
var dealer_display: String:
	get:
		return 'Player' if PLAYER_DEALER else 'Computer'



@export var STAGE: String

#var card_code: String
var round_count: int

## point to all the nodes/children needed from the other scenes
@onready var cards_player_node = $Cards_Player
@onready var cards_computer_node = $Cards_Computer
@onready var cards_crib_node = $Cards_Crib
@onready var cards_cut_node = $Cards_Cut

@onready var game_log = $Table/GameLog
@onready var game_log_scenario = $Scenario/GameLog
@onready var table_button = $Table/Button
@onready var button_quit = $Table/Button_Quit
@onready var button_hint = $Table/Hint_Button
@onready var table_arrow = $Table/NextArrow
@onready var label_played = $Table/Label_RunningTotal
@onready var score_played = $Table/Score_RunningTotal
@onready var label_score_entry = $Table/Label_ScoreEntry
@onready var score_entry = $Table/ScoreEntry
@onready var score_player = $Table/Score_Player
@onready var score_computer = $Table/Score_Computer
@onready var score_round = $Table/Score_Round
@onready var label_scoreround = $Table/Label_ScoreRound

@onready var DIFFICULTY = $Menu/Option_Difficulty.get_item_text($Menu/Option_Difficulty.selected)


var card_scene = preload("res://card.tscn")

var score_total_current_player: Variant:
	get:
		return score_player if PLAYER_TURN else score_computer
		
var PLAYER_COLOR: Dictionary = {
	'Player': '8499de', 
	'Computer': 'ee8f06',
	'metadata': 'dde0e9'
}

signal card_was_clicked
signal button_was_clicked

func _ready():
	## game starts by showing the main menu, but loops indefinitely to allow movement between menu and gameplay
	while true:
		show_menu()
		var mode = await button_was_clicked
	
		if mode == 'game':
			await gameplay_main()
		elif mode == 'scenario':
			await show_scenario_mode()

func gameplay_main():
	print(DIFFICULTY)
	show_table()
	prep_playing_field()
	table_arrow.visible = false
	button_hint.visible = false
	
	## looping through playing a whole game (play_game) and breaking the loop when the player selects the Quit button
	while true:
		GAME_OVER = false
		score_player.text = '0'
		score_computer.text = '0'
		await play_game()
		
		table_button.visible = true
		table_button.text = 'Play again'
		table_button.disabled = false
		button_quit.visible = true
		await button_was_clicked
		discard_all_cards()
		if GAME_OVER == true:
			break
		else:
			show_table()
	
func play_game():
	shuffle_deck()
	cut_for_deal()
	
	table_button.visible = true
	table_button.text = "Play"
	await table_button.pressed
	discard_all_cards()
	
	## loop for each hand
	## function names should be pretty well self-documenting for this one, but any other toggles and function calls
	## peppered in here are used to make sure the screen is displaying the right nodes
	round_count = 0
	while not GAME_OVER:
		round_count += 1
		game_log.push_color(Color(PLAYER_COLOR['metadata']))
		game_log.add_text('-------------------------------------------\n')
		game_log.add_text('Round ' + str(round_count) + '\n')
		game_log.push_color(Color(PLAYER_COLOR[dealer_display]))
		game_log.add_text(dealer_display + ' deals\n\n')
		
		#score_player.text = '111'
		#score_computer.text = '111'
		
		shuffle_deck()
		deal()
		print(HAND_PLAYER)
		print(HAND_COMPUTER)
		print(CARD_CUT)
		
		STAGE = 'crib_selection'
		PLAYER_TURN = PLAYER_DEALER
		arrow_flip()
		table_arrow.visible = true
		button_hint.visible = true
		select_cards_for_crib_player()
		await table_button.pressed
		button_hint.visible = false
		select_cards_for_crib_computer()
		place_crib()
		table_arrow.visible = false
		print(CRIB)
		
		## determined earlier in deal, this is just instantiating the child
		show_cut_card()
		
		STAGE = 'play_cards'
		play_cards_display_toggle()
		rearrange_cards()
		await play_cards()
		await get_tree().create_timer(2.0).timeout
		play_cards_display_toggle()
		if GAME_OVER: return
		
		STAGE = 'score_hands'
		rearrange_cards()
		await score_hands()
		if GAME_OVER: return
		
		STAGE = 'score_crib'
		populate_crib()
		await score_crib()
		
		discard_all_cards()
		
		PLAYER_DEALER = not PLAYER_DEALER
			

func prep_playing_field():
	## building deck of cards and scoring attributes
	## [score value, order value]
	CARD_RANK = {
		'A': [1,1],
		'2': [2,2],
		'3': [3,3],
		'4': [4,4],
		'5': [5,5],
		'6': [6,6],
		'7': [7,7],
		'8': [8,8],
		'9': [9,9],
		'T': [10,10],
		'J': [10,11],
		'Q': [10,12],
		'K': [10,13]
	}
	
	## creating two persistent arrays of all possible cards the player may throw in the crib
	## if it is the player's deal, then include any two card combination (CRIB_COMBOS_PLAYER)
	## if it is the computer's deal, remove some combinations that are highly unlikely to be thrown by the player (CRIBS_COMBO_COMPUTER)
	CRIB_COMBOS_PLAYER = []
	CRIB_COMBOS_COMPUTER = []
	var crib_combo: Array
	for card1 in CARD_RANK:
		for card2 in CARD_RANK:
			if CARD_RANK[card1][1] < CARD_RANK[card2][1]:
				crib_combo = [card1 + 'Y', card2 + 'Y'] 
			else:
				crib_combo = [card2 + 'Y', card1 + 'Y']
				
			if crib_combo not in CRIB_COMBOS_PLAYER:
				CRIB_COMBOS_PLAYER.append(crib_combo)
			if crib_combo not in CRIB_COMBOS_COMPUTER:
				if (str(card1) != str(card2)) and (CARD_RANK[card1][0] + CARD_RANK[card2][0] != 15) and (CARD_RANK[card1][0] + CARD_RANK[card2][0] != 5) and (str(card1) != '5') and (str(card2) != '5'):
					CRIB_COMBOS_COMPUTER.append(crib_combo)

	
	DECK = []
	for suit in ['S','H','C','D']:
		for rank in CARD_RANK.keys():
			DECK.append(rank + suit)
			
	## X and Y coordinates for card positions on table
	for i in range(7):
		CARD_X[i] = 130 + i * 120
	CARD_X[4.5] = 130 + 4.5 * 120
		
	CARD_Y = {
		'Player': 600,
		'Computer': 200,
		'Cut': 400,
		'Player_Crib': 500,
		'Computer_Crib': 300
	}

func shuffle_deck():
	var deck_copy = DECK.duplicate()
	DECK_SHUFFLED = []
	while deck_copy.size() > 0:
		var j = randi() % deck_copy.size()
		DECK_SHUFFLED.append(deck_copy[j])
		deck_copy.remove_at(j)


func cut_for_deal():
	var player_cut: String
	var computer_cut: String
	var cut_size: int
	var player_rank: int
	var computer_rank: int
	
	while true:
		player_cut = DECK_SHUFFLED[randi() % (DECK.size() - 16)]
		cut_size = DECK_SHUFFLED.find(player_cut) + 1
		computer_cut = DECK_SHUFFLED[randi() % (DECK.size() - cut_size) + cut_size]
		
		print(player_cut)
		print(computer_cut)
		
		var card_player = card_scene.instantiate()
		card_player.code = player_cut
		cards_player_node.add_child(card_player)
		card_player.position = Vector2(CARD_X[3], CARD_Y['Player'])
		card_player.show_face()
		
		var card_computer = card_scene.instantiate()
		card_computer.code = computer_cut
		cards_computer_node.add_child(card_computer)
		card_computer.position = Vector2(CARD_X[3], CARD_Y['Computer'])
		card_computer.show_face()
		
		player_rank = CARD_RANK[player_cut[0]][1]
		computer_rank = CARD_RANK[computer_cut[0]][1]
				
		if player_rank < computer_rank:
			PLAYER_DEALER = true
		elif computer_rank < player_rank:
			PLAYER_DEALER = false
		else:
			PLAYER_DEALER = null
			
		if PLAYER_DEALER != null:
			game_log.push_color(Color(PLAYER_COLOR[dealer_display]))
			game_log.add_text(dealer_display + ' wins the cut\n')
			break
	

func sort_card_array(arr):	
	## added this because it was easier to sort the card codes in an array vs. sorting the actual cards in their nodes
	## orders cards in hand by rank/sequence
	arr.sort_custom(func(a,b): return CARD_RANK[a[0]][1] < CARD_RANK[b[0]][1])
	return arr
		
func deal():
	## deal out the first 12 cards, then assign to the correct player based on current dealer
	## also just cut the deck now while we're parsing the DECK_SHUFFLED array
	var hand_1: Array = []
	var hand_2: Array = []

	for i in range(0, 12, 2):
		hand_1.append(DECK_SHUFFLED[i])
		hand_2.append(DECK_SHUFFLED[i+1])

	if PLAYER_DEALER == true:
		HAND_PLAYER = sort_card_array(hand_1)
		HAND_COMPUTER = sort_card_array(hand_2)
	else:
		HAND_PLAYER = sort_card_array(hand_2)
		HAND_COMPUTER = sort_card_array(hand_1)

	CARD_CUT = DECK_SHUFFLED[randi() % (DECK.size() - 12) + 12]
	
	### can hardcode in hands here for testing purposes
	#HAND_PLAYER = ['5S', '5D', '5C', 'JH', 'KD','KH']
	#HAND_COMPUTER = ['AC','AD','AH','AS','KC','KS']
	#HAND_COMPUTER = ['5S', '5D', '5C', '5C', '5C','5C']
	#CARD_CUT = '5H'
	#HAND_PLAYER = ["TS", "JS", "TH", "QD", "AS", "AS"]
	#HAND_COMPUTER = ["2D", "4D", "4C", "7H", "KH", "KD"]
	#CARD_CUT = 'QS'

	# show player's cards (face up)
	for i in range(HAND_PLAYER.size()):
		var j = card_scene.instantiate()
		j.code = HAND_PLAYER[i]
		cards_player_node.add_child(j)
		j.position = Vector2(CARD_X[i], CARD_Y['Player'])
		j.show_face()
		j.selected = false

	# show computer's cards (face down)
	for i in range(HAND_COMPUTER.size()):
		var j = card_scene.instantiate()
		j.code = HAND_COMPUTER[i]
		cards_computer_node.add_child(j)
		j.position = Vector2(CARD_X[i], CARD_Y['Computer'])
		j.show_back()
		j.selected = false
		
	## populate the cut card node and show the card face down on the table
	var c = card_scene.instantiate()
	c.code = CARD_CUT
	cards_cut_node.add_child(c)
	c.position = Vector2(CARD_X[4.5], CARD_Y['Cut'])
	c.show_back()
		
func select_cards_for_crib_player():
	## card selection handled by logic in card.gd
	table_button.text = "Send cards to " + dealer_display + "'s crib"
	table_button.disabled = true
	table_button.visible = true


func get_combinations(array: Array, r: int, start: int = 0, current: Array = []) -> Array:
	var result = []
	
	if current.size() == r:
		result.append(current.duplicate())
		return result
	
	for i in range(start, array.size()):
		current.append(array[i])
		result.append_array(get_combinations(array, r, i + 1, current))
		current.pop_back()
	
	return result
	
func create_cut_probability_dict(hand):
	var prob_dict: Dictionary
	
	## based on the computer's knowledge at the time
	## probability of drawing each card in the cut is (4 - # in hand) / (unknown cards)
	for key in CARD_RANK:
		prob_dict[key] = float(max(4 - hand.filter(func(item): return item.begins_with(key)).size(), 0)) / float(52 - 6)
		
	return prob_dict
	
func create_nextcard_probability_dict():
	var prob_dict: Dictionary
	var worldview: Dictionary
	var rank_worldview: Dictionary
	
	## combining all cards that computer knows has been played
	## since the computer always throws in the crib last, grabbing last two instead of creating new variable to manage
	for hand in [HAND_COMPUTER, [CRIB[-2], CRIB[-1]], CARD_CUT, PLAYED_COMPUTER, PLAYED_PLAYER]:
		for i in hand:
			worldview[i] = true
			
	for i in worldview:
		rank_worldview[i[0]] = rank_worldview.get(i[0], 0) + 1
			
	for key in CARD_RANK:
		prob_dict[key] = float(4 - rank_worldview.get(key, 0)) / float(52 - worldview.size())
		
	return prob_dict
	
func create_crib_probability_dict(hand, cut, bln_hint=false):
	var tmp_dict: Dictionary
	var prob_dict: Dictionary
	var hand_cut: Array
	var rebalance: float = 0.00
	var combo_arr: Array
	var card_ct: int
	
	hand_cut = hand.duplicate()
	hand_cut.append(cut)
	
	## variable names were originally given before hint system was developed
	## both CRIBS_COMBO variables reflect what the opponent may throw, while the suffix of CRIBS_COMBO_* represents the dealer (crib recipient) at the time
	if bln_hint == false:
		## if not using hint system (default), computing from standpoint of computer and the opponent is you, the player.
		## assume the player would throw all combinations (CRIB_COMBOS_PLAYER) to his own crib or the limited combinations to computer crib
		combo_arr = CRIB_COMBOS_PLAYER if PLAYER_DEALER else CRIB_COMBOS_COMPUTER
	else:
		## if using the hint system (new feature), computing from standpoint of player and the opponent is the computer.
		## assume the computer would throw all combinations (CRIB_COMBOS_PLAYER) to its own crib or the limited combinations to you
		combo_arr = CRIB_COMBOS_COMPUTER if PLAYER_DEALER else CRIB_COMBOS_PLAYER

	for key in combo_arr:
		card_ct = max(4 - hand_cut.filter(func(item): return item.begins_with(key[0][0])).size(), 0)
		var card_1_prob = float(card_ct) / float(52 - 7)
		card_ct = max(4 - hand_cut.filter(func(item): return item.begins_with(key[1][0])).size(), 0)
		if key[0][0] == key[1][0]:
			card_ct = max(card_ct - 1, 0)
			
		var card_2_prob = float(card_ct) / float(52 - 8)
			
		tmp_dict[key] = (card_1_prob * card_2_prob * 2)
		rebalance += (card_1_prob * card_2_prob * 2)
		
	for key in tmp_dict:
		prob_dict[key] = tmp_dict[key] / rebalance
		
	return prob_dict


func select_cards_for_crib_computer():
	## on easy difficulty, randomly select two computer cards to send to the crib
	var card: Area2D
	var tmp_hand: Array
	table_button.visible = false
	
	if DIFFICULTY == 'EASY':
		for i in range(2):
			var card_code = HAND_COMPUTER[randi() % HAND_COMPUTER.size()]
			CRIB.append(card_code)
			HAND_COMPUTER.erase(card_code)
			card = get_child_from_card_node(cards_computer_node, card_code)
			cards_computer_node.remove_child(card)
			card.queue_free()
	elif DIFFICULTY == 'NORMAL':
		var highest_score: int = 0
		var highest_hand: Array = []
		
		var hands = get_combinations(HAND_COMPUTER, 4)
		
		
		## if both are close to finishing 
		if int(score_computer.text) > 110 and int(score_player.text) > 110:
			## if the player counts first, computer uses four lowest cards in hand
			if PLAYER_DEALER == false:
				highest_hand = HAND_COMPUTER.slice(0,4)
		## if the dealer counts first, pick the lowest cards that guarantee still being able to go out with counting
			else:
				for hand in hands:
					highest_score = calculate_hand_score(hand, null)['Total']
					if highest_score > (121 - int(score_computer.text)):
						highest_hand = hand
						break
		## otherwise, perform main logic for hand
		if highest_hand.size() == 0:
			highest_hand = calculate_best_crib_decision()[0]
				
		## I created this earlier and figured it was easier to just loop through to find the crib cards vs. carrying it through from the beginning
		tmp_hand = HAND_COMPUTER.duplicate()
		for card_code in tmp_hand:
			if card_code not in highest_hand:
				CRIB.append(card_code)
				HAND_COMPUTER.erase(card_code)
				card = get_child_from_card_node(cards_computer_node, card_code)
				cards_computer_node.remove_child(card)
				card.queue_free()
				
func calculate_best_crib_decision(bln_hint=false):

	var tmp_crib: Array
	var score_dict_hand: Dictionary
	var score_dict_crib: Dictionary
	var all_scores: Dictionary
	var all_cribs: Dictionary
	var highest_score: float = -999.00
	var highest_hand: Array = []
	var highest_score_hand: float = 0.00
	var highest_score_crib: float = 0.00
	var tmp_ev_hand: float
	var tmp_ev_crib: float
	var crib: Array
	
	var hand_arr = HAND_PLAYER if bln_hint else HAND_COMPUTER
	
	var hands = get_combinations(hand_arr, 4)
		
	var cut_odds = create_cut_probability_dict(hand_arr)

	
	## cycle through all possible hand/crib combinations
	for hand in hands:
		crib = hand_arr.filter(func(item): return not item in hand)
		
		all_scores[hand] = {}
		for key in CARD_RANK:
			score_dict_hand = calculate_hand_score(hand, key + 'X')
			
			## for each hand, also determine the expected value of the crib (rank only)
			var crib_odds = create_crib_probability_dict(hand_arr, key + 'X', bln_hint)
			
			all_cribs = {}
			for possible_crib in crib_odds:
				tmp_crib = crib + possible_crib
				score_dict_crib = calculate_hand_score(tmp_crib, key + 'X')
				
				all_cribs[possible_crib] = [score_dict_crib['Total'], crib_odds[possible_crib]]
				
			tmp_ev_crib = 0.0
			for i in all_cribs:
				tmp_ev_crib += float(all_cribs[i][0]) * all_cribs[i][1]
			
			## all_scores[hand][cut card] = [hand total, crib expected value given cut, odds of cut]
			all_scores[hand][key] = [score_dict_hand['Total'], tmp_ev_crib, cut_odds[key]]
			
	## cycle through the dictionary created above to determine the expected values of the hands and the crib EVs
	## in the event of a tie, keep the first combination found with that score
	## since it has been sorted, this is the hand with the lowest pips, which
	## should hopefully maximize points in play for the computer
	for hand in all_scores:
		tmp_ev_hand = 0
		tmp_ev_crib = 0
		for key in CARD_RANK:
			tmp_ev_hand += float(all_scores[hand][key][0]) * all_scores[hand][key][2]
			tmp_ev_crib += float(all_scores[hand][key][1]) * all_scores[hand][key][2]
			
		if (PLAYER_DEALER == true and bln_hint == false) or (PLAYER_DEALER == false and bln_hint == true):
			tmp_ev_crib = -tmp_ev_crib
			
		print(str(hand) + ': ' + str(tmp_ev_hand) + '; ' + str(tmp_ev_crib))
		
		if tmp_ev_hand + tmp_ev_crib > highest_score:
			highest_score = tmp_ev_hand + tmp_ev_crib
			highest_score_hand = tmp_ev_hand
			highest_score_crib = tmp_ev_crib
			highest_hand = hand
	
	## too lazy to pull all the way through, just going to redefine here
	crib = hand_arr.filter(func(item): return not item in highest_hand)
	return [highest_hand, crib, highest_score_hand, highest_score_crib]
	
func get_crib_hint(bln_scenario = false):
	
	var active_log = game_log_scenario if bln_scenario == true else game_log
	
	var suit_verbose = {
		'C': 'Clubs',
		'D': 'Diamonds',
		'H': 'Hearts',
		'S': 'Spades'
	}
	
	var rank_verbose = {
		'A': 'Ace',
		'T': '10',
		'J': 'Jack',
		'Q': 'Queen',
		'K': 'King'
	}
	
	var crib_pick = calculate_best_crib_decision(true)	
	
	active_log.push_color(Color(PLAYER_COLOR['metadata']))
	active_log.add_text('Send to crib:\n')
	active_log.push_bold()
	
	for i in range(2):
		var card_rank: String = crib_pick[1][i][0]
		var card_rank_verbose = rank_verbose[card_rank] if card_rank in rank_verbose else card_rank
		var card_suit: String = crib_pick[1][i][1]
		var card_suit_verbose = suit_verbose[card_suit]
		
		active_log.add_text(card_rank_verbose + ' of ' + card_suit_verbose + '\n')
		
	active_log.pop()
	
	var hand_ev = round_to_decimal_places(crib_pick[2], 3)
	var crib_ev = round_to_decimal_places(crib_pick[3], 3)
	var sign_crib = '+' if crib_ev >= 0 else ''
	var sign_net = '+' if (crib_ev + hand_ev) >= 0 else ''
	
	active_log.add_text('\nExpected Values:\n')
	active_log.add_text('Net: ' + sign_net + str(hand_ev + crib_ev) + '\n')
	active_log.add_text('      Hand: +' + str(hand_ev) + '\n')
	active_log.add_text('      Crib:   ' + sign_crib + str(crib_ev) + '\n\n')
	
	if bln_scenario == true:
		active_log.add_text('-------------------------------------------\n')
	
func round_to_decimal_places(value: float, decimals: int) -> float:
	var factor = pow(10, decimals)
	return round(value * factor) / factor	
					
func place_crib():	
	## dummy card to represent crib, shifted towards dealer side of table
	var card = card_scene.instantiate()
	cards_crib_node.add_child(card)
	card.position = Vector2(CARD_X[6], CARD_Y['Player_Crib' if PLAYER_DEALER else 'Computer_Crib'])
	card.show_back()
	
func populate_crib():
	## clear out dummy card, then populate with cards selected by player/computer
	discard_all_cards(cards_crib_node)
	CRIB = sort_card_array(CRIB)

	for card_code in CRIB:
		var card = card_scene.instantiate()
		card.code = card_code
		cards_crib_node.add_child(card)
		card.show_face()
		
	## move player and computer cards to right side of play field
	rearrange_cards()
	
func show_cut_card():
	## show the cut card, scoring for Heels if needed
	for j in cards_cut_node.get_children():
		j.show_face()
		
		if j.code[0] == 'J':
			update_game_log({'Heels': 2}, dealer_display)
			update_total_score(2, score_total_current_player)
			if GAME_OVER: return
	
func rearrange_cards():
	## realign cards on table based on game state and player/computer position
	if STAGE == 'score_crib':
		for i in range(4):
			cards_crib_node.get_child(i).position = Vector2(CARD_X[i + 2], CARD_Y[dealer_display])
	else:
		## for the play_cards stage, reorganize computer cards so player cannot deduce what cards they have left in their hand
		var rand_arr = [0,1,2,3]
		if STAGE == 'play_cards':
			rand_arr.shuffle()
		for i in range(4):
			cards_player_node.get_child(i).position = Vector2(CARD_X[i + 2], CARD_Y['Player'])
			cards_computer_node.get_child(i).position = Vector2(CARD_X[rand_arr[i] + 2], CARD_Y['Computer'])
			
			if PLAYER_DEALER == false:
				cards_computer_node.get_child(i).show_back()
			
			cards_player_node.get_child(i).get_node('Overlay').visible = false
			cards_computer_node.get_child(i).get_node('Overlay').visible = false
			


func play_cards():
	## main loop of playing through the hand
	
	var go_player: bool
	var go_computer: bool
	#var i: int = 0
	
	## keep track of cards played this round, and determine the first one to play a card
	PLAYED_ALL = []
	PLAYER_TURN = not PLAYER_DEALER
		
	while HAND_PLAYER.size() != 0 or HAND_COMPUTER.size() != 0:
		#if i >= 20:
			#breakpoint
		if PLAYER_TURN == true and HAND_PLAYER.size() != 0 and go_player == false:
			## go_player is result of function that checks if any cards can be played (running total <= 31)
			## the function also applies the overlay to any cards that can't be played so that players can only select valid cards
			go_player = check_card_eligibility_player()
			if go_player == true:
				if go_computer == true:
					## add one point to player score
					update_game_log({'Go':1}, LAST_PLAYED)
					update_total_score(1, score_player if LAST_PLAYED=='Player' else score_computer)
					if GAME_OVER: return
				else:
					pass # go back to loop, computer turn is next
			else:
				await play_cards_player()
				calculate_points_in_play()
				LAST_PLAYED = 'Player'
				if GAME_OVER: return
		elif PLAYER_TURN == false and HAND_COMPUTER.size() != 0 and go_computer == false:
			## only in this block because the arrow_flip function is embedded in one of the functions specific to the player
			arrow_flip()
			
			## added this to reduce lag time when it would keep cycling back to the player
			## if it has already been determined that the player cannot play, remove the wait time
			## otherwise it is disorienting how quickly the computer plays, so adding in a bit of a pause
			if go_player == false:
				await get_tree().create_timer(1.5).timeout
				
			## unlike go_player where the function only checks eligibility, this function actually plays the cards and returns the boolean
			## based on whether or not any cards were actually played
			go_computer = await play_cards_computer()
			if go_computer == true:
				if go_player == true:
					## add one point to computer score
					update_game_log({'Go':1}, LAST_PLAYED)
					update_total_score(1, score_computer if LAST_PLAYED=='Computer' else score_player)
					if GAME_OVER: return
				else:
					pass
			else:
				calculate_points_in_play()
				LAST_PLAYED = 'Computer'
				if GAME_OVER: return
		
		## add a bit of a pause so the player can see it landed on 31, then reset the counter
		if score_played.text == '31' or (go_player and go_computer):
			await get_tree().create_timer(2.0).timeout
			await update_running_total('reset')
			go_player = false
			go_computer = false

		
		## used to apply the point for last card as well as bypass some unnecessary loops above if one player is out of cards
		if HAND_PLAYER.size() == 0 and HAND_COMPUTER.size() == 0:
			update_game_log({'Last card':1}, turn_display)
			update_total_score(1, score_total_current_player)
			if GAME_OVER: return
		elif HAND_PLAYER.size() == 0:
			go_player = true
			PLAYER_TURN = false
			go_computer = false
		elif HAND_COMPUTER.size() == 0:
			go_computer = true
			PLAYER_TURN = true
			go_player = false
		else:
			PLAYER_TURN = not PLAYER_TURN
			
		#i += 1

func calculate_points_in_play(test_cards = null):
	## Last Card and Go logic included in card playing loop
	var test_sum: int = 0
	var played_sum: int = 0
	
	## didn't necessarily need to create reversed copies of each array, but I found it easier to work with
	## particularly since .slice() kept giving me odd results
	var rev_all = PLAYED_ALL.duplicate()
	var rev_seq = PLAYED_ALL_SEQ.duplicate()
	
	if test_cards != null:
		for test_card in test_cards:
			rev_all.append(test_card[0])
			rev_seq.append(CARD_RANK[test_card[0]][1])
	
	rev_all.reverse()
	rev_seq.reverse()
	
	for i in rev_all:
		played_sum += CARD_RANK[str(i)][0]
		
	## landing on 15 or 31
	if played_sum == 15 or played_sum == 31:
		if test_cards == null:
			update_game_log({score_played.text: 2}, turn_display)
			update_total_score(2, score_total_current_player)
			if GAME_OVER: return
		else:
			test_sum += 2
		
	## pairs (includes 3 and 4 of a kind)
	## was just easier to keep it all labeled as Pairs, and technically it is a combination of multiple pairs
	if rev_all.size() >= 2:
		var pairs: int = 1
		for i in range(1, rev_seq.size()):
			if rev_all[i] == rev_all[i - 1]:
				pairs += 1
			else:
				break
		if pairs > 1:
			if test_cards == null:
				update_game_log({str(pairs) + ' of a kind': ((pairs ** 2) - pairs)}, turn_display)
				update_total_score(((pairs ** 2) - pairs), score_total_current_player)
				if GAME_OVER: return
			else:
				test_sum += ((pairs ** 2) - pairs)
			
	## runs
	if rev_seq.size() >= 3:
		for num_cards in range(rev_seq.size(), 2, -1):
			var run_len: int = 1
			var run_array: Array = []
			for i in range(0, num_cards):
				run_array.append(rev_seq[i])
			run_array.sort()
			
			for j in range(1, num_cards):
				if (run_array[j] - 1) == run_array[j - 1]:
					run_len += 1
				else:
					run_len = 1
					break
			
			if run_len >= 3:
				if test_cards == null:
					update_game_log({'Run': run_len}, turn_display)
					update_total_score(run_len, score_total_current_player)
					if GAME_OVER: return
				else:
					test_sum += run_len
				break
				
	if test_cards != null:
		return(test_sum)
			
						
func update_total_score(score, player_total):
	### update the scores and game log with point details
	### if a player hits 121, set GAME_OVER = true and end the game immediately
	player_total.text = str(min(int(player_total.text) + score, 121))
	if player_total.text == '121':
		if player_total == score_player:
			game_log.push_color(Color(PLAYER_COLOR['Player']))
			game_log.push_bold()
			game_log.add_text('YOU WIN!!\n')
			game_log.pop()
		else:
			game_log.push_color(Color(PLAYER_COLOR['Computer']))
			game_log.push_bold()
			game_log.add_text('YOU LOSE\n')
			game_log.pop()
		game_log.push_color(Color(PLAYER_COLOR['metadata']))
		game_log.add_text('-------------------------------------------\n')
		GAME_OVER = true
	
func play_cards_player():
	arrow_flip()
	await card_was_clicked
	await update_running_total(PLAYED_PLAYER[-1])
	PLAYED_ALL.append(PLAYED_PLAYER[-1][0])
	PLAYED_ALL_SEQ.append(CARD_RANK[PLAYED_PLAYER[-1][0]][1])

func play_cards_computer():
	## on Easy difficulty, Computer selects cards randomly
	var card: Area2D
	var played_card_offset: int = 4 - HAND_COMPUTER.size()
	var eligible_cards: Array
	var points: float
	var player_points_ev: float
	var max_points_ev: float
	var nextcard_odds: Dictionary
	var card_code: String
	
	eligible_cards = check_card_eligibility_computer()
	
	if eligible_cards.size() > 0:
		if DIFFICULTY == 'EASY':
			card_code = eligible_cards[randi() % eligible_cards.size()]
		elif DIFFICULTY == 'NORMAL':
			nextcard_odds = create_nextcard_probability_dict()
			max_points_ev = -999.00
			for test_card in eligible_cards:
				points = float(calculate_points_in_play([test_card]))
				
				player_points_ev = 0.00
				
				for key in CARD_RANK:
					if int(score_played.text) + CARD_RANK[test_card[0]][0] + CARD_RANK[key][0] <= 31:
						player_points_ev += (float(calculate_points_in_play([test_card, str(key)])) * nextcard_odds[key])
					
				if points - player_points_ev >= max_points_ev:
					max_points_ev = points - player_points_ev
					card_code = test_card
					
				print(test_card + ': ' + str(points - player_points_ev))
			
		PLAYED_COMPUTER.append(card_code)
		PLAYED_ALL.append(card_code[0])
		PLAYED_ALL_SEQ.append(CARD_RANK[card_code[0]][1])
		HAND_COMPUTER.erase(card_code)
			
		card = get_child_from_card_node(cards_computer_node, card_code)
		card.show_face()
		card.z_index = played_card_offset
		card.position = Vector2(CARD_X[0] + played_card_offset * 50, CARD_Y['Computer'])
			
		await update_running_total(PLAYED_COMPUTER[-1])
		
		return false
	else:
		return true
				
		
func check_card_eligibility_player():
	## check to see if any player cards can legally be played
	var card: Area2D
	var go_bool: bool
	
	go_bool = true
	for card_code in HAND_PLAYER:
		card = get_child_from_card_node(cards_player_node, card_code)
		if CARD_RANK[card_code[0]][0] > 31 - int(score_played.text):
			card.get_node('Overlay').visible = true
		else:
			card.get_node('Overlay').visible = false
			go_bool = false
			
	return go_bool
			
func check_card_eligibility_computer():
	## check to see if any computer cards can legally be played
	var eligible: Array = []
	for card_code in HAND_COMPUTER:
		if CARD_RANK[card_code[0]][0] <= 31 - int(score_played.text):
			eligible.append(card_code)
			
	return eligible
			
func score_hands():	
	## determine score order of hands/crib based on dealer
	if PLAYER_DEALER == true:
		await score_hand_computer()
		if GAME_OVER: return
		await score_hand_player()
		if GAME_OVER: return
	else:
		await score_hand_player()
		if GAME_OVER: return
		await score_hand_computer()
		if GAME_OVER: return
		
		
func score_hand_player():
	var score_dict: Dictionary
	score_entry_toggle()
	var player_score = await score_entry.text_submitted
	score_entry_toggle()
	
	var stage_hand = PLAYED_PLAYER if STAGE == 'score_hands' else CRIB
	score_dict = calculate_hand_score(stage_hand)
			
	## if player entered correct score, apply it and not require confirmation
	## if not, apply appropriate penalty and require confirmation before proceeding 
	if int(player_score) == score_dict['Total']:
		update_game_log(score_dict, 'Player')
		update_total_score(score_dict['Total'], score_player)
	else:
		if int(player_score) > score_dict['Total']:
			show_hand_score(score_dict, 'Player', true)
			update_total_score(score_dict['Total'], score_player)
			
			update_game_log({'Overcounted': 2}, 'Computer')
			update_total_score(2, score_computer)
		elif int(player_score) < score_dict['Total']:
			score_dict['Muggins'] = -(score_dict['Total'] - int(player_score))
			score_dict['Total'] += score_dict['Muggins']
			show_hand_score(score_dict, 'Player', true)
			update_total_score(score_dict['Total'], score_player)
			
			update_game_log({'Muggins': -score_dict['Muggins']}, 'Computer')
			update_total_score(-score_dict['Muggins'], score_computer)
			
		await ok_to_continue() 
	
	if STAGE == 'score_hands':
		discard_all_cards(cards_player_node)
		if PLAYER_DEALER == false:
			for i in range(4):
				cards_computer_node.get_child(i).show_face()
	
func score_hand_computer():
	var score_dict: Dictionary
	
	score_dict = calculate_hand_score(PLAYED_COMPUTER)
	await show_hand_score(score_dict, 'Computer')
	update_total_score(score_dict['Total'], score_computer)
	discard_all_cards(cards_computer_node)
	
func score_crib():
	var score_dict: Dictionary
	
	score_dict = calculate_hand_score(CRIB)
	
	if PLAYER_DEALER == true:
		await score_hand_player()
	else:
		await await show_hand_score(score_dict, dealer_display)
		update_total_score(score_dict['Total'], score_computer)
		
	discard_all_cards(cards_crib_node)
	
func calculate_hand_score(hand, cut_card=CARD_CUT):
	
	var pips: Dictionary
	var suits: Dictionary
	var seq: Array
	var ranks: Array
	var tmp_calc: int
	
	var score: Dictionary
	var run_len: int = 0
	var run_mult: int = 1
	var run_dict: Dictionary
	
	if cut_card != null:
		pips = {cut_card[0]: 1}
		seq = [CARD_RANK[cut_card[0]][1]]
		ranks = [CARD_RANK[cut_card[0]][0]]
	else:
		cut_card = 'XX'
		pips = {'X': 1}
		seq = [100]
		ranks = [100]
		
		
	## various arrays of hand (+ cut card) that just made the logic below easier to code
	for card in hand:
		pips[card[0]] = pips.get(card[0], 0) + 1
		suits[card[1]] = suits.get(card[1], 0) + 1
		seq.append(CARD_RANK[card[0]][1])
		ranks.append(CARD_RANK[card[0]][0])

	seq.sort()
	ranks.sort()
	
	## check for 15s
	tmp_calc = 0
	for i in range(1, 1 << 5):
		var sumval = 0
		for j in range(5):
			if i & (1 << j):
				sumval += ranks[j]
		
		if sumval == 15:
			tmp_calc += 2
	
	if tmp_calc > 0:
		score['Fifteens'] = tmp_calc
	
	## check for pairs, etc.
	tmp_calc = 0
	for key in pips.keys():
		tmp_calc += (pips[key] ** 2 - pips[key])
	
	if tmp_calc > 0:
		score['Pairs'] = tmp_calc
		
	## check for runs
	tmp_calc = 0
	#for i in range(1, 5):
		#run_dict[seq[i]] += run_dict.get(seq[i], 1)
		#
	for i in range(1, 5):
		if seq[i] == seq[i - 1]:
			if i >= 2:
				if seq[i] == seq[i - 2]:
					run_mult += 1
				else:
					run_mult *= 2
			else:
				run_mult += 1
		elif (seq[i] - seq[i - 1]) == 1:
			run_len += 1
		else:
			if run_len >= 2:
				tmp_calc += ((run_len + 1) * run_mult)
			run_len = 0
			run_mult = 1
	
	if run_len >= 2:
		tmp_calc += ((run_len + 1) * run_mult)
	
	if tmp_calc > 0:
		score['Runs'] = tmp_calc
		
	## check for suits
	## flush only scored in crib if cut card is of the same suit
	tmp_calc = 0
	if suits.size() == 1:
		tmp_calc = 4
		
		if suits.keys()[0] == cut_card[1]:
			tmp_calc += 1
		else:
			if STAGE == 'score_crib':
				tmp_calc = 0
			
	if tmp_calc > 0:
		score['Flush'] = tmp_calc
		
	## check for Jack
	for card in hand:
		if card[0] == 'J' and card[1] == cut_card[1]:
			score['Nobs'] = 1
			
			
	tmp_calc = 0
	for key in score.keys():
		tmp_calc += score[key]
		
	score['Total'] = tmp_calc
	
	return score


## everything below this point is a helper function that is pretty self-explanatory by function name alone
## I might just be lazy right now though, but I'll add comments if something breaks

func ok_to_continue():
	table_button.text = "OK"
	table_button.disabled = false
	table_button.visible = true
	await table_button.pressed
	table_button.disabled = true
	table_button.visible = false
	
	
func get_child_from_card_node(node, card_str):
	for j in node.get_children():
		if j.code == str(card_str):
			return j

func play_cards_display_toggle(off_override=false):
	if off_override == true:
		label_played.visible = false
		score_played.visible = false
		table_arrow.visible = false
	else:
		label_played.visible = not label_played.visible
		score_played.visible = not score_played.visible
		table_arrow.visible = not table_arrow.visible
		arrow_flip()
	
	if score_played.visible == true:
		score_played.text = '0'
	
func arrow_flip():
	table_arrow.flip_v = PLAYER_TURN

func score_entry_toggle():
	var hand_name: String
	hand_name = 'Player ' if STAGE == 'score_hands' else 'Crib '
	label_score_entry.text = hand_name + 'point entry'
	
	label_score_entry.visible = not label_score_entry.visible
	score_entry.visible = not score_entry.visible
	
	if score_entry.visible == true:
		score_entry.release_focus()
		score_entry.clear()
		await get_tree().process_frame
		score_entry.grab_focus()

func update_game_log(score_dict, player):
	var indent: String
		
	game_log.push_color(Color(PLAYER_COLOR[player]))
	if 'Total' in score_dict:
		var stage = 'hand' if STAGE == 'score_hands' else 'crib'
		game_log.add_text(player + ' ' + stage + ' total: ' + str(score_dict['Total']) + '\n')
		indent = '      '
	else:
		indent = ''
		
	for key in score_dict:
		if key != 'Total':
			game_log.add_text(indent + key + ': ' + str(score_dict[key]) + '\n')
	
	# new line for game log readability
	for i in ['Total', 'Last card', 'Muggins', 'Overcounted']:
		if i in score_dict:
			game_log.add_text('\n')
			break
		
	
func show_hand_score(score_dict, player, bln_error=false):
	update_game_log(score_dict, player)
	label_scoreround.visible = true
	score_round.visible = true
	
	var round_name: String
	round_name = ' Round ' if STAGE == 'score_hands' else ' Crib '
	
	if bln_error == true:
		score_round.text = str(score_dict['Total'] - score_dict.get('Muggins', 0))
		label_scoreround.text = player + round_name + ' Actual Score'
	else:
		score_round.text = str(score_dict['Total'])
		label_scoreround.text = player + round_name + 'Score'
	await ok_to_continue()
	
	label_scoreround.visible = false
	score_round.visible = false
		
func update_running_total(card_code):
	var total_score: int
	var card_score: int
	
	if card_code == 'reset':
		score_played.text = '0'
		for node in [cards_computer_node, cards_player_node]:
			for card in node.get_children():
				if card.code in PLAYED_PLAYER or card.code in PLAYED_COMPUTER:
					card.get_node('Overlay').visible = true
		
		PLAYED_ALL = []
		PLAYED_ALL_SEQ = []
	else:
		total_score = int(score_played.text)
		card_score = CARD_RANK[card_code[0]][0]
	
		score_played.text = str(total_score + card_score)			 
	
	
func discard_all_cards(node=null):
	var hands: Array
	
	if node == null:
		hands = [cards_player_node, cards_computer_node, cards_crib_node, cards_cut_node]
	else:
		hands = [node]
		
	for hand in hands:
		for n in hand.get_children():
			hand.remove_child(n)
			n.queue_free()
			
	if node == null:
		HAND_PLAYER = []
		HAND_COMPUTER = []
		PLAYED_PLAYER = []
		PLAYED_COMPUTER = []
		PLAYED_ALL = []
		PLAYED_ALL_SEQ = []
		CRIB = []
		
func show_menu():
	$Table.visible = false
	$Menu.visible = true
	$Scenario.visible = false
	
	$Menu.display_menu_cards()
	
func show_table():
	$Table.visible = true
	$Menu.visible = false
	$Scenario.visible = false
	
	table_button.visible = false
	button_quit.visible = false
	
	play_cards_display_toggle(true)
	
func show_scenario_mode():
	$Table.visible = false
	$Menu.visible = false
	$Scenario.visible = true
	
	$Scenario/Toggle_CribRecipient.button_pressed = false
	PLAYER_DEALER = true
	
	await button_was_clicked
