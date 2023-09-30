extends Node3D

@export var open = false
@export var locked = false
var playback = null

func _ready():
	playback = $AnimationTree.get("parameters/playback")
	if open:
		playback.travel("Open")
	else:
		playback.travel("Close")
	
func toggle_door(_who):
	open = !open
	
	if open:
		playback.travel("Open")
	else:
		playback.travel("Close")


func _on_door_hitbox_interacted(who):
	var doortxt = $door/Object_7/door_Door_0/door_hitbox
	if locked:
		doortxt.set_message("Door is locked")
	else:
		toggle_door(who)
