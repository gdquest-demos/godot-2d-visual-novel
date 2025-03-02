## Uses a Tween object to animate the control node fading in and out.
extends Control

const COLOR_WHITE_TRANSPARENT := Color(1.0, 1.0, 1.0, 0.0)

@export var appear_duration := 0.3


func _ready() -> void:
	modulate = COLOR_WHITE_TRANSPARENT


func appear() -> void:
	var _tween = create_tween()
	_tween.tween_property(
		self, "modulate", Color.WHITE, appear_duration
	).from(COLOR_WHITE_TRANSPARENT)


func disappear() -> void:
	var _tween = create_tween()
	_tween.tween_property(
		self, "modulate", COLOR_WHITE_TRANSPARENT, appear_duration / 2.0
	).from(Color.WHITE)
