extends CharacterBody3D

const flareScene = preload("res://flare.tscn")

const SPEED : float = 5.0
const FLARE_VELOCITY : float = 10.0
const JUMP_VELOCITY : float = 6.0
const ACCEL : float = 0.05
const DECEL : float = 0.03
const JUMPCEL : float = 0.1

var flare_available : bool = false

var SENSITIVITY : float = 1.0
var LOOK_DOWN_LIMIT : float = -PI/2
var LOOK_UP_LIMIT : float = PI/2

var REACH : float = 1.0

const JETPACK_MAX_VOLUME : float = 100.0
var JETPACK_VOLUME : float = JETPACK_MAX_VOLUME

var moving : bool = false

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

var paused : bool = false

var queue_flare : bool = false # for physics process to not ignore flare input

var holding_artifact : bool = false

var game_over_yeah : bool = false
var yeah_there_we_go_apc_destroyed_mission_accomplished : bool = false

var quitting : bool = false

var jetpack_fuel_economy : float = 0.8

func _ready():
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	jetpack_fuel_economy = get_parent().jetpack_fuel_economy
	get_parent().delivery_point.body_entered.connect(_on_delivery_complete)
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(%JetpackFG, "color:a", 0.25, 5.0)
	tween.tween_property(%Headlight, "light_energy", 0.5, 5.0)
	tween.chain().tween_callback(_on_headlight_flicker_timeout)
	headlight_rotate_loop()
	set_info_text(GET_ARTIFACT)

func _on_headlight_flicker_timeout():
	var tween = get_tree().create_tween()
	for n in randi_range(1, 4):
		tween.chain().tween_property(%Headlight, "light_energy", randf_range(0.01, 0.2), randf_range(0, 0.1))
		tween.parallel().tween_property(%Headlight, "spot_angle", randf_range(31.0, 34.0), randf_range(0.02, 0.2))
		tween.parallel().tween_property(%Arrow, "modulate:a", randf_range(0.1, 0.5), randf_range(0.02, 0.2))
		tween.chain().tween_property(%Headlight, "light_energy", randf_range(0.6, 1.0), randf_range(0.02, 0.2))
		tween.parallel().tween_property(%Headlight, "spot_angle", randf_range(35.0, 38.0), randf_range(0.02, 0.2))
		tween.parallel().tween_property(%Arrow, "modulate:a", randf_range(0.6, 0.9), randf_range(0.02, 0.2))
	%HeadlightFlicker.wait_time = randf_range(0.5, 10.0)
	%HeadlightFlicker.start()

func headlight_rotate_loop():
	var next = randf_range(2.0, 5.0)
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(%Headlight, "rotation:x", randfn(0, 0.07), next)
	tween.tween_property(%Headlight, "rotation:y", randfn(0, 0.07), next)
	tween.tween_property(%Headlight, "rotation:z", randfn(0, 0.07), next)
	tween.chain().tween_callback(headlight_rotate_loop)

enum {GET_ARTIFACT=1, DELIVER=2, STEP_AWAY=3}
var objective_state = GET_ARTIFACT
const rand_chars = " 0123456789!@#$%^&*()-=_+[]{}\\|;':\",.<>/?"
# When setting text, modify these instead of the text variable directly
var stored_text1 : String = ""
var stored_text2 : String = ""
var stored_text3 : String = ""
var light_shone : bool = false
func _process(delta):
	%Info1.text = stored_text1
	%Info2.text = stored_text2
	%Info3.text = stored_text3
	
	#camera physics interpolation to reduce physics jitter on high refresh-rate monitors
	var fps = 1.0/delta
	if fps > Engine.get_physics_ticks_per_second():
		$Camera.set_as_top_level(true)
		$Camera.global_transform.origin = $Camera.global_transform.origin.lerp(global_transform.origin, 40.0 * delta)
		$Camera.rotation.y = rotation.y
	else:
		$Camera.set_as_top_level(false)
	
	if holding_artifact:
		var artifact = get_parent().artifact
		var desired_position = -$Camera.global_transform.basis.z.normalized() * 1.5 + position
		artifact.position = desired_position
		artifact.gravity_scale = 0
		if not light_shone and position.distance_squared_to(get_parent().delivery_point.position) < 2500:
			light_shone = true
			get_parent().delivery_point.show()
	
	if position.y < 0:
		position.y = 525
	
	
	%Arrow.pivot_offset = %Arrow.size / 2.0
	match objective_state:
		GET_ARTIFACT:
			var mypos : Vector2 = Vector2(position.x, position.z)
			var itpos : Vector2 = Vector2(get_parent().artifact.position.x, get_parent().artifact.position.z)
			%Arrow.rotation = snappedf(mypos.angle_to_point(itpos) + rotation.y + PI/2.0, PI/4.0)
			%Distance.text = str(ceilf(position.distance_to(get_parent().artifact.position)), "m")
		DELIVER:
			var mypos : Vector2 = Vector2(position.x, position.z)
			var itpos : Vector2 = Vector2(get_parent().delivery_point.position.x, get_parent().delivery_point.position.z)
			%Arrow.rotation = snappedf(mypos.angle_to_point(itpos) + rotation.y + PI/2.0, PI/4.0)
			%Distance.text = str(ceilf(position.distance_to(get_parent().delivery_point.position)), "m")
	
	for n in objective_state:
		if stored_text1.length() > 0 and randf() < objective_state*0.1:
			%Info1.text[randi_range(0, %Info1.text.length()-1)] = rand_chars[randi_range(0, rand_chars.length()-1)]
		if stored_text2.length() > 0 and randf() < objective_state*0.1:
			%Info2.text[randi_range(0, %Info2.text.length()-1)] = rand_chars[randi_range(0, rand_chars.length()-1)]
		if stored_text3.length() > 0 and  randf() < objective_state*0.1:
			%Info3.text[randi_range(0, %Info3.text.length()-1)] = rand_chars[randi_range(0, rand_chars.length()-1)]
	

var jumpbobtween
func _input(event):
	if event is InputEventMouseMotion and DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_CAPTURED:
		# Rotate the camera up and down
		$Camera.rotation.x = clamp($Camera.rotation.x - event.relative.y / (SENSITIVITY * 400.0), LOOK_DOWN_LIMIT, LOOK_UP_LIMIT)
		# Rotate the camera horizontally
		rotation.y -= event.relative.x / (SENSITIVITY * 400.0)

	# Jump lampbobbing
	if event.is_action_pressed("jump"):
		if jumpbobtween: jumpbobtween.kill()
		jumpbobtween = get_tree().create_tween().set_parallel(true)
		jumpbobtween.set_trans(Tween.TRANS_QUAD)
		jumpbobtween.tween_property(%LampJump, "rotation:x", -0.2, 0.5)
		jumpbobtween.tween_property(%GUI, "anchor_top", 0.1, 0.5)
		jumpbobtween.tween_property(%GUI, "anchor_bottom", 1.1, 0.5)
	elif event.is_action_released("jump"):
		if jumpbobtween: jumpbobtween.kill()
		jumpbobtween = get_tree().create_tween().set_parallel(true)
		jumpbobtween.set_trans(Tween.TRANS_QUAD)
		jumpbobtween.tween_property(%LampJump, "rotation:x", 0, 0.5)
		jumpbobtween.tween_property(%GUI, "anchor_top", 0, 0.5)
		jumpbobtween.tween_property(%GUI, "anchor_bottom", 1, 0.5)
	
	# Assumes that you have an input action called "menu"
	if event.is_action_pressed("menu"):
		cycle_pause() # Frees the mouse to close the window or do other things

	if event.is_action_pressed("flare"):
		queue_flare = true
	
	if event.is_action_pressed("use"):
		var UseCast = get_parent().use_cast
		UseCast.position = position
		UseCast.target_position = -$Camera.global_transform.basis.z.normalized() * 1.5
		UseCast.force_raycast_update()
		var collided = UseCast.get_collider()
		print(collided)
		if collided and collided == get_parent().artifact:
			if objective_state == GET_ARTIFACT:
				holding_artifact = true
				objective_state = DELIVER
				set_info_text(DELIVER)
			elif objective_state == STEP_AWAY:
				game_fail()

func cycle_pause():
	if paused:
		unpause()
	else:
		pause()

func pause():
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	paused = true
	%Pause.show()

func unpause():
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	paused = false
	%Pause.hide()

var touched_grass = false
var in_air = false
func _physics_process(delta):
	
	if queue_flare: # Queued action
		queue_flare = false
		if flare_available:
			flare_available = false
			%FlareReady.hide()
			$FlareTimer.start()
			var flare = flareScene.instantiate()
			get_parent().add_child(flare)
			flare.position = position
			flare.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
			flare.apply_central_impulse(-$Camera.global_transform.basis.z.normalized() * FLARE_VELOCITY + velocity)
	
	# Add the gravity.
	if not is_on_floor():
		in_air = velocity.y
		if not touched_grass:
			velocity.y -= gravity * delta * 10.0
		else:
			velocity.y -= gravity * delta
	else:
		if in_air:
			if jumpbobtween: jumpbobtween.kill()
			$LandSound.volume_db = in_air*0.1
			$LandSound.play()
			jumpbobtween = get_tree().create_tween().set_parallel(true)
			jumpbobtween.tween_property(%LampJump, "rotation:x", in_air*0.007, 0.1)
			jumpbobtween.tween_property(%GUI, "anchor_top", -in_air*0.007, 0.1)
			jumpbobtween.tween_property(%GUI, "anchor_bottom", -in_air*0.007+1, 0.1)
			jumpbobtween.tween_property($Camera, "v_offset", min(in_air*0.02, 1), 0.1)
			jumpbobtween.set_trans(Tween.TRANS_QUAD)
			var comeup = min(-in_air*0.06, 1.0)
			jumpbobtween.chain().tween_property(%LampJump, "rotation:x", 0, comeup)
			jumpbobtween.parallel().tween_property(%GUI, "anchor_top", 0, comeup)
			jumpbobtween.parallel().tween_property(%GUI, "anchor_bottom", 1, comeup)
			jumpbobtween.parallel().tween_property($Camera, "v_offset", 0, comeup)
			in_air = 0
		touched_grass = true
	
	JETPACK_VOLUME = min(JETPACK_VOLUME + 0.2, JETPACK_MAX_VOLUME)

	# Handle Jump.
	if touched_grass and JETPACK_VOLUME >= 5.0 and Input.is_action_pressed("jump"):
		velocity.y = move_toward(velocity.y, JUMP_VELOCITY, SPEED * JUMPCEL)
		JETPACK_VOLUME -= 0.8

	%JetpackFG.anchor_right = 0.3 + (0.4*JETPACK_VOLUME/JETPACK_MAX_VOLUME)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("strafe_left", "strafe_right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		moving = true
		velocity.x = move_toward(velocity.x, direction.x * SPEED, SPEED * ACCEL)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, SPEED * ACCEL)
	else:
		moving = false
		velocity.x = move_toward(velocity.x, 0, SPEED * DECEL)
		velocity.z = move_toward(velocity.z, 0, SPEED * DECEL)

	move_and_slide()

func _on_flare_timer_timeout():
	flare_available = true
	%FlareReady.show()

const set_text1 = "❏ Retrieve the artifact."
const set_text2 = "❏ Deliver the artifact to the retrieval point."
const set_text3 = "❏ IMPORTANT: Step back from the artifact while retrieval takes place."
func set_info_text(which : int):
	match which:
		GET_ARTIFACT:
			objective_state = GET_ARTIFACT
			for n in set_text1.length():
				stored_text1 += set_text1[n]
				if quitting:
					break
				await get_tree().create_timer(0.1).timeout
		DELIVER:
			objective_state = DELIVER
			for n in set_text2.length():
				stored_text2 += set_text2[n]
				if quitting:
					break
				await get_tree().create_timer(0.1).timeout
		STEP_AWAY:
			objective_state = STEP_AWAY
			for n in set_text3.length():
				stored_text3 += set_text3[n]
				if quitting:
					break
				await get_tree().create_timer(0.1).timeout
		_:
			push_error("Tried to set text of out-of-bounds %Info", which)

func _on_delivery_complete(body):
	if body != get_parent().artifact:
		return
	get_parent().artifact.freeze = true
	holding_artifact = false
	objective_state = STEP_AWAY
	set_info_text(STEP_AWAY)
	$VictoryTimer.start()

const fail_text = "This unit has demonstrated willful defiance in mission testing environments.\n...We will have to start over."
func game_fail():
	if yeah_there_we_go_apc_destroyed_mission_accomplished:
		return
	game_over_yeah = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(%Fail, "modulate:a", 1, 1.0)
	for n in fail_text.length():
		%Fail.get_node("Label").text += fail_text[n]
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

const win_text = "Retrieval of artifact successful.\nDeactivation in progress...........\nGood night."
func _on_victory_timer_timeout():
	if game_over_yeah:
		return
	yeah_there_we_go_apc_destroyed_mission_accomplished = true
	get_parent().artifact.queue_free()
	get_parent().artifact = null
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(%Win, "modulate:a", 1, 1.0)
	for n in win_text.length():
		%Win.get_node("Label").text += win_text[n]
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

func _on_resume_pressed():
	if game_over_yeah or yeah_there_we_go_apc_destroyed_mission_accomplished:
		return
	unpause()

func _on_qt_menu_pressed():
	if game_over_yeah or yeah_there_we_go_apc_destroyed_mission_accomplished:
		return
	quitting = true
	get_tree().reload_current_scene()
