extends Node3D

# t_flashlightpattern.png (CC0) from https://opengameart.org/content/flashlight-pattern-incandescent
# CRT noise (CC0) from https://freesound.org/people/grcekh/sounds/546047/

@export var SKIP_MENU : bool = false
const playerScene = preload("res://dwarf.tscn")
const DEFAULT_LIGHT = Color("01000e") # HSL: (274, 100, 2) (0.76, 1, 0.02)
var SEED : int = -1
var initialized = false
var playing = false
var arti_pos : Vector2
var jetpack_fuel_economy : float = 0.8
@onready var artifact = $Artifact
@onready var delivery_point = $DeliveryPoint
@onready var use_cast = $UseCast

func _ready():
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	randomize()
	if SEED >= 0:
		%VoxelLodTerrain.generator.noise.seed = SEED
	else:
		%VoxelLodTerrain.generator.noise.seed = randi()
	$Lightning.wait_time = randf_range(5.0, 30.0)
	$Lightning.start()
	if SKIP_MENU:
		start_game()
	else:
		$MainMenuAnim.play("MenuStart")

func start_game():
	playing = true
	%MainMenu.get_node("Options").disabled = true

var first_process : bool = true
func _process(_delta):
	if initialized or not playing: return
	if first_process:
		%LoadingTxt.show()
		await get_tree().process_frame
	$TerrainCheck.force_raycast_update()
	if $TerrainCheck.is_colliding() and $TerrainCheck.get_collider() == %VoxelLodTerrain:
		# Spawns the artifact
		arti_pos = Vector2.UP.rotated(randf_range(0, TAU)) * randfn(100, 10)
		$Artifact.position.x = arti_pos.x
		$Artifact.position.y = 500
		$Artifact.position.z = arti_pos.y
		# Runs through random spawn points until it finds a point that is mostly flat
		# or gives up after 10 tries and just goes with what it found
		var selected_dpoint : Vector3
		var satisfied_dpoint : bool = false
		while not satisfied_dpoint:
			var delivery_pos : Vector2 = Vector2.UP.rotated(randf_range(0, TAU)) * randfn(100, 10) + arti_pos
			$DeliveryScan.position.x = delivery_pos.x
			$DeliveryScan.position.z = delivery_pos.y
			var cancel_ops : bool = false
			var collision_spots = []
			$DeliveryScan.force_raycast_update()
			if not $DeliveryScan.is_colliding():
				continue
			selected_dpoint = $DeliveryScan.get_collision_point()
			for x in 3:
				for y in 3:
					$DeliveryScan.position.x = delivery_pos.x + x - 1
					$DeliveryScan.position.z = delivery_pos.y + y - 1
					$DeliveryScan.force_raycast_update()
					if not $DeliveryScan.is_colliding():
						cancel_ops = true
						break
					collision_spots.append($DeliveryScan.get_collision_point())
				if cancel_ops:
					break
			if cancel_ops:
				continue
			
			for n in collision_spots:
				for b in collision_spots:
					if n.distance_squared_to(b) > 16:
						cancel_ops = true
						break
				if cancel_ops:
					break
			
			if cancel_ops:
				continue
			
			satisfied_dpoint = true
		$DeliveryPoint.position = selected_dpoint
		$MainMenuAnim.play("MenuFade")
		add_child(playerScene.instantiate())
		initialized = true

func _on_lightning_timeout():
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	for n in randi_range(1, 4):
		tween.chain().tween_property($Star, "light_color", 
			Color.from_ok_hsl(0.76, 1.0, 0.02 + randf_range(0.01, 0.1)), randf_range(0, 0.1))
		tween.parallel().tween_property(%MainMenu.get_node("Title"), "theme_override_colors/font_color", 
			Color.from_ok_hsl(0.76, 1.0, 0.02 + randf_range(0.01, 0.1)), randf_range(0, 0.1))
		tween.chain().tween_property($Star, "light_color", DEFAULT_LIGHT, randf_range(0.05, 0.3))
		tween.parallel().tween_property(%MainMenu.get_node("Title"), "theme_override_colors/font_color", Color.WHITE, randf_range(0.05, 0.3))
	$Lightning.wait_time = randf_range(5.0, 30.0)
	$Lightning.start()


func _on_play_pressed():
	start_game()

func _on_main_menu_anim_animation_finished(anim_name):
	if anim_name == "MenuStart":
		$MainMenuLayer/MainMenu/Play.disabled = false
		$MainMenuLayer/MainMenu/Options.disabled = false
		$MainMenuLayer/MainMenu/Exit.disabled = false
	elif anim_name == "MenuFade":
		%MainMenu.hide()

func _on_exit_pressed():
	get_tree().quit()

func _on_options_pressed():
	%Options.show()
	%MainMenu.hide()

func _on_back_pressed():
	%MainMenu.show()
	%Options.hide()

func _on_fullscreen_item_selected(index):
	match index:
		0:
			get_window().mode = Window.MODE_WINDOWED
		1:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		2:
			get_window().mode = Window.MODE_FULLSCREEN

func _on_difficulty_item_selected(index):
	match index:
		0:
			jetpack_fuel_economy = 0.0
		1:
			jetpack_fuel_economy = 0.8
		2:
			jetpack_fuel_economy = 1.1


func _on_h_slider_value_changed(value):
	if is_zero_approx(value):
		$Buzz.volume_db = -80
	else:
		$Buzz.volume_db = value * 20 - 20
