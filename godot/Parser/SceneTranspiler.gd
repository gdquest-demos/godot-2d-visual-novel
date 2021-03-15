## Receives a SyntaxTree and produces a script dictionary for the ScenePlayer
class_name SceneTranspiler
extends Reference


class DialogueTree:
	# Store variables, jump points, etc.
	const GLOBALS := {
		jump_points = {},
		variables = {}
		}

	var values := {}

	var index := 0

	## Add a new node to the tree and assign it a unique index in the tree
	func append_node(node: BaseNode) -> void:
		values[index] = node
		index += 1

	func add_variable(symbol: String, value) -> void:
		# For simplicity's sake, this function can both create new variables and modify existing ones
		GLOBALS.variables[symbol] = value

	func get_variable(symbol: String):
		if GLOBALS.variables.has(symbol):
			return GLOBALS.variables[symbol]
		else:
			push_error("Could not find variable with the symbol `%s`" % symbol)
			return null

	func add_jump_point(name: String, index: int) -> void:
		if GLOBALS.jump_points.has(name):
			push_error("Jump point already exists")
			return

		GLOBALS.jump_points[name] = index

	func has_jump_point(name: String) -> bool:
		return GLOBALS.jump_points.has(name)

	func get_jump_point(name: String) -> int:
		if has_jump_point(name):
			return GLOBALS.jump_points[name]

		# -3 because -1, -2 are already used in the ScenePlayer interpreter
		return -3


## Reprents a simple node in the dialogue tree
class BaseNode:
	var next: int

	func _init(next: int) -> void:
		self.next = next


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


## Represents a command that changes the background with an optional transition type
class BackgroundCommandNode:
	extends BaseNode
	var background: String
	var transition: String

	func _init(next: int, background: String).(next) -> void:
		self.next = next
		self.background = background


## Represents a command that changes the scene
class SceneCommandNode:
	extends BaseNode
	var scene_path: String

	func _init(next: int, scene_path: String).(next) -> void:
		self.next = next
		self.scene_path = scene_path


## Represents a command that runs a transition animation
class TransitionCommandNode:
	extends BaseNode
	var transition: String

	func _init(next: int, transition: String).(next) -> void:
		self.next = next
		self.transition = transition


## Represents a branching path in the dialogue tree
class ChoiceTreeNode:
	extends BaseNode
	var choices: Array

	func _init(next: int, choices: Array).(next) -> void:
		self.next = next
		self.choices = choices


## Represents a tree of if, elifs, and else in the script
class ConditionalTreeNode:
	extends BaseNode

	var if_block: ConditionalBlockNode

	# Array because there can be multiple elifs
	var elif_blocks: Array
	var else_block: ConditionalBlockNode

	func _init(next: int, if_block: ConditionalBlockNode).(next) -> void:
		self.next = next
		self.if_block = if_block


## Represents a conditional
class ConditionalBlockNode:
	extends BaseNode

	var condition: SceneParser.BaseExpression

	func _init(next: int, condition: SceneParser.BaseExpression).(next) -> void:
		self.next = next
		self.condition = condition


## Represents a command that creates or modify a variable on the save file level
class SetCommandNode:
	extends BaseNode
	var symbol: String
	var value

	func _init(next: int, symbol: String, value).(next) -> void:
		self.next = next
		self.symbol = symbol
		self.value = value


## Repretends a command that will advance to any existing jump points
class JumpCommandNode:
	extends BaseNode

	func _init(next: int).(next) -> void:
		self.next = next


## Represents a command that will break out of any running code blocks
class PassCommandNode:
	extends BaseNode

	func _init(next: int).(next) -> void:
		self.next = next


# Used to distinguish choice/if block's target number
const UNIQUE_CHOICE_ID_MODIFIER = 1000000000
const UNIQUE_CONDITIONAL_ID_MODIFIER = 2100000000


## Takes in a syntax tree from the SceneParser and turns it into a
## script dictionary for the ScenePlayer
func transpile(syntax_tree: SceneParser.SyntaxTree, starting_index: int) -> DialogueTree:
	var dialogue_tree := DialogueTree.new()
	dialogue_tree.index = starting_index

	# Store all the declared jump points in advance
	var jump_index := 0
	for expression in syntax_tree.values:
		if (
			expression.type == SceneParser.EXPRESSION_TYPES.COMMAND
			and expression.value == SceneLexer.BUILT_IN_COMMANDS.MARK
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

		if expression.type == SceneParser.EXPRESSION_TYPES.COMMAND:
			# Create the approriate command node
			match expression.value:
				SceneLexer.BUILT_IN_COMMANDS.BACKGROUND:
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
				SceneLexer.BUILT_IN_COMMANDS.SCENE:
					# For now, the command only works when next_scene is used as an argument
					# It shouldn't be too hard to allow for file paths to be used as arguments in the future
					var new_scene: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else ""
					)

					if new_scene == "":
						push_error("A `scene` command is missing an argument")
						continue

					dialogue_tree.append_node(SceneCommandNode.new(dialogue_tree.index + 1, new_scene))
				SceneLexer.BUILT_IN_COMMANDS.PASS:
					# This command doesn't work yet because the logic for jumping out of code blocks is still really messy
					pass
				SceneLexer.BUILT_IN_COMMANDS.JUMP:
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
						push_error("Jump point %s does not exist" % jump_point)
						continue
				SceneLexer.BUILT_IN_COMMANDS.TRANSITION:
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
				SceneLexer.BUILT_IN_COMMANDS.SET:
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
				SceneLexer.BUILT_IN_COMMANDS.MARK:
					# Ignore since we've already handled them above
					pass
				_:
					push_error("Unrecognized command type `%s`" % expression.value)
					continue
		elif expression.type == SceneParser.EXPRESSION_TYPES.DIALOGUE:
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
		elif expression.type == SceneParser.EXPRESSION_TYPES.CHOICE:
			var choices := []

			# Stores the position for the choice tree node which has pointers to the actual choice blocks
			# that are stored at a unique place
			var original_value: int = dialogue_tree.index

			# Store the choice nodes at a normally unreacheable place in the dialogue tree
			dialogue_tree.index += UNIQUE_CHOICE_ID_MODIFIER
			for block in expression.value:
				var subtree := SceneParser.SyntaxTree.new()
				subtree.values = block.value

				dialogue_tree.index += 1

				# Any jump points, variables that get declared in the block's tree don't need to be handled since
				# the jump_points, variables are constants that are shared between all DialogueTree instances
				# We pass in the current index tree's index here so the subtree can transpile properly
				var block_dialogue_tree: DialogueTree = transpile(subtree, dialogue_tree.index)

				# Add the pointer to this code block in the choice tree
				choices.append({label = block.label, target = dialogue_tree.index})

				# Add the block's tree's nodes to the main dialogue tree
				_add_nodes_to_tree(original_value, block_dialogue_tree.values.keys(), dialogue_tree, block_dialogue_tree)

			# Reset the index
			dialogue_tree.index = original_value

			dialogue_tree.append_node(ChoiceTreeNode.new(dialogue_tree.index + 1, choices))
		elif expression.type == SceneParser.EXPRESSION_TYPES.CONDITIONAL_TREE:
			if expression.if_block == null:
				push_error("Invalid conditional tree")
				continue

			# Stores the position for the conditional tree node which has pointers to the actual conditional blocks
			# that are stored at a unique place
			var original_value = dialogue_tree.index

			# Store the if nodes at a normally unreacheable place in the dialogue tree, apart from the choice nodes
			dialogue_tree.index += UNIQUE_CONDITIONAL_ID_MODIFIER
			dialogue_tree.index += 1

			# The conditional tree only needs a pointer to the `if` block to be proper, elifs and else are optional
			var tree_node = ConditionalTreeNode.new(
				original_value + 1,
				ConditionalBlockNode.new(
					# The pointer to the if block's index in the dialogue tree
					dialogue_tree.index,
					# The if's condition
					expression.if_block.value.front()
					)
				)

			# Transpile the if block
			var if_subtree := SceneParser.SyntaxTree.new()
			if_subtree.values = expression.if_block.block
			var if_block_dialogue_tree: DialogueTree = transpile(if_subtree, dialogue_tree.index)

			# Add the if block's tree's nodes to the main dialogue tree
			_add_nodes_to_tree(original_value, if_block_dialogue_tree.values.keys(), dialogue_tree, if_block_dialogue_tree)


			# Transpile the elif blocks
			if not expression.elif_block.empty():
				var elif_blocks := []

				for elif_block in expression.elif_block:
					var elif_subtree := SceneParser.SyntaxTree.new()
					elif_subtree.values = elif_block.block

					var elif_block_dialogue_tree: DialogueTree = transpile(
						elif_subtree, dialogue_tree.index
					)

					# Store to pointer to the elif block in the choice tree node
					elif_blocks.append(ConditionalBlockNode.new(dialogue_tree.index, elif_block.value.front()))

					# Add the elif block's tree's nodes to the main dialogue tree
					_add_nodes_to_tree(original_value, elif_block_dialogue_tree.values.keys(), dialogue_tree, elif_block_dialogue_tree)

				tree_node.elif_blocks = elif_blocks

			# Transpile the else block
			if expression.else_block != null:
				var else_subtree := SceneParser.SyntaxTree.new()
				else_subtree.values = expression.else_block.block

				var else_block_dialogue_tree: DialogueTree = transpile(
					else_subtree, dialogue_tree.index
				)

				# Store to pointer to the else block in the choice tree node
				tree_node.else_block = ConditionalBlockNode.new(dialogue_tree.index, null)

				# Add the else block's tree's nodes to the main dialogue tree
				_add_nodes_to_tree(original_value, else_block_dialogue_tree.values.keys(), dialogue_tree, else_block_dialogue_tree)

			# Reset the index
			dialogue_tree.index = original_value

			dialogue_tree.append_node(tree_node)
		else:
			push_error("Unrecognized expression of type: %s with value: %s" % [expression.type, expression.value])

	# Make sure the scene is transitioned properly
	if not dialogue_tree.values[dialogue_tree.index - 1] is JumpCommandNode:
		(dialogue_tree.values[dialogue_tree.index - 1] as BaseNode).next = -1

	return dialogue_tree


## Adds node from a source tree to a target tree
func _add_nodes_to_tree(original_value: int, nodes : Array, target_tree: DialogueTree, source_tree: DialogueTree) -> void:
	# Add the else block's tree's nodes to the main dialogue tree
	for node in nodes:
		target_tree.values[node] = source_tree.values[node]

		if (
			node == source_tree.values.keys().back()
			and not (
				target_tree.values[node] is JumpCommandNode
				or target_tree.values[node] is PassCommandNode
				or target_tree.values[node] is SceneCommandNode
				)
			):
			# Modify the final node's next value to properly escape out of the code block
			target_tree.values[node].next = original_value + 1

		target_tree.index += 1
