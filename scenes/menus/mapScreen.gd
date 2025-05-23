extends Control


var posDes = Vector2(360, 640)
var zoomDes = Vector2(0.5, 0.5)
var phonePosDes = Vector2(0, 500)
var markerOffset = -15
var markerThreshold = 3
var markerSpeed = 160
var currentButton = null
var camThreshold = 0.5
onready var cam = get_node("cam")
onready var marker = get_node("marker")
onready var phone = get_node("cam/phone")
onready var playButton = get_node("cam/phone/playButton")
var loading = false
var infoScreen = false
var lastLevel = 0

enum {READY, UP, DOWN, LEFT, RIGHT}
var markerState = READY


# Called when the node enters the scene tree for the first time.
func _ready():
	# tells pg that news load in of characters will be for inital level spawns
	pg.initialSpawn = true
	pg.karting = false
	# re-enables dropping players from pause menu
	pg.dropPlayerEnabled = true
	# music stuff
	soundManager.playMusicIfDiff("menu")
	soundManager.follow2DCam = true
	discordRPC.updateLevel("Checking the map", "Currently:")
	cam.zoom = Vector2(1,1)
	loading = false
	get_node("cam/pockets/totalMoney").text = str(pg.totalMoney)
	# sets starting positions
	get_node("wart").grab_focus()
	posDes = get_node("wart").rect_position + Vector2(get_node("wart").rect_size / 2)
	posDes.y += markerOffset
	marker.position = posDes
	#resets store variable just in case
	pg.currentStore = 0
	# hides/disables not yet unlocked levels
	for i in range(3, len(pg.completedLevels)-1):
		if (pg.completedLevels[i - 1]):
			get_node("lvl" + str(i - 1)).disabled = false
			get_node("lvl" + str(i - 1)).set_focus_mode(2)
		else:
			get_node("lvl" + str(i - 1)).disabled = true
			get_node("lvl" + str(i - 1)).set_focus_mode(0)
	if (pg.unlockedFinalLevel):
		get_node("lvl10").disabled = false
		get_node("lvl10").set_focus_mode(2)
	else:
		get_node("lvl10").disabled = true
		get_node("lvl10").set_focus_mode(0)
	# re-disables level 2/3 and playground for demo purposes
#		get_node("lvl2").disabled = true
#		get_node("lvl2").set_focus_mode(0)
#		get_node("play").disabled = true
#		get_node("play").set_focus_mode(0)
#		get_node("lvl3").disabled = true
#		get_node("lvl3").set_focus_mode(0)
	# removes arrow if been to wartwood
	if (pg.firstTimeInWartwood == false):
		$"arrow".hide()
		$"arrow".queue_free()
	else:
		$"arrow".show()

func _process(delta):
	#positions marker
	if (marker.position == posDes):
		markerState = READY
	# Y movement. Y first so L/R sprite takes priority over U/D
	if (marker.position.y == posDes.y):
		pass
	elif (abs(marker.position.y - posDes.y) < markerThreshold):
		marker.position.y = posDes.y
	elif (marker.position.y > posDes.y):
		marker.position.y -= markerSpeed * delta
		markerState = UP
	else:
		marker.position.y += markerSpeed * delta
		markerState = DOWN
	# X movement
	if (marker.position.x == posDes.x):
		pass
	elif (abs(marker.position.x - posDes.x) < markerThreshold):
		marker.position.x = posDes.x
	elif (marker.position.x > posDes.x):
		marker.position.x -= markerSpeed * delta
		markerState = LEFT
	else:
		marker.position.x += markerSpeed * delta
		markerState = RIGHT
	
	# marker animation
	match markerState:
		READY:
			marker.play("idle")
			marker.set_scale(Vector2(1.0, 1.0))
		UP:
			marker.play("up")
			marker.set_scale(Vector2(1.3, 1.3))
		DOWN:
			marker.play("down")
			marker.set_scale(Vector2(1.3, 1.3))
		LEFT:
			marker.play("left")
			marker.set_scale(Vector2(1.0, 1.0))
		RIGHT:
			marker.play("right")
			marker.set_scale(Vector2(1.0, 1.0))
		_:
			marker.play("idle")
			marker.set_scale(Vector2(1.0, 1.0))
	
	#positions camera
	if (cam.position != posDes):
		cam.position.x += (posDes.x - cam.position.x) * delta * 3
		cam.position.y += (posDes.y - cam.position.y) * delta * 3
	if (abs(cam.position.y - posDes.y) < camThreshold) and (abs(cam.position.x - posDes.x) < camThreshold):
		cam.position = posDes
#	cam.position.x = marker.position.x
#	cam.position.y = marker.position.y
	cam.zoom.x += 0.2*(zoomDes.x - cam.zoom.x)
	cam.zoom.y += 0.2*(zoomDes.y - cam.zoom.y)
	soundManager.scale = cam.zoom
	soundManager.position = cam.position - Vector2((cam.zoom.x * 1280 * 0.5), (cam.zoom.y * 720 * 0.5))
	
	
	# "back" Inputs
	if !infoScreen:
		if (Input.is_action_just_pressed("k0_leave") == true) and (loading == false):
			loading = true
			tran.loadLevel("res://scenes/menus/title.tscn")
		for i in range(0, 3):
			if (Input.is_action_just_pressed(str(i) + "_leave") == true) and (loading == false):
				loading = true
				tran.loadLevel("res://scenes/menus/title.tscn")
	else: # if infoscreen is active
		if (Input.is_action_just_pressed("k0_leave") == true):
			infoScreen = false
			focusOnStage(pg.levelNum)
			playButton.hide()
			playButton.set_focus_mode(0)
		for i in range(0, 3):
			if (Input.is_action_just_pressed(str(i) + "_leave") == true) and (loading == false):
				infoScreen = false
				focusOnStage(pg.levelNum)
				playButton.hide()
				playButton.set_focus_mode(0)
	# Phone positioning
	if infoScreen:
		phonePosDes = Vector2(0, 0)
	else:
		phonePosDes = Vector2(0, 500)
	phone.position.y += (phonePosDes.y - phone.position.y) * delta * 8
	# check box for level completion
	if (pg.levelNum == 0):
		$cam/phone/checkBox.play("none")
	elif pg.completedLevels[pg.levelNum]:
		$cam/phone/checkBox.play("check")
	else:
		$cam/phone/checkBox.play("uncheck")
	
	
func focusOnStage(levelNum):
	if (levelNum == 0):
		get_node("wart").grab_focus()
	elif (levelNum == 1):
		get_node("play").grab_focus()
	else:
		get_node("lvl" + str(pg.levelNum - 1)).grab_focus()

func _on_lvl_pressed():
	infoScreen = true
	playButton.set_focus_mode(2)
	playButton.show()
	playButton.grab_focus()
	
func fucusOnButton(buttonNode):
	marker.position = posDes
	posDes = buttonNode.rect_position + Vector2(buttonNode.rect_size / 2)
	posDes.y += markerOffset
	
func _on_playButton_pressed():
	if (loading == false):
		loading = true
		tran.loadLevel("res://scenes/menus/charSelect.tscn")
	else:
		pass
	
func _on_wart_focus_entered():
	fucusOnButton(get_node("wart"))
	pg.levelName = "wartwood"
	pg.levelNameDisc = "Wartwood"
	pg.levelMusic = "wart"
	pg.levelNum = 0
	$cam/phone/levelName.text = "Wartwood"
	$cam/pockets/levelName.text = "Wartwood"
	$cam/phone/levelPic.play("wartwood")
	
func _on_play_focus_entered():
	fucusOnButton(get_node("play"))
	pg.levelName = "playground"
	pg.levelNameDisc = "?-2 Beta Playground"
	pg.levelMusic = "marcy"
	pg.levelNum = 1
	$cam/phone/levelName.text = "Beta Playground"
	$cam/pockets/levelName.text = "Beta Playground"
	$cam/phone/levelPic.play("playground")

func _on_lvl1_focus_entered():
	fucusOnButton(get_node("lvl1"))
	pg.levelName = "bestFronds"
	pg.levelNameDisc = "1-1 Trip to the Lake"
	pg.levelMusic = "swamp"
	pg.levelNum = 2
	$cam/phone/levelName.text = "Trip to the Lake"
	$cam/pockets/levelName.text = "Trip to the Lake"
	$cam/phone/levelPic.play("bestFronds")
	
func _on_lvl3_focus_entered():
	fucusOnButton(get_node("lvl3"))
	pg.levelName = "bestFrondsHard"
	pg.levelNameDisc = "?-1 Bonus Level"
	pg.levelMusic = "nbd"
	pg.levelNum = 4
	$cam/phone/levelName.text = "Trip to the Lake EX"
	$cam/pockets/levelName.text = "Bonus Challenge"
	$cam/phone/levelPic.play("bestFrondsHard")

func _on_lvl2_focus_entered():
	fucusOnButton(get_node("lvl2"))
	pg.levelName = "mountain"
	pg.levelNameDisc = "1-2 The Mountain Pass"
	pg.levelMusic = "mountain"
	pg.levelNum = 3
	$cam/phone/levelName.text = "The Mountain Pass"
	$cam/pockets/levelName.text = "The Mountain Pass"
	$cam/phone/levelPic.play("mountain")


# for demo!
#func _on_lvl2_focus_entered():
#	fucusOnButton(get_node("lvl2"))
#	pg.levelName = "bestFrondsHard"
#	pg.levelNameDisc = "?-1 Bonus Level"
#	pg.levelMusic = "nbd"
#	pg.levelNum = 3
#	$cam/phone/levelName.text = "Trip to the Lake EX"
#	$cam/pockets/levelName.text = "Bonus Challenge"
#	$cam/phone/levelPic.play("bestFrondsHard")


