extends Node

var dialogue_data = {
	1: {
		character = "bear",
		line = "Hi there! My name's Bear. How about you?",
	},
	2: {
		character = "cat",
		line = "Hey, I'm Cat.",
	},
	3: {
		choice = [
			Choice.new("Start over", 1),
			Choice.new("Continue", 4),
			Choice.new("Jump ahead", 5)
		]
	},
	4: {
		character = "bear",
		line = "Well, let's continue."
	},
	5: {
		character = "cat",
		line = "Did you jump ahead?"
	},
}

onready var _text_box := $TextBox
onready var _character_displayer := $CharacterDisplayer


func _ready() -> void:
	run_dialogue_sequence()


func run_dialogue_sequence() -> void:
	var key := 1
	while dialogue_data.has(key):
		var node: Dictionary = dialogue_data[key]
		var character: Character
		if node.has("character"):
			character = CharactersDB.get_character(node.character)
		
		# Choice.
		if "choice" in node:
			_text_box.display_choice(node.choice)
			key = yield(_text_box, "choice_made")
		# Normal text reply.
		else:
			_text_box.display(node.line, character.display_name)
			_character_displayer.display(node.character)
			yield(_text_box, "next_requested")
			key += 1
	_text_box.hide()
	_character_displayer.hide()
