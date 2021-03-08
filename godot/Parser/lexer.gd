class_name Lexer
extends Reference


class Token:
	var type: String

	var value = ""

	func _init(type: String, value) -> void:
		self.type = type
		self.value = value

	func _to_string() -> String:
		return "{ type = \"%s\", value = \"%s\" }" % [self.type, self.value]

# Class to control the process of lexing through the script
class DialogueScript:
	var text: String

	var current_index := 0

	var current_indent_level := 0

	var length := 0

	func _init(text: String) -> void:
		self.text = text
		self.length = len(text)

	# Returns the character at the current lexer position
	func current() -> String:
		return self.text[self.current_index]

	# Returns the previously read character
	func previous() -> String:
		if self.current_index > 0:
			return self.text[self.current_index - 1]
		else:
			return ""

	# Advances the current lexer position by one and returns the character at the new position
	func move_next() -> String:
		if self.current_index + 1 < len(text):
			self.current_index += 1
			return self.text[self.current_index]
		else:
			push_error("End of File encountered. Cannot move next.")
			return ""

	# Decrement the current lexer position and returns the character at that position
	func move_previous() -> String:
		if self.current_index - 1 >= 0:
			self.current_index -= 1
			return self.text[self.current_index]
		else:
			push_error("Can't go back beyond the first character of the script")
			return ""

	# Returns the character at the next lexer position without advancing the current lexer position
	func peek() -> String:
		if self.current_index + 1 < len(text):
			return text[self.current_index + 1]
		else:
			push_error("End of File encountered. Cannot peek.")
			return ""

	func is_end_of_file() -> bool:
		return self.current_index == len(text) - 1


# Reserved keywords for functions
const FunctionKeywords := [
	"background",
	"mark",
	"scene",
	"pass",
	"jump",
	"transition",
	"set",
]

const TokenTypes := {
	SYMBOL = "Symbol",
	FUNCTION = "Function",
	STRING_LITERAL = "String",
	CHOICE = "Choice",
	IF = "If",
	ELIF = "Elif",
	ELSE = "Else",
	BEGIN_BLOCK = "BeginBlock",
	END_BLOCK = "EndBlock",
	NEWLINE = "Newline",
	COMMENT = "Comment",
}

# Only one character for the OR and AND operators so we can match with the lexer's current character
const BooleanOperators := {
	NOT = "!",
	AND = "&",
	OR = "|"
	}

# Reads the text script, tokenizes it, then returns the tokens
func read_script(path: String) -> Array:
	var file := File.new()

	if not file.file_exists(path):
		push_error("Could not find the script with path: %s" % path)
		return []

	file.open(path, File.READ)
	var script := file.get_as_text()
	file.close()

	return tokenize(script)


func tokenize(input: String) -> Array:
	var script := DialogueScript.new(input)

	var tokens := []

	while not script.is_end_of_file():
		var character: String = script.current()

		if character == " ":
			pass
		elif character == "\n":  # Add the NEWLINE token and handle indentation
			tokens.append(Token.new(TokenTypes.NEWLINE, ""))

			# Get the indentation level
			var line_indent_level := 0
			while script.peek() == "\t":
				line_indent_level += 1
				script.move_next()

			if not script.peek() in [" ", "\n"]: # Not an empty line
			  if line_indent_level > script.current_indent_level:
				  push_error("Invalid indent level")
			  elif line_indent_level == script.current_indent_level:
				  pass
			  else:
				  # Emit token(s) indicating end of a block if the line's indent is lower than the currently tracked indent level
				  for i in range(script.current_indent_level - line_indent_level):
					  script.current_indent_level -= 1
					  tokens.append(Token.new(TokenTypes.END_BLOCK, ""))
		elif character in BooleanOperators.values():
			if character != BooleanOperators.NOT:
				# Find the other matching character for || or &&
				if script.peek() == BooleanOperators.AND or script.peek() == BooleanOperators.OR:
					character += script.move_next()
				else:
					push_error("Could not find matching character for one of the || or && boolean operators")

			tokens.append(Token.new(character, ""))
		elif character == "\"": # Handle string literals
			tokens.append(tokenize_string_literal(script))
		elif character == ":":  # Begin a nested block
			if script.previous() == ":":
				push_error("Invalid block declaration syntax")

			script.current_indent_level += 1

			tokens.append(Token.new(TokenTypes.BEGIN_BLOCK, ""))
		elif character == "#": # Handle comments
			tokens.append(tokenize_comment(script))
		elif character.is_valid_identifier(): # Handle symbols
			tokens.append(tokenize_symbol(script))
		else:
			push_error("Found unidentified character: %s" % character)

		script.move_next()

	if tokens.back().type != TokenTypes.NEWLINE:
		# Add a NEWLINE token so the final line can always be delimited properly
		tokens.append(Token.new(TokenTypes.NEWLINE, ""))

	return tokens


func tokenize_comment(script: DialogueScript) -> Token:
	var comment_value := ""

	while not script.is_end_of_file():
		var character = script.move_next()

		if character == "\n":  # End the comment
			script.move_previous()
			return Token.new(TokenTypes.COMMENT, comment_value)
		else:
			comment_value += character

	# In case we reach End of File
	return Token.new(TokenTypes.COMMENT, comment_value)


func tokenize_symbol(script: DialogueScript) -> Token:
	# Store the symbol's first character because that's been checked to be a valid identifier (isn't a digit)
	var symbol := "%s" % script.current()

	# Allow normal + capitalized characters, numbers, underscores
	var regex := RegEx.new()
	regex.compile("[_a-zA-Z0-9]")

	while not script.is_end_of_file():
		var character = script.move_next()

		if regex.search(character): # Only add characters that match the regex
			symbol += character
		elif character in [" ", "\n", ":"]:
			script.move_previous()
			break
		else:
			push_error("Invalid character %s inside symbol" % character)
			return Token.new("", "")

	if symbol in FunctionKeywords:
		return Token.new(TokenTypes.FUNCTION, symbol)
	elif symbol in ["if", "elif", "else"]:
		return Token.new(TokenTypes[symbol.to_upper()], "")
	elif symbol == "choice":
		return Token.new(TokenTypes.CHOICE, "")
	else:
		return Token.new(TokenTypes.SYMBOL, symbol)


func tokenize_string_literal(script: DialogueScript) -> Token:
	var value := ""

	# Try to find the matching double quotes for the string
	while not script.is_end_of_file():
		var character: String = script.move_next()

		if character == "\"":
			if script.previous() == "\\":  # Continue on if the double quotes is escaped
				value += character
				continue

			value = value.c_unescape()

			return Token.new(TokenTypes.STRING_LITERAL, value)
		else:
			if character == "\n":
				script.move_previous()
				break

			value += character

	# Throw if no matching quotes is found by the end of the line or
	# the lexer hits End of File
	push_error("Unterminated string")
	return Token.new("", "")
