class_name ChoiceSelector
extends VBoxContainer

signal choice_made(target_id)


func setup(choices: Array) -> void:
	for choice in choices:
		var button := Button.new()
		button.text = choice.label
		button.connect("pressed", self, "_on_Button_pressed", [choice.target])
		add_child(button)
	(get_child(0) as Button).grab_focus()


func _on_Button_pressed(target_id: int) -> void:
	emit_signal("choice_made", target_id)
	queue_free()
