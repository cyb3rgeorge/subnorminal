extends ProgressBar

@export var starship: Starship

func _ready():
	starship.throttleTelemetry.connect(update)
	update()

func update():
	value = starship.throttle
