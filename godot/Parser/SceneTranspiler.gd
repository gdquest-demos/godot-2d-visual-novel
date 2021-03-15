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


class ConditionTreeNode:
	extends BaseNode

	var if_block: ConditionBlockNode

	# Array because there can be multiple elifs
	var elif_blocks: Array
	var else_block: ConditionBlockNode

	func _init(next: int, if_block: ConditionBlockNode).(next) -> void:
		self.next = next
		self.if_block = if_block


class ConditionBlockNode:
	extends BaseNode

	var condition: SceneParser.BaseExpression

	func _init(next: int, condition: SceneParser.BaseExpression).(next) -> void:
		self.next = next
		self.condition = condition


class SetCommandNode:
	extends BaseNode
	var symbol: String
	var value

	func _init(next: int, symbol: String, value).(next) -> void:
		self.next = next
		self.symbol = symbol
		self.value = value

class JumpCommandNode:
	extends BaseNode

	func _init(next: int).(next) -> void:
		self.next = next


class PassCommandNode:
	extends BaseNode

	func _init(next: int).(next) -> void:
		self.next = next


const COMMAND_KEYWORDS := {
	BACKGROUND = "background",
	MARK = "mark",
	SCENE = "scene",
	PASS = "pass",
	JUMP = "jump",
	TRANSITION = "transition",
	SET = "set",
}

# Used to distinguish choice/if block's target number
var unique_choice_id_modifier = 1000000000
var unique_conditional_id_modifier = 2000000000


## Takes in a syntax tree from the SceneParser and turns it into a
## .scene script we can use
func transpile(syntax_tree: SceneParser.SyntaxTree, starting_index: int) -> DialogueTree:
	var dialogue_tree := DialogueTree.new()
	dialogue_tree.index = starting_index

	# Store all the declared jump points in advance
	var jump_index := 0
	for expression in syntax_tree.values:
		if (
			expression.type == SceneLexer.TOKEN_TYPES.COMMAND
			and expression.value == COMMAND_KEYWORDS.MARK
		):
			var new_jump_point: String = (
				expression.arguments[0].value
				if expression.arguments[0]
				else ""
			)

			if new_jump_point == "":
				push_error("A `mark` command is missing an argument")
				continue

			dialogue_tree.add_jump_point(new_jump_point, jump_index)
		else:
			jump_index += 1

	while not syntax_tree.is_at_end():
		var expression: SceneParser.BaseExpression = syntax_tree.move_to_next_expression()

		if expression.type == SceneLexer.TOKEN_TYPES.COMMAND:
			match expression.value:
				COMMAND_KEYWORDS.BACKGROUND:
					var background: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else ""
					)

					if background == "":
						push_error("A `background` command is missing an argument")
						continue

					var node := BackgroundCommandNode.new(dialogue_tree.index + 1, background)

					node.transition = (
						expression.arguments[1].value
						if len(expression.arguments) > 1
						else ""
					)

					dialogue_tree.append_node(node)
				COMMAND_KEYWORDS.SCENE:
					# For now we'll just use an absolute path as an argument
					var new_scene: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else ""
					)

					if new_scene == "":
						push_error("A `scene` command is missing an argument")
						continue

					dialogue_tree.append_node(SceneCommandNode.new(-1, new_scene))
				COMMAND_KEYWORDS.PASS:
					# Basically continue to the next node, this works since any choice/ifs are really just
					# one node with despite all their child blocks
					dialogue_tree.append_node(PassCommandNode.new(dialogue_tree.index + 1))
				COMMAND_KEYWORDS.JUMP:
					# Jump to an existing jump point
					var jump_point: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else ""
					)

					if jump_point == "":
						push_error("A `jump` command is missing an argument")
						continue

					if dialogue_tree.has_jump_point(jump_point):
						var target = dialogue_tree.get_jump_point(jump_point)
						dialogue_tree.append_node(JumpCommandNode.new(target))
					else:
						# -1 is a flag for an unknown jump_point
						dialogue_tree.add_jump_point(jump_point, -1)

						dialogue_tree.append_node(JumpCommandNode.new(-1))
				COMMAND_KEYWORDS.TRANSITION:
					var transition: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else ""
					)

					if transition == "":
						push_error("A `transition` command is missing an argument")
						continue

					dialogue_tree.append_node(
						TransitionCommandNode.new(dialogue_tree.index + 1, transition)
					)
				COMMAND_KEYWORDS.SET:
					var symbol: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else ""
					)

					if symbol == "":
						push_error("A `set` command is missing an argument")
						continue

					var value = (
						expression.arguments[1].value
						if len(expression.arguments) > 1
						else ""
					)

					if value == "":
						push_error("A `set` command is missing an argument")
						continue

					dialogue_tree.append_node(SetCommandNode.new(dialogue_tree.index + 1, symbol, value))
				COMMAND_KEYWORDS.MARK:
					pass
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

			var original_value = dialogue_tree.index

			# Store the choice nodes at a normally unreacheable place in the dialogue tree
			dialogue_tree.index += unique_choice_id_modifier

			for block in expression.value:
				var subtree := SceneParser.SyntaxTree.new()
				subtree.values = block.value

				dialogue_tree.index += 1

				# Any jump points, variables that get declared in the block's tree don't need to be handled since
				# the JUMP_POINTS, VARIABLES are constants that are shared between all DialogueTree instances
				# We pass in the current index tree's index here so the subtree can transpile properly
				var block_dialogue_tree: DialogueTree = transpile(subtree, dialogue_tree.index)

				choices.append({label = block.label, target = dialogue_tree.index})

				# Add the block's tree's nodes to the main dialogue tree
				for node in block_dialogue_tree.values.keys():
					dialogue_tree.values[node] = block_dialogue_tree.values[node]
					if (
						node == block_dialogue_tree.values.keys().back()
						and not (
							dialogue_tree.values[node] is JumpCommandNode
							or dialogue_tree.values[node] is PassCommandNode
							or dialogue_tree.values[node] is SceneCommandNode
						)
					):
						# Modify the final node's next value to properly continue on after the choice is made
						dialogue_tree.values[node].next = original_value + 1
					dialogue_tree.index += 1

			# Reset the index
			dialogue_tree.index = original_value

			dialogue_tree.append_node(ChoiceTreeNode.new(dialogue_tree.index + 1, choices))
		elif expression.type == "ConditionTree":
			if expression.if_block == null:
				push_error("Invalid condition tree")
				continue

			# Store the if nodes at a normally unreacheable place in the dialogue tree, apart from the choice nodes
			var original_value = dialogue_tree.index
			dialogue_tree.index += unique_conditional_id_modifier

			dialogue_tree.index += 1

			var tree_node = ConditionTreeNode.new(
				original_value + 1,
				ConditionBlockNode.new(
					dialogue_tree.index,
					expression.if_block.value.front() # To be changed to something cleaner
					)
				)

			# Transpile the if block
			var if_subtree := SceneParser.SyntaxTree.new()
			if_subtree.values = expression.if_block.block
			var if_block_dialogue_tree: DialogueTree = transpile(if_subtree, dialogue_tree.index)

			# Add the if block's tree's nodes to the main dialogue tree
			for node in if_block_dialogue_tree.values.keys():
				dialogue_tree.values[node] = if_block_dialogue_tree.values[node]
				if (
					node == if_block_dialogue_tree.values.keys().back()
					and not (
						dialogue_tree.values[node] is JumpCommandNode
						or dialogue_tree.values[node] is PassCommandNode
						or dialogue_tree.values[node] is SceneCommandNode
						)
				):
					# Modify the final node's next value to properly continue on after the choice is made
					dialogue_tree.values[node].next = original_value + 1
				dialogue_tree.index += 1


			# # Transpile the elif blocks
			# if not expression.elif_block.empty():
			# 	var elif_blocks := []

			# 	for elif_block in expression.elif_block:
			# 		var elif_subtree := SceneParser.SyntaxTree.new()
			# 		elif_subtree.values = elif_block.block

			# 		var elif_block_dialogue_tree: DialogueTree = transpile(
			# 			elif_subtree, dialogue_tree.index
			# 		)

			# 		elif_blocks.append(
			# 			ConditionBlockNode.new(
			# 				dialogue_tree.index + 1,
			# 				elif_block.value[0].value,  # To be changed
			# 				elif_block_dialogue_tree.values
			# 			)
			# 		)

			# 	node.elif_block = elif_blocks

			# Transpile the else block
			if expression.else_block != null:
				var else_subtree := SceneParser.SyntaxTree.new()
				else_subtree.values = expression.else_block.block

				var else_block_dialogue_tree: DialogueTree = transpile(
					else_subtree, dialogue_tree.index
				)

				# Store to pointer to the else block
				tree_node.else_block = ConditionBlockNode.new(dialogue_tree.index, null)

				# Add the else block's tree's nodes to the main dialogue tree
				for node in else_block_dialogue_tree.values.keys():
					dialogue_tree.values[node] = else_block_dialogue_tree.values[node]
					if (
						node == else_block_dialogue_tree.values.keys().back()
						and not (
							dialogue_tree.values[node] is JumpCommandNode
							or dialogue_tree.values[node] is PassCommandNode
							or dialogue_tree.values[node] is SceneCommandNode
							)
						):
						# Modify the final node's next value to properly continue on after the choice is made
						dialogue_tree.values[node].next = original_value + 1
						dialogue_tree.index += 1


			# Reset the index
			dialogue_tree.index = original_value

			dialogue_tree.append_node(tree_node)
		else:
			push_error("Unrecognized expression of type: %s with value: %s")
			continue

	# Make sure the scene is transitioned properly
	if not dialogue_tree.values[dialogue_tree.index - 1] is JumpCommandNode:
		(dialogue_tree.values[dialogue_tree.index - 1] as BaseNode).next = -1

	return dialogue_tree
