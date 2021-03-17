## Receives a `SceneParser.SyntaxTree` and produces a `DialogueTree`, an object
## representing a scene, which a `ScenePlayer` instance can read.
##
## Use the `transpile()` method to get a `DialogueTree`.
class_name SceneTranspiler
extends Reference

# We assign a number to every step in a generated `DialogueTree`.
# We use the numbers below to offset the index number of choices and conditional
# blocks. This helps us to group them in the `DialogueTree.nodes` dictionary.
const UNIQUE_CHOICE_ID_MODIFIER = 1000000000
const UNIQUE_CONDITIONAL_ID_MODIFIER = 2100000000


# A mapping of named jump points to a corresponding node in the tree.
var _jump_points := {}
# Store jump nodes with unknown jump points
var _unresolved_jump_nodes := []


## A tree of nodes representing a scene. It stores nodes in its `nodes` dictionary.
## See the node types below.
class DialogueTree:
	var index := 0

	## Add a new node to the tree and assign it a unique index in the tree
	func append_node(node: BaseNode) -> void:
		values[index] = node
		index += 1


## Base type for all other node types below.
class BaseNode:
	var next: int

	func _init(next: int) -> void:
		self.next = next


## Node with a line of text optional parameters.
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


## Node type for a command that changes the displayed background, with an
## optional transition animation.
class BackgroundCommandNode:
	extends BaseNode

	var background: String
	var transition: String

	func _init(next: int, background: String).(next) -> void:
		self.next = next
		self.background = background


## Node type for a command that makes the game jump to another scene (or restart
## the current one).
class SceneCommandNode:
	extends BaseNode

	var scene_path: String

	func _init(next: int, scene_path: String).(next) -> void:
		self.next = next
		self.scene_path = scene_path


## Node type for a command that runs a scene transition animation, like a fade
## to black.
class TransitionCommandNode:
	extends BaseNode

	var transition: String

	func _init(next: int, transition: String).(next) -> void:
		self.next = next
		self.transition = transition


## Node type representing a player choice.
class ChoiceTreeNode:
	extends BaseNode

	var choices: Array

	func _init(next: int, choices: Array).(next) -> void:
		self.next = next
		self.choices = choices


## Represents one conditional block, starting with an `if`, `elif`, or `else`
## keyword.
class ConditionalBlockNode:
	extends BaseNode

	var condition: SceneParser.BaseExpression

	func _init(next: int, condition: SceneParser.BaseExpression).(next) -> void:
		self.next = next
		self.condition = condition


## Node type representing a tree of if, elifs, and else blocks in the script.
class ConditionalTreeNode:
	extends BaseNode

	var if_block: ConditionalBlockNode
	# There can be multiple `elif` blocks in a row, which is why we store them
	# in an array.
	var elif_blocks: Array
	var else_block: ConditionalBlockNode

	func _init(next: int, if_block: ConditionalBlockNode).(next) -> void:
		self.next = next
		self.if_block = if_block


## Represents a command that creates or modify a persistent variable. These
## variables are saved in the player's save file.
class SetCommandNode:
	extends BaseNode

	var symbol: String
	var value

	func _init(next: int, symbol: String, value).(next) -> void:
		self.next = next
		self.symbol = symbol
		self.value = value


## Node type for a command that will advance to any existing jump point.
class JumpCommandNode:
	extends BaseNode

	var jump_point: String

	func _init(next: int).(next) -> void:
		self.next = next


## Node type for a command that will break out of any running code block.
class PassCommandNode:
	extends BaseNode

	func _init(next: int).(next) -> void:
		self.next = next


## Takes in a syntax tree from the SceneParser and turns it into a
## `DialogueTree` for the `ScenePlayer` to play.
func transpile(syntax_tree: SceneParser.SyntaxTree, start_index: int) -> DialogueTree:
	var dialogue_tree := DialogueTree.new()
	dialogue_tree.index = start_index

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
					# Using `pass` is just syntactic sugar since a `pass` node is always appended at the end of each code block anyways
					# to allow the blocks to escape to its parent properly when it's finished
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

					if _has_jump_point(jump_point):
						var target: int = _get_jump_point(jump_point)
						dialogue_tree.append_node(JumpCommandNode.new(target))
					else:
						# Store as an unresolved jump node

						var jump_node := JumpCommandNode.new(-1)
						jump_node.jump_point = jump_point

						dialogue_tree.append_node(jump_node)

						# Pass in the instance by reference so we can modify this later
						_unresolved_jump_nodes.append(jump_node)
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
					var new_jump_point: String = (
						expression.arguments[0].value
						if expression.arguments[0]
						else ""
					)

					if new_jump_point == "":
						push_error("A `mark` command is missing an argument")
						continue

					_add_jump_point(new_jump_point, dialogue_tree.index)

					# Handle any unresolved jump nodes that point to this jump point
					# Use a `temp` variable because modifying an array while also looping through it can get buggy
					var temp := _unresolved_jump_nodes
					for jump_node in _unresolved_jump_nodes:
						if jump_node.jump_point == new_jump_point:
							jump_node.next = dialogue_tree.index
							temp.erase(jump_node)

					_unresolved_jump_nodes = temp
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
			var original_value := dialogue_tree.index

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

	return dialogue_tree


## Adds node from a source tree to a target tree
func _add_nodes_to_tree(original_value: int, nodes : Array, target_tree: DialogueTree, source_tree: DialogueTree) -> void:
	# Append a `pass` node to the end of the block to make sure it'll properly
	# end and continue to its parent block.
	source_tree.append_node(PassCommandNode.new(original_value + 1))
	nodes.append(source_tree.values.keys().back())

	# Add the source tree's nodes to the target tree
	for node in nodes:
		target_tree.values[node] = source_tree.values[node]
		target_tree.index += 1


func _add_jump_point(name: String, index: int) -> void:
	if _jump_points.has(name):
		push_error("Jump point already exists")
		return

	_jump_points[name] = index


func _has_jump_point(name: String) -> bool:
	return _jump_points.has(name)


func _get_jump_point(name: String) -> int:
	if _has_jump_point(name):
		return _jump_points[name]

	# -3 because -1, -2 are already used in the ScenePlayer interpreter
	return -3
