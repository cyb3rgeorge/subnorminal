extends ProgressBar

@export var starship: Starship

func _ready():
	starship.propTelemetry.connect(update)
	update()
	
func update():
	value = starship.prop
