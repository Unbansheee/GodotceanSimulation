extends RefCounted
class_name TimerCounter

var t: float = 0
var scale: float = 1.0

var running: bool = true
var time_prev : float = Time.get_ticks_msec() * 1000.0

func update() -> float:
	if not running: return 0.0
	var time_current = Time.get_ticks_msec() * 1000.0
	var dt = scale*(time_current-time_prev)
	time_prev = time_current
	t += dt
	return dt
	
func start():
	running = true
	time_prev = Time.get_ticks_msec() * 1000.0
	
func stop():
	running = false


