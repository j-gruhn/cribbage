extends Node2D


var DECK: Array
var DECK_SHUFFLED: Array = []
var CARD_RANK: Dictionary
var CARD_X: Dictionary
var CARD_Y: Dictionary
var PLAYER_COLOR: Dictionary

var HAND_PLAYER: Array = []
var HAND_COMPUTER: Array = []
var PLAYED_PLAYER: Array = []
var PLAYED_COMPUTER: Array = []
var CRIB: Array = []
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

var card_cut: String
var card_code: String

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

func _ready():
	play_cards_display_toggle()
	
	prep_playing_field()
	shuffle_deck()
	play_game()
	
func play_game():
	cut_for_deal()
	
	table_button.visible = true
	table_button.text = "Deal"
	table_arrow.visible = false
	
	await table_button.pressed
	discard_all_cards()
	
	#while true:
	deal()
	print(HAND_PLAYER)
	print(HAND_COMPUTER)
	print(card_cut)
	
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
	
	STAGE = 'score_hands'
	play_cards_display_toggle()
	rearrange_cards()
	await score_hands()
	
	STAGE = 'score_crib'
	populate_crib()
	await score_crib()
	
	discard_all_cards(cards_cut_node)

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
	
	PLAYER_COLOR = {
		'Player': '0000ff',
		'Computer': 'ff0000'
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
			game_log.add_text(dealer_display + ' wins the deal\n')
			break
	
	
func deal():
	var hand_1: Array = []
	var hand_2: Array = []

	for i in range(0, 12, 2):
		hand_1.append(DECK_SHUFFLED[i])
		hand_2.append(DECK_SHUFFLED[i+1])

	if PLAYER_DEALER == true:
		HAND_PLAYER = hand_1
		HAND_COMPUTER = hand_2
	else:
		HAND_PLAYER = hand_2
		HAND_COMPUTER = hand_1

	card_cut = DECK_SHUFFLED[randi() % (DECK.size() - 12) + 12]
	
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
	card.code = card_cut
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
	
	for card_code in CRIB:
		var card = card_scene.instantiate()
		card.code = card_code
		cards_crib_node.add_child(card)
		card.show_face()
		
	rearrange_cards()
	
func show_cut_card():
	for j in cards_cut_node.get_children():
		j.show_face()
	
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
	var i: int = 0
	
	PLAYER_TURN = not PLAYER_DEALER
		
	while HAND_PLAYER.size() != 0 or HAND_COMPUTER.size() != 0:
		if i >= 20:
			breakpoint
		if PLAYER_TURN == true and HAND_PLAYER.size() != 0 and go_player == false:
			go_player = check_card_eligibility_player()
			if go_player == true:
				if go_computer == true:
					## add one point to player score
					await update_running_total('reset')
					go_player = false
					go_computer = false
				else:
					pass # go back to loop, computer turn is next
			else:
				await play_cards_player()
		elif PLAYER_TURN == false and HAND_COMPUTER.size() != 0 and go_computer == false:
			arrow_flip()
			await get_tree().create_timer(1.5).timeout
			go_computer = await play_cards_computer()
			if go_computer == true:
				if go_player == true:
					## add one point to computer score
					await update_running_total('reset')
					go_player = false
					go_computer = false
				else:
					pass # go back to loop, player turn is next
					
		if HAND_PLAYER.size() == 0:
			go_player = true
			PLAYER_TURN = false
			go_computer = false
		elif HAND_COMPUTER.size() == 0:
			go_computer = true
			PLAYER_TURN = true
			go_player = false
		else:
			PLAYER_TURN = not PLAYER_TURN
			
		i += 1
		
func play_cards_player():
	arrow_flip()
	await card_was_clicked
	await update_running_total(PLAYED_PLAYER[-1])

func play_cards_computer():
	var card: Area2D
	var played_card_offset: int = 4 - HAND_COMPUTER.size()
	var eligible_cards: Array
	
	eligible_cards = check_card_eligibility_computer()
	
	if eligible_cards.size() > 0:
		if DIFFICULTY == 'EASY':
			card_code = eligible_cards[randi() % eligible_cards.size()]
			
		PLAYED_COMPUTER.append(card_code)
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
		await score_hand_player()
	else:
		await score_hand_player()
		await score_hand_computer()
		
		
		
func score_hand_player():
	score_entry_toggle()
	
	var player_score = await score_entry.text_submitted
	
	### check score, if incorrect add something here to adjust scores
	### else, use line below
	score_player.text = str(min(int(score_player.text) + int(score_entry.text), 121))
	discard_all_cards(cards_player_node)
	score_entry_toggle()
	
	
func score_hand_computer():
	await show_hand_score()
	discard_all_cards(cards_computer_node)
	
func ok_to_continue():
	table_button.text = "OK"
	table_button.disabled = false
	table_button.visible = true
	await table_button.pressed
	table_button.disabled = true
	table_button.visible = false
	
	
func score_crib():
	
	if PLAYER_DEALER == true:
		await score_hand_player()
	else:
		await score_hand_computer()
		
	discard_all_cards(cards_crib_node)
	
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
		
func show_hand_score(score=0):
	label_scoreround.visible = true
	score_round.visible = true
	
	var round_name: String
	round_name = ' Round ' if STAGE == 'score_hands' else ' Crib '
	label_scoreround.text = turn_display + round_name + 'Score'
	score_round.text = str(score)
	await ok_to_continue()
	
	label_scoreround.visible = false
	score_round.visible = false
		
func update_running_total(card_code):
	var total_score: int
	var card_score: int
	
	if card_code == 'reset':
		score_played.text = '0'
	else:
		total_score = int(score_played.text)
		card_score = CARD_RANK[card_code[0]][0]
	
		score_played.text = str(total_score + card_score)
		
		if score_played.text == '31':
			await get_tree().create_timer(2.0).timeout
			score_played.text = '0'
			 
	
	
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
