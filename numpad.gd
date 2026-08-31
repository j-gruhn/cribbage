extends Control

signal submitted(value: int)

@onready var display: Label = $PanelContainer/VBoxContainer/Display

var current_text: String = ""

func _ready():
	for i in range(10):
		var btn = get_node("PanelContainer/VBoxContainer/GridContainer/Btn_" + str(i))
		btn.pressed.connect(_on_digit_pressed.bind(str(i)))
	$PanelContainer/VBoxContainer/GridContainer/Btn_Back.pressed.connect(_on_backspace_pressed)
	$Btn_Confirm.pressed.connect(_on_confirm_pressed)

func _on_digit_pressed(digit: String):
	if current_text.length() < 2:  # max cribbage hand/crib score is 29
		current_text += digit
		display.text = current_text

func _on_backspace_pressed():
	current_text = current_text.substr(0, current_text.length() - 1)
	display.text = current_text

func _on_confirm_pressed():
	var value = int(current_text) if current_text != "" else 0
	reset()
	submitted.emit(value)

func reset():
	current_text = ""
	display.text = ""
	
func _input(event):
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			_on_digit_pressed(str(event.keycode - KEY_0))
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_KP_0 and event.keycode <= KEY_KP_9:
			_on_digit_pressed(str(event.keycode - KEY_KP_0))
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BACKSPACE:
			_on_backspace_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_confirm_pressed()
			get_viewport().set_input_as_handled()
