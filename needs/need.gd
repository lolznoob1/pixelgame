extends RefCounted
class_name Need
## One need (hunger, thirst): a value from 0 to 100 that runs down over time and is restored by consuming items.

var value: float = 100.0
var max_value: float = 100.0
## How many units are lost per minute.
var rate_per_minute: float = 0.0


func tick(delta: float, rate_multiplier: float = 1.0) -> void:
	value = maxf(value - rate_per_minute * rate_multiplier * delta / 60.0, 0.0)


func restore(amount: float) -> void:
	value = minf(value + amount, max_value)


func fraction() -> float:
	return value / maxf(max_value, 0.001)


func is_empty() -> bool:
	return value <= 0.0


func is_full() -> bool:
	return value >= max_value
