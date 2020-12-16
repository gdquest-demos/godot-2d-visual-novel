extends Node

var dialogue_data = [
	{
		character = "Sofia",
		expression = "smiling",
		line = "Hi there! My name's Sofia. How about you?",
	},
	{
		character = "Dan",
		expression = "neutral",
		line = "Hey, I'm Dan.",
	}
]

func _ready() -> void:
	run_dialogue_sequence()


func run_dialogue_sequence() -> void:
	for node in dialogue_data:
		$TextBox.display(node.line, node.character)
		yield($TextBox, "next_requested")
	$TextBox.hide()
