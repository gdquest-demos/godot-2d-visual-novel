extends Node

var dialogue_data = [
	{
		character = "bear",
		line = "Hi there! My name's Bear. How about you?",
	},
	{
		character = "cat",
		line = "Hey, I'm Cat.",
	}
]

onready var _text_box := $TextBox
onready var _character_displayer := $CharacterDisplayer


func _ready() -> void:
	run_dialogue_sequence()


func run_dialogue_sequence() -> void:
	for node in dialogue_data:
		var character: Character = CharactersDB.get_character(node.character)
		_text_box.display(node.line, character.display_name)
		_character_displayer.display(node.character)
		yield(_text_box, "next_requested")
	_text_box.hide()
	_character_displayer.hide()
