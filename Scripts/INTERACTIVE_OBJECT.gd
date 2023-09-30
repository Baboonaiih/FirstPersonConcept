class_name Interactive
extends Node3D

signal interacted(who)

@export var message = "Interact"
@export var action = "interact"

func get_message():
	return message
func set_message(text):
	message = text

func get_prompt():
	var key_name = ""
	for actions in InputMap.action_get_events(action):
		if actions is InputEventKey:
			key_name = OS.get_keycode_string(actions.physical_keycode)
	return message + "\n[" + key_name + "]"

func interact(who):
	emit_signal("interacted", who)
