extends Node2D


var DECK: Array
var DECK_SHUFFLED: Array = []
var CARD_RANK: Dictionary
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


@export var DIFFICULTY: String = 'EASY'
@export var STAGE: String

var card_code: String
var round_count: int

signal card_was_clicked


#@onready var card = $Card
@onready var cards_player_node = $Cards_Player
@onready var cards_computer_node = $Cards_Computer
@onready var cards_crib_node = $Cards_Crib
@onready var cards_cut_node = $Cards_Cut

@onready var game_log = $Table/GameLog
@onready var table_button = $Table/Button
@onready var table_arrow = $Table/NextArrow
@onready var label_played = $Table/Label_RunningTotal
@onready var score_played = $Table/Score_RunningTotal
@onready var label_score_entry = $Table/Label_ScoreEntry
@onready var score_entry = $Table/ScoreEntry
@onready var score_player = $Table/Score_Player
@onready var score_computer = $Table/Score_Computer
@onready var score_round = $Table/Score_Round
@onready var label_scoreround = $Table/Label_ScoreRound

var card_scene = preload("res://card.tscn")

var score_total_current_player: Variant:
	get:
		return score_player if PLAYER_TURN else score_computer
		
var PLAYER_COLOR: Dictionary = {
	'Player': '8499de', 
	'Computer': 'ee8f06',
	'metadata': 'dde0e9'
}

func _ready():
	play_cards_display_toggle()
	prep_playing_field()
	table_arrow.visible = false
	
	while true:
		await play_game()
		
		table_button.visible = true
		table_button.text = 'Play again'
		table_button.disabled = false
		await table_button.pressed
		
	
func play_game():
	shuffle_deck()
	cut_for_deal()
	
	table_button.visible = true
	table_button.text = "Deal"
	await table_button.pressed
	discard_all_cards()
	
	round_count = 0
	while not GAME_OVER:
		round_count += 1
		game_log.push_color(Color(PLAYER_COLOR['metadata']))
		game_log.add_text('-------------------------------------------\n')
		game_log.add_text('Round ' + str(round_count) + '\n')
		game_log.push_color(Color(PLAYER_COLOR['Player']))
		game_log.add_text(dealer_display + ' deals\n\n')
		
		shuffle_deck()
		deal()
		print(HAND_PLAYER)
		print(HAND_COMPUTER)
		print(CARD_CUT)
		
		STAGE = 'crib_selection'
		select_cards_for_crib_player()
		await table_button.pressed
		select_cards_for_crib_computer()
		place_crib()
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
	
	for suit in ['C','D','H','S']:
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
	var cut_winner: String
	
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
	arr.sort_custom(func(a,b): return CARD_RANK[a[0]][1] < CARD_RANK[b[0]][1])
	return arr
		
func deal():
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
	
	#HAND_PLAYER = ['5S', '5D', '5C', 'JH', 'KD','KH']
	#HAND_COMPUTER = ['AC','AD','AH','AS','KC','KS']
	#HAND_COMPUTER = ['5S', '5D', '5C', '5C', '5C','5C']
	#CARD_CUT = '5H'
	
	# show player's cards (face up)
	for i in range(HAND_PLAYER.size()):
		var card = card_scene.instantiate()
		card.code = HAND_PLAYER[i]
		cards_player_node.add_child(card)
		card.position = Vector2(CARD_X[i], CARD_Y['Player'])
		card.show_face()
		card.selected = false

	# show computer's cards (face down)
	for i in range(HAND_COMPUTER.size()):
		var card = card_scene.instantiate()
		card.code = HAND_COMPUTER[i]
		cards_computer_node.add_child(card)
		card.position = Vector2(CARD_X[i], CARD_Y['Computer'])
		card.show_back()
		card.selected = false
		
	var card = card_scene.instantiate()
	card.code = CARD_CUT
	cards_cut_node.add_child(card)
	card.position = Vector2(CARD_X[4.5], CARD_Y['Cut'])
	card.show_back()
		
func select_cards_for_crib_player():
	
	table_button.text = "Send cards to " + dealer_display + "'s crib"
	table_button.disabled = true
	table_button.visible = true
	
func select_cards_for_crib_computer():	
	var card: Area2D
	table_button.visible = false
	
	if DIFFICULTY == 'EASY':
		for i in range(2):
			card_code = HAND_COMPUTER[randi() % HAND_COMPUTER.size()]
			CRIB.append(card_code)
			HAND_COMPUTER.erase(card_code)
			card = get_child_from_card_node(cards_computer_node, card_code)
			cards_computer_node.remove_child(card)
			card.queue_free()
					
func place_crib():	
	## dummy card to represent dealer
	var card = card_scene.instantiate()
	cards_crib_node.add_child(card)
	card.position = Vector2(CARD_X[6], CARD_Y['Player_Crib' if PLAYER_DEALER else 'Computer_Crib'])
	card.show_back()
	
func populate_crib():
	discard_all_cards(cards_crib_node)
	
	CRIB = sort_card_array(CRIB)
	
	for card_code in CRIB:
		var card = card_scene.instantiate()
		card.code = card_code
		cards_crib_node.add_child(card)
		card.show_face()
		
	rearrange_cards()
	
func show_cut_card():
	for j in cards_cut_node.get_children():
		j.show_face()
		
		if j.code[0] == 'J':
			update_game_log({'Heels': 2}, dealer_display)
			update_total_score(2, score_total_current_player)
			if GAME_OVER: return
	
func rearrange_cards():
	if STAGE == 'score_crib':
		for i in range(4):
			cards_crib_node.get_child(i).position = Vector2(CARD_X[i + 2], CARD_Y[dealer_display])
	else:
		for i in range(4):
			cards_player_node.get_child(i).position = Vector2(CARD_X[i + 2], CARD_Y['Player'])
			cards_computer_node.get_child(i).position = Vector2(CARD_X[i + 2], CARD_Y['Computer'])


func play_cards():
	var go_player: bool
	var go_computer: bool
	#var i: int = 0
	
	PLAYED_ALL = []
	PLAYER_TURN = not PLAYER_DEALER
		
	while HAND_PLAYER.size() != 0 or HAND_COMPUTER.size() != 0:
		#if i >= 20:
			#breakpoint
		if PLAYER_TURN == true and HAND_PLAYER.size() != 0 and go_player == false:
			go_player = check_card_eligibility_player()
			if go_player == true:
				if go_computer == true:
					## add one point to player score
					update_game_log({'Go':1}, 'Player')
					update_total_score(1, score_player)
					if GAME_OVER: return
				else:
					pass # go back to loop, computer turn is next
			else:
				await play_cards_player()
				calculate_points_in_play()
				LAST_PLAYED = 'Player'
				if GAME_OVER: return
		elif PLAYER_TURN == false and HAND_COMPUTER.size() != 0 and go_computer == false:
			arrow_flip()
			await get_tree().create_timer(1.5).timeout
			go_computer = await play_cards_computer()
			if go_computer == true:
				if go_player == true:
					## add one point to computer score
					update_game_log({'Go':1}, 'Computer')
					update_total_score(1, score_computer)
					if GAME_OVER: return
				else:
					pass
			else:
				calculate_points_in_play()
				LAST_PLAYED = 'Computer'
				if GAME_OVER: return
		
		if score_played.text == '31' or (go_player and go_computer):
			await get_tree().create_timer(2.0).timeout
			await update_running_total('reset')
			go_player = false
			go_computer = false

		
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

func calculate_points_in_play():
	#print(PLAYED_ALL_SEQ)
	var rev_all = PLAYED_ALL.duplicate()
	var rev_seq = PLAYED_ALL_SEQ.duplicate()
	rev_all.reverse()
	rev_seq.reverse()
		
	if score_played.text in ['15', '31']:
		update_game_log({score_played.text: 2}, turn_display)
		update_total_score(2, score_total_current_player)
		if GAME_OVER: return
	if PLAYED_ALL.size() >= 2:
		var pairs: int = 1
		for i in range(1, rev_seq.size()):
			if rev_all[i] == rev_all[i - 1]:
				pairs += 1
			else:
				break
		if pairs > 1:
			update_game_log({str(pairs) + ' of a kind': ((pairs ** 2) - pairs)}, turn_display)
			update_total_score(((pairs ** 2) - pairs), score_total_current_player)
			if GAME_OVER: return
	if PLAYED_ALL_SEQ.size() >= 3:
		for num_cards in range(rev_seq.size(), 2 -1):
			var run_len: int = 1
			var run_array: Array = []
			for i in range(0, num_cards):
				run_array.append(rev_seq[i])
			run_array.sort()
			
			for j in range(1, num_cards):
				#print(run_array[j] - 1)
				#print(run_array[j - 1])
				if (run_array[j] - 1) == run_array[j - 1]:
					run_len += 1
				else:
					run_len = 1
			#print(' ')
			
			if run_len >= 3:
				update_game_log({'Run': run_len}, turn_display)
				update_total_score(run_len, score_total_current_player)
				if GAME_OVER: return
				break
			
						
func update_total_score(score, player_total):
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
	var card: Area2D
	var played_card_offset: int = 4 - HAND_COMPUTER.size()
	var eligible_cards: Array
	
	eligible_cards = check_card_eligibility_computer()
	
	if eligible_cards.size() > 0:
		if DIFFICULTY == 'EASY':
			card_code = eligible_cards[randi() % eligible_cards.size()]
			
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
	var eligible: Array = []
	for card_code in HAND_COMPUTER:
		if CARD_RANK[card_code[0]][0] <= 31 - int(score_played.text):
			eligible.append(card_code)
			
	return eligible
			
func score_hands():	
		
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
			
	if int(player_score) == score_dict['Total']:
		update_game_log(score_dict, 'Player')
		update_total_score(score_dict['Total'], score_player)
	else:
		if int(player_score) > score_dict['Total']:
			show_hand_score(score_dict, 'Player')
			update_total_score(score_dict['Total'], score_player)
			
			update_game_log({'Overcounted': 2}, 'Computer')
			update_total_score(2, score_computer)
		elif int(player_score) < score_dict['Total']:
			score_dict['Muggins'] = -(score_dict['Total'] - int(player_score))
			score_dict['Total'] += score_dict['Muggins']
			show_hand_score(score_dict, 'Player')
			update_total_score(score_dict['Total'], score_player)
			
			update_game_log({'Muggins': -score_dict['Muggins']}, 'Computer')
			update_total_score(-score_dict['Muggins'], score_computer)
			
		await ok_to_continue() 
	
	if STAGE == 'score_hands':
		discard_all_cards(cards_player_node)
	
func score_hand_computer():
	var score_dict: Dictionary
	
	score_dict = calculate_hand_score(PLAYED_COMPUTER)
	await show_hand_score(score_dict, 'Computer')
	update_total_score(score_dict['Total'], score_computer)
	discard_all_cards(cards_computer_node)
	
func score_crib():
	var score: int
	var score_dict: Dictionary
	
	score_dict = calculate_hand_score(CRIB)
	score = score_dict['Total']
	
	if PLAYER_DEALER == true:
		await score_hand_player()
	else:
		await await show_hand_score(score_dict, dealer_display)
		update_total_score(score_dict['Total'], score_computer)
		
	discard_all_cards(cards_crib_node)
	
func calculate_hand_score(hand):
	var pips: Dictionary = {CARD_CUT[0]: 1}
	var suits: Dictionary
	var seq: Array = [CARD_RANK[CARD_CUT[0]][1]]
	var ranks: Array = [CARD_RANK[CARD_CUT[0]][0]]
	var tmp_calc: int
	
	var score: Dictionary
	var run_len: int = 0
	var run_mult: int = 1
	
	for card in hand:
		pips[card[0]] = pips.get(card[0], 0) + 1
		suits[card[1]] = suits.get(card[1], 0) + 1
		seq.append(CARD_RANK[card[0]][1])
		ranks.append(CARD_RANK[card[0]][0])

	seq.sort()
	print(seq)
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
	for i in range(1, 5):
		if seq[i] == seq[i - 1]:
			run_mult *= 2
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
	tmp_calc = 0
	if suits.size() == 1:
		tmp_calc = 4
		
		if suits.keys()[0] == CARD_CUT[1]:
			tmp_calc += 1
		else:
			if STAGE == 'score_crib':
				tmp_calc = 0
			
	if tmp_calc > 0:
		score['Flush'] = tmp_calc
		
	## check for Jack
	for card in hand:
		if card[0] == 'J' and card[1] == CARD_CUT[1]:
			score['Nobs'] = 1
			
			
	tmp_calc = 0
	for key in score.keys():
		tmp_calc += score[key]
		
	score['Total'] = tmp_calc		
	
	return score

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

func play_cards_display_toggle():
	label_played.visible = not label_played.visible
	score_played.visible = not score_played.visible
	
	if score_played.visible == true:
		score_played.text = '0'
	
	arrow_flip()	
	table_arrow.visible = not table_arrow.visible
	
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
		
	
func show_hand_score(score_dict, player):
	update_game_log(score_dict, player)
	label_scoreround.visible = true
	score_round.visible = true
	
	var round_name: String
	round_name = ' Round ' if STAGE == 'score_hands' else ' Crib '
	label_scoreround.text = player + round_name + 'Score'
	score_round.text = str(score_dict['Total'])
	await ok_to_continue()
	
	label_scoreround.visible = false
	score_round.visible = false
		
func update_running_total(card_code):
	var total_score: int
	var card_score: int
	
	if card_code == 'reset':
		score_played.text = '0'
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
