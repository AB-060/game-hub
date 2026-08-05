class_name BallStateData

var lock_duration : int
var spin : float

static func build() -> BallStateData:
	return BallStateData.new()

func set_lock_duration(duration: int) -> BallStateData:
	lock_duration = duration
	return self

func set_spin(value: float) -> BallStateData:
	spin = value
	return self
