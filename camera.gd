extends CharacterBody2D

@export_range(1, 1000, 100) var speed : int = 400

var zoom_step = 0.1

func _process(_delta: float) -> void:
	_get_input()
	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed('zoom_in'):
		$Camera2D.zoom += Vector2.ONE * zoom_step
	if event.is_action_pressed('zoom_out'):
		$Camera2D.zoom -= Vector2.ONE * zoom_step
	
	$Camera2D.zoom = $Camera2D.zoom.clamp(Vector2.ZERO, Vector2(5.0, 5.0))

	
func _get_input() -> void:
	var input_dir = Input.get_vector('move_left', 'move_right', 'move_up', 'move_down')
	velocity = input_dir * speed
