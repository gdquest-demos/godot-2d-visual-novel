extends Node

var lexer := SceneLexer.new()

func _ready() -> void:
	var text := lexer.read_file_content("res://Parser/test-scene.txt")
	var tokens = lexer.tokenize(text)
	print(tokens)
