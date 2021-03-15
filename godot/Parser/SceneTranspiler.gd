## Receives a SyntaxTree and produces a `.scene` script for the ScenePlayer
class_name SceneTranspiler
extends Reference


class DialogueTree:
	# Store variables, jump points, etc.
	const GLOBALS := {JUMP_POINTS = {}, VARIABLES = {}}

	var values := {}

	var index := 0

	## Add a new node to the tree and assign it a unique index in the tree
	func append_node(node: BaseNode) -> void:
		values[index] = node
		index += 1

	func add_variable(symbol: String, value) -> void:
		# For simplicity's sake, this function can both create new variables and modify existing ones
		GLOBALS.VARIABLES[symbol] = value

	func get_variable(symbol: String):
		if _has_variable(symbol):
			return GLOBALS.VARIABLES[symbol]
		else:
			push_error("Could not find variable with the symbol `%s`" % symbol)
			return null

	func _has_variable(symbol: String) -> bool:
		return GLOBALS.VARIABLES.has(symbol)

	func add_jump_point(name: String, index: int) -> void:
		if GLOBALS.JUMP_POINTS.has(name):
			push_error("Jump point already exists")
			return

		GLOBALS.JUMP_POINTS[name] = index

	func has_jump_point(name: String) -> bool:
		return GLOBALS.JUMP_POINTS.has(name)

	func get_jump_point(name: String) -> int:
		if has_jump_point(name):
			return GLOBALS.JUMP_POINTS[name]

		# -3 because -1, -2 are already used in the ScenePlayer interpreter
		return -3


## Reprents a simple node in the dialogue tree
class BaseNode:
	var next: int

	func _init(next: int) -> void:
		self.next = next

	func _to_string() -> String:
		return "\n{ next = %s }" % self.next


## Represents a node with dialogue text and some optional parameters
class DialogueNode:
	extends BaseNode

	var line: String
	var character: String
	var expression: String
	var animation: String
	var side: String

	func _init(next: int, line: String).(next) -> void:
		self.next = next
		self.line = line

	func _to_string() -> String:
		return (
			"\n{ next = %s, line = %s, character = %s, expression = %s, animation = %s, side = %s }"
			% [self.next, self.line, self.character, self.expression, self.animation, self.side]
		)


## Represents a command that changes the background with an optional transition type
class BackgroundCommandNode:
	extends BaseNode
	var background: String
	var transition: String

	func _init(next: int, background: String).(next) -> void:
		self.next = next
		self.background = background

	func _to_string() -> String:
		return (
			"\n{ next = %s, background = %s, transition = %s }"
			% [self.next, self.background, self.transition]
		)


## Represents a command that changes the scene
class SceneCommandNode:
	extends BaseNode
	var scene_path: String

	func _init(next: int, scene_path: String).(next) -> void:
		self.next = next
		self.scene_path = scene_path

	func _to_string() -> String:
		return "\n{ next = %s, scene_path = %s }" % [self.next, self.scene_path]


## Represents a command that runs a transition animation
class TransitionCommandNode:
	extends BaseNode
	var transition: String

	func _init(next: int, transition: String).(next) -> void:
		self.next = next
		self.transition = transition

	func _to_string() -> String:
		return "\n{ next = %s, transition = %s }" % [self.next, self.transition]


## Represents a branching path in the dialogue tree
class ChoiceTreeNode:
	extends BaseNode
	var choices: Array

	func _init(next: int, choices: Array).(next) -> void:
		self.next = next
		self.choices = choices

class ChoiceNode:
	extends BaseNode
	var label: String
	var value: Dictionary

	func _init(next: int, label: String, value: Dictionary).(next) -> void:
		self.next = next
		self.label = label
		self.value = value


const COMMAND_KEYWORDS := {
	BACKGROUND = "background",
	MARK = "mark",
	SCENE = "scene",
	PASS = "pass",
	JUMP = "jump",
	TRANSITION = "transition",
	SET = "set",
}


## Takes in a syntax tree from the SceneParser and turns it into a
## .scene script we can use
func transpile(syntax_tree: SceneParser.SyntaxTree, starting_index: int) -> DialogueTree:
	var dialogue_tree := DialogueTree.new()
	dialogue_tree.index = starting_index

	while not syntax_tree.is_at_end():
		var expression: SceneParser.BaseExpression = syntax_tree.move_to_next_expression()

		if expression.type == SceneLexer.TOKEN_TYPES.COMMAND:
			match expression.value:
				COMMAND_KEYWORDS.BACKGROUND:
					var background: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else null
					)

					if background == null:
						push_error("A `background` command is missing an argument")
						continue

					var node = BackgroundCommandNode.new(dialogue_tree.index + 1, background)

					node.transition = (
						expression.arguments[1].value
						if len(expression.arguments) > 1
						else null
					)

					dialogue_tree.append_node(node)
				COMMAND_KEYWORDS.MARK:
					var new_jump_point: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else null
					)

					if new_jump_point == null:
						push_error("A `mark` command is missing an argument")
						continue

					# Store the jump point globally in the script file
					dialogue_tree.add_jump_point(new_jump_point, dialogue_tree.index)
				COMMAND_KEYWORDS.SCENE:
					# For now we'll just use an absolute path as an argument
					var new_scene: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else null
					)

					if new_scene == null:
						push_error("A `scene` command is missing an argument")
						continue

					dialogue_tree.append_node(
						SceneCommandNode.new(dialogue_tree.index + 1, new_scene)
					)
				COMMAND_KEYWORDS.PASS:
					# Basically continue to the next node, this works since any choice/ifs are really just
					# one node with despite all their child blocks
					dialogue_tree.append_node(BaseNode.new(dialogue_tree.index + 1))
				COMMAND_KEYWORDS.JUMP:
					# Jump to an existing jump point
					var jump_point: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else null
					)

					if jump_point == null:
						push_error("A `jump` command is missing an argument")
						continue

					if dialogue_tree.has_jump_point(jump_point):
						var target = dialogue_tree.get_jump_point(jump_point)
						dialogue_tree.append_node(BaseNode.new(target))
					else:
						# Maybe there's a future jump point so we'll add one in regardless
						# We'll do a check once we finish transpiling

						# Maybe we should parse all the `mark` commands first though...


						# -1 is a flag for an unknown jump_point
						dialogue_tree.add_jump_point(jump_point, -1)


						dialogue_tree.append_node(BaseNode.new(-1))
				COMMAND_KEYWORDS.TRANSITION:
					var transition: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else null
					)

					if transition == null:
						push_error("A `transition` command is missing an argument")
						continue

					dialogue_tree.append_node(
						TransitionCommandNode.new(dialogue_tree.index + 1, transition)
					)
				COMMAND_KEYWORDS.SET:
					var symbol: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else null
					)

					if symbol == null:
						push_error("A `set` command is missing an argument")
						continue

					var value = (
						expression.arguments[1].value
						if len(expression.arguments) > 1
						else null
					)

					if value == null:
						push_error("A `set` command is missing an argument")
						continue

					dialogue_tree.add_variable(symbol, value)
				_:
					push_error("Unrecognized command type `%s`" % expression.value)
					break
		elif expression.type == "Dialogue":
			# A dialogue node only needs the dialogue text, anything else is optional
			var node := DialogueNode.new(dialogue_tree.index + 1, expression.value)

			node.character = (
				expression.arguments[0].value
				if not expression.arguments.empty()
				else ""
			)

			node.expression = expression.arguments[1].value if len(expression.arguments) > 1 else ""

			node.animation = expression.arguments[2].value if len(expression.arguments) > 2 else ""

			node.side = expression.arguments[3].value if len(expression.arguments) > 3 else ""

			dialogue_tree.append_node(node)
		elif expression.type == SceneLexer.TOKEN_TYPES.CHOICE:
			var choices := []

			# Go through the choices and transpile their blocks with a bit of recursion
			for block in expression.value:
				var subtree := SceneParser.SyntaxTree.new()
				subtree.values = block.value

				# The dialogue tree for the choice block
				# Any jump points, variables that get declared in the block's tree don't need to be handled since
				# the JUMP_POINTS, VARIABLES are constants that are shared between all DialogueTree instances
				var block_dialogue_tree: DialogueTree = transpile(subtree, dialogue_tree.index)

				choices.append(ChoiceNode.new(dialogue_tree.index + 1, block.label, block_dialogue_tree.values))

			print(choices)

			dialogue_tree.append_node(ChoiceTreeNode.new(dialogue_tree.index + 1, choices))
		elif expression.type == "ConditionTree":  # If's
			pass

	return dialogue_tree
