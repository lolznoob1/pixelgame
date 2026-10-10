extends CharacterBody2D

@export var behavior: EnemyBehavior

func _physics_process(delta: float) -> void:
	if behavior:
		behavior.execute(self, delta)
