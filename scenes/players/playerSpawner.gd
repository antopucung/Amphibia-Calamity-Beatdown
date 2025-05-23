extends Spatial

# this scripts calls into the scene:
#	Players
#	Camera
#   Overhead Light (for shadows
#	Pause Screen Scene
#	Game over screen/checker
#	Music


var AnneScene  = preload("res://scenes/players/Anne.tscn")
var SashaScene = preload("res://scenes/players/Sasha.tscn")
var MarcyScene = preload("res://scenes/players/Marcy.tscn")
var SprigScene = preload("res://scenes/players/Sprig.tscn")
var MaggieScene = preload("res://scenes/players/Maggie.tscn")
var GrimeScene = preload("res://scenes/players/Grime.tscn")
var DarlaScene = preload("res://scenes/players/Darla.tscn")

var camScene = preload("res://scenes/cam.tscn")
var pauseScene = preload("res://scenes/menus/pauseScreen.tscn")
var GOScene = preload("res://scenes/menus/gameOverScreen.tscn")
var lightScene = preload("res://scenes/downwardLight.tscn")

var player = AnneScene.instance()
var offset = Vector3.ZERO
var spawnerLocation = Vector3.ZERO

var nextScene = camScene.instance()

export var hideGUI = false
export var noCameraWalls = false
export var cartSpawnOffset = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	# repositions spawner if needed for minecart returns
	if pg.karting:
		translation = translation + cartSpawnOffset
	# resets reposition player flags
	for i in range(0, 4):
		pg.playerFixPos[i] = false
	# moves spawner to appropriate location if in wartwood
	if (pg.levelNum == 0):
		match pg.currentStore:
			0: 
				spawnerLocation = translation
			1: #City Hall
				spawnerLocation = translation
			2: #Maddie
				spawnerLocation = Vector3(-382.109, -0.131, -8.907)
			3: #Felicia
				spawnerLocation = Vector3(246.903, 1.623, 7.669)
			_:
				spawnerLocation = translation
		translation = spawnerLocation


func _process(_delta):
	# Sets globals BEFORE spawning players since player initializations use these vars
	if pg.initialSpawn:
		for i in range(0, 4):
			pg.playerAlive[i] = pg.playerActive[i]
	for i in range(0, 4):
		# skips player spawning if there is none
		if (pg.playerAlive[i] == false):
			continue
		# determines character choice and sets player variable
		match pg.playerCharacter[i]:
			"Anne":
				player = AnneScene.instance()
			"Marcy":
				player = MarcyScene.instance()
			"Sasha":
				player = SashaScene.instance()
			"Sprig":
				player = SprigScene.instance()
			"Maggie":
				player = MaggieScene.instance()
			"Grime":
				player = GrimeScene.instance()
			"Darla":
				player = DarlaScene.instance()
			_:
				player = AnneScene.instance()
		# Adds instance of player to tree
		get_parent().add_child(player)
		# Determines player position
		match i:
			0:
				offset = Vector3(-3, 0, -3)
			1:
				offset = Vector3(3, 0, -3)
			2:
				offset = Vector3(-3, 0, 3)
			3:
				offset = Vector3(3, 0, 3)
			_:
				offset = Vector3.ZERO
		# initializes player
		player.initialize(i, (translation + offset), pg.playerCharacter[i])
		# hides GUI if necessary
		if (hideGUI):
			player.get_node("playerInfo").visible = false
		
	# adds camera scene
	nextScene = camScene.instance()
	get_parent().add_child(nextScene)
	nextScene.get_node("Camera").initialize(translation)
	if noCameraWalls:
		nextScene.get_node("leftWall").queue_free()
		nextScene.get_node("rightWall").queue_free()
	
	# adds pause scene
	nextScene = pauseScene.instance()
	get_parent().add_child(nextScene)
	nextScene.hide()
	
	# adds game over scene
	nextScene = GOScene.instance()
	get_parent().add_child(nextScene)
	nextScene.hide()
	
	# adds main light scene
	nextScene = lightScene.instance()
	get_parent().add_child(nextScene)
	
	# plays music
	# April Fools
	if ("Maggie" in pg.playerCharacter) and (pg.levelName == "bestFrondsHard"):
		pg.levelMusic = "mag"
	soundManager.playMusic(pg.levelMusic)
	
	# sets player movement/cutscene flag so they can act
	pg.dontMove = false
	
	# sets flag for minecart levels to false
	pg.karting = false
	
	# sets level in discord thing
	discordRPC.updateLevel(pg.levelNameDisc)
	
	#removes spawner
	queue_free()
