extends RigidBody3D

func _ready():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property($OmniLight3D, "light_energy", 0, 15.0)
	tween.chain().tween_callback(kill_light)

func kill_light():
	$OmniLight3D.queue_free()
