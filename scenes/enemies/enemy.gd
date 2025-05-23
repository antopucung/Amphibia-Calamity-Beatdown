extends KinematicBody

var vfxScene = preload("res://scenes/vfx.tscn")
var coinScene = preload("res://scenes/pickups/coin.tscn")
var khaoScene = preload("res://scenes/pickups/khao.tscn")
var mushScene = preload("res://scenes/pickups/mush.tscn")

export var speedWalk = 8
export var damage = 10

export var weakAttacker = false

export var printVals = false

export var maxCoins = 5
export var minCoins = 2
export var oddsDrop = 0.10 # 0.10
export var oddsKhao = 0.20 
export var broke = false
export var infEnemy = false #if true, enemy does not count towards kills. Used for spawners and summons
export var startRight = false
export var ambushEnemy = false # if true, kills count towards ambush kill counts
export var color = 0 # determines behavior besed on the enemy color (green vs yellow mantis)

export var hp = 100


var velocity = Vector3.ZERO
var velocityG = Vector3.ZERO
var velocityE = Vector3.ZERO
var direction = Vector2.ZERO
var lookRight = false

var mini_jump_boost = 20
var force_grav = 125.0
var snapVect  = Vector3.ZERO

var hitDamage = 0
var hitType = 0
var hitDir = Vector3.ZERO

var justHurt = false
var invincible = false
var hurtAgain = false
var hurtDamage = 0
var hurtType = 0
var hurtDir = Vector3.ZERO
var invincibleState = false
var deathFloorHeight = -30

var target = null
var targetFound = false
var aggroReset = false
var walkTo = Vector3.ZERO
var targetOffset = 2.5
var xAttackRange = 3 #3
var zAttackRange = 1.25
var attackWaitCounter = 0
var attackResetTime = 70
var blockWaitCounter = 60


var enemyPush = Vector3.ZERO

var windVect = Vector3.ZERO

#var attackWaitCounter = 1500
#var attackReady = false

enum {IDLE, WALK, HURT, HURTLAUNCH, HURTRISING, HURTFALLING, HURTFLOOR, A_H, BLOCK, BLOCKHIT, KO, SPAWN, A_L, A_P, DODGE, THINK}
enum {KB_WEAK, KB_STRONG, KB_ANGLED, KB_AIR, KB_STRONG_RECOIL, KB_AIR_UP, KB_WEAK_PIERCE, KB_STRONG_PIERCE, KB_ANGLED_PIERCE}
enum {LIGHT, HEAVY, VERYHEAVY}

export var weight = LIGHT

var state = IDLE
var nextState = IDLE

onready var anim = $"AnimationPlayer"
onready var sprite = $"zeroPoint/AnimatedSprite3D"
var animFinished = false

var onRightWall = false
var onLeftWall = false
var alreadyBounced = false

func isInState(list):
	var found = false
	for i in list:
		if state == i:
			found = true
	return found

func setHitBox(attackDamage, type, dir):
	hitDamage = attackDamage
	hitType = type
	hitDir = dir # for direction, +x and +y means away and up. ~10 for magnitude
	if (lookRight == false):
		hitDir.x *= -1
		
func despawn():
	# Adds 1 to kill counter
	if (infEnemy == false):
		pg.killsTotal += 1
	if (ambushEnemy== true):
		pg.kills += 1
	# update drop counts/odds
	minCoins += (pg.luckUpgrades * pg.coinBoost)
	if (minCoins > maxCoins):
		minCoins = maxCoins
	oddsDrop += (pg.luckUpgrades * pg.dropBoost)
	#print(oddsDrop)
	queue_free()
	# spawns items/money
	if broke:
		return
	else:
		var coinsLeft = rng.rand.randi_range(minCoins, maxCoins)
		while (coinsLeft > 0):
			if (coinsLeft >= 20):
				var coins = coinScene.instance()
				get_parent().add_child(coins)
				coins.initialize(translation, 20)
				coinsLeft -= 20
			elif (coinsLeft >= 5):
				var coins = coinScene.instance()
				get_parent().add_child(coins)
				coins.initialize(translation, 5)
				coinsLeft -= 5
			else:
				var coins = coinScene.instance()
				get_parent().add_child(coins)
				coins.initialize(translation, 1)
				coinsLeft -= 1
#		for i in rng.rand.randi_range(minCoins, maxCoins):
#			var coins = coinScene.instance()
#			get_parent().add_child(coins)
#			coins.initialize(translation)
		var food = null
		if (rng.rand.randf() <= oddsDrop):
			food = mushScene.instance()
			if (rng.rand.randf() <= oddsKhao):
				food = khaoScene.instance()
			get_parent().add_child(food)
			food.initialize(translation)

	
func checkInRange(targetPlayer):
	if (targetPlayer != null):
		if(abs(targetPlayer.translation.x - translation.x) <= xAttackRange) and (abs(targetPlayer.translation.z - translation.z) <=zAttackRange):
			return true
		else:
			return false
			
func attackCounterReady():
	if (attackWaitCounter <= 0):
		attackWaitCounter = attackResetTime
		return true
	else:
		return false
		
func blockCounterReady():
	if (blockWaitCounter <= 0):
		return true
	else:
		return false
func blockCounterReset():
	blockWaitCounter = rng.rand.randi_range(60, 90)
		
func reduce(value, amount):
	if (abs(value) <= amount):
		value = 0
	elif value > 0:
		value -= amount
	else:
		value += amount
	return value
	
func rollOffensiveAction():
	blockCounterReset()
	match color:
		0: # Green -------------------------------
			return A_H
		1: # Yellow -------------------------------
			return equalOdds([BLOCK, A_H, A_L])
		2: # Black -------------------------------
			return equalOdds([DODGE, A_H, A_L])
		3: # Red -------------------------------
			return equalOdds([DODGE, A_H, A_L, A_P])
			
func rollDefensiveAction():
	blockCounterReset()
	match color:
		0: # Green -------------------------------
			return equalOdds([BLOCK, A_H])
		1: # Yellow -------------------------------
			return equalOdds([BLOCK, A_H, A_L])
		2: # Black -------------------------------
			return equalOdds([DODGE, A_L])
		3: # Red -------------------------------
			return IDLE

# returns a random object/state in the given array. Each has the same chance of returning.
func equalOdds(stateArray):
	var i = rng.rand.randi_range(0, len(stateArray)-1)
	return stateArray[i]
	

func _ready():
	if (startRight):
		lookRight = true
	else:
		lookRight = false
	# makes arrow invisible if the enemy has one
	if get_node_or_null("zeroPoint/AnimatedSprite3D/arrow") != null:
		if pg.hardMode:
			get_node("zeroPoint/AnimatedSprite3D/arrow").play("invis")
		else:
			get_node("zeroPoint/AnimatedSprite3D/arrow").play("default")

#func initialize(loc, vel, spd, dam, hlth, wgt, maxC, minC, oddsD = 0.1, oddsK = 0.2, brk = false, weakA = false, infVision = false):
#	translation = loc
#	velocity = vel
#	speedWalk = spd
#	damage = dam
#	hp = hlth
#	weight = wgt
#	maxCoins = maxC
#	minCoins = minC
#	oddsDrop = oddsD
#	oddsKhao = oddsK
#	broke = brk
#	weakAttacker = weakA
#	if infVision:
#		#$aggro/CollisionShape.shape.radius = 100
#		targetFound = true
#		# picks a random target
#		target = rng.rand.randi_range(0, 3)
#		while (pg.playerAlive[target] == false):
#			target = rng.rand.randi_range(0, 3)
#		target = get_parent().get_node_or_null("Player" + str(target))

func initialize(type, loc, vel = Vector3.ZERO, brk = false, infVis = false, infEn = false):
	translation = loc
	velocity = vel
	broke = brk
	infEnemy = infEn
	speedWalk = type.spd
	damage = type.dam
	hp = type.hlth
	weight = type.wgt
	maxCoins = type.maxC
	minCoins = type.minC
	oddsDrop = type.oddsD
	oddsKhao = type.oddsK
	weakAttacker = type.weakA
	attackResetTime = type.attackWaitTime
	color = type.color
	
	# puts enemy in waiting "SPAWN" state and picks a random facing direction
	state = SPAWN
	nextState = SPAWN
	if velocity.x >= 0:
		lookRight = true
	else:
		lookRight = false
	# Sets up target and aggro collision if the enemy has infinite vision (like if from spawner)
	if infVis:
		get_node("aggro/CollisionShape").get_shape().radius = 100
		get_node("aggro/CollisionShape").get_shape().height = 100
		targetFound = true
		# picks a random target
		target = rng.rand.randi_range(0, 3)
		while (pg.playerAlive[target] == false):
			target = rng.rand.randi_range(0, 3)
		target = get_node_or_null("/root/" + pg.levelName + "/Player" + str(target))

func _physics_process(delta):
	
	# state changes
	match state:
		SPAWN:
			if is_on_floor():
				nextState = IDLE
			else:
				nextState = SPAWN
		IDLE:
			if (targetFound) and (attackCounterReady()):
				nextState = WALK
			else:
				nextState = IDLE
		WALK:
			if (targetFound == false):
				nextState = IDLE
			elif checkInRange(target):
				nextState = rollOffensiveAction()
			else:
				nextState = WALK
		DODGE:
			if (animFinished):
				animFinished = false
				if (rng.rand.randf() >= 0.5):
					nextState = BLOCK
				else:
					nextState = IDLE
			else:
				nextState = DODGE
		HURT:
			if (animFinished):
				animFinished = false
				nextState = rollDefensiveAction()
			else:
				nextState = HURT
		HURTLAUNCH:
			nextState = HURTRISING
		HURTRISING:
			if (velocity.y <= 0):
				nextState = HURTFALLING
			else:
				nextState = HURTRISING
		HURTFALLING:
			if is_on_floor():
				nextState = HURTFLOOR
			else:
				nextState = HURTFALLING
		HURTFLOOR:
			if (hp <= 0):
				nextState = KO
			elif (animFinished):
				animFinished = false
				nextState = IDLE
			else:
				nextState = HURTFLOOR
		A_H:
			if animFinished:
				nextState = IDLE
				animFinished = false
		A_L:
			if animFinished:
				nextState = IDLE
				animFinished = false
		A_P:
			if animFinished:
				nextState = IDLE
				animFinished = false
		BLOCK:
			if (blockCounterReady()):
				if checkInRange(target):
					nextState = A_H
				else:
					nextState = IDLE
			else:
				nextState = BLOCK
		BLOCKHIT:
			if (animFinished):
				nextState = BLOCK
				animFinished = false
			else:
				nextState = BLOCKHIT
		KO:
			nextState = KO
			if (animFinished):
				animFinished = false
				despawn()
		_:
			state = IDLE
			nextState = IDLE
	# taking damage
	if (isInState([KO, SPAWN])):
		invincibleState = true
	else:
		invincibleState = false
	if (justHurt):
		blockCounterReset()
		justHurt = false
		#print("HIT")
		if isInState([BLOCK]) and ((hurtType == KB_WEAK) or (weight == VERYHEAVY)):
			nextState = BLOCKHIT
			hurtDamage = 0
		elif isInState([BLOCKHIT]) and ((hurtType == KB_WEAK) or (weight == VERYHEAVY)):
			hurtAgain = true
			nextState = BLOCKHIT
			hurtDamage = 0
		elif (weight == VERYHEAVY) and (hp >= 0):
			pass
		elif (hurtType == KB_STRONG) or (hurtType == KB_ANGLED) or (hurtType == KB_ANGLED_PIERCE):
			if (weight == LIGHT) or (hp <= 0):
				nextState = HURTLAUNCH				
			elif isInState([HURT]):
				hurtAgain = true
				nextState = HURT
			else:
				nextState = HURT
		elif isInState([HURT]):
			hurtAgain = true
			nextState = HURT
		else:
			nextState = HURT
		hp -= hurtDamage
		if (get_node_or_null("dummyLifebar") != null):
			get_node("dummyLifebar").dealDamage(hurtDamage)
		#print(str(hurtDamage))
	state = nextState
	
	# resets animFinished if in looping animation state to prevent bugs
	if (isInState([IDLE, HURTFALLING, HURTRISING, BLOCK])):
		animFinished = false

	# attack delay counter
	if (isInState([A_H, A_L, A_P])):
		attackWaitCounter = attackResetTime
	elif (attackWaitCounter > 0):
		attackWaitCounter -= 1
		
	# blocking delay
	if (isInState([BLOCK, BLOCKHIT])):
		blockWaitCounter -= 1
		
	# sets up hitbox
	if isInState([A_H]):
		setHitBox(damage, KB_STRONG, Vector3(20, 20, 0))
	elif isInState([A_L]):
		setHitBox(0.35 * damage, KB_WEAK, Vector3(1, 0, 0))
	elif isInState([A_P]):
		setHitBox(1.25 * damage, KB_ANGLED_PIERCE, Vector3(25, 30, 0))
		
	# turns on/off enemy only ground for walk off barriers
	if (isInState([WALK, IDLE, DODGE])):
		set_collision_mask_bit(11, true)
	else:
		set_collision_mask_bit(11, false)
	
	# Y movement	
	velocity.y -= force_grav * delta

	# X movement
	if isInState([WALK]):
		# determines where the enemy should walk to (which side of the player
		# IF YOU GET AN ERROR HERE WHEN SPAWNING ENEMIES,
		# VERIFY THE LEVEL NODE'S NAME IS CORRECT!
		if (translation > target.translation):
			walkTo = target.translation + Vector3(targetOffset, 0, 0)
		else:
			walkTo = target.translation - Vector3(targetOffset, 0, 0)
		# sets direction
		direction.x = walkTo.x - translation.x
		direction.y = walkTo.z - translation.z
		direction = direction.normalized()
		# sets velocity
		velocity.x = speedWalk * direction.x
		velocity.z = speedWalk * direction.y
		# sets look direction
		if (target.translation.x  > translation.x):
			lookRight = true
		elif (target.translation.x  < translation.x):
			lookRight = false
	elif isInState([DODGE]):
		# determines where the enemy should walk to
		if (target == null):
			walkTo = translation
		else:
			walkTo = target.translation
		# sets direction
		direction.x = translation.x - walkTo.x
		direction.y = translation.z - walkTo.z
		direction = direction.normalized()
		# sets velocity
		velocity.x = speedWalk * direction.x * 1.2
		velocity.z = speedWalk * direction.y * 1
		# sets look direction
		if (target != null) and (target.translation.x  > translation.x):
			lookRight = true
		elif (target != null) and (target.translation.x  < translation.x):
			lookRight = false
		else:
			lookRight = true
	elif isInState([HURTLAUNCH, HURTRISING, HURTFALLING, SPAWN]):
		pass
	else:
		velocity.x = 0
		velocity.z = 0
		
	# knockback
	if isInState([HURTLAUNCH]):
		velocity.x = hurtDir.x
		velocity.y = hurtDir.y
		velocity.z = hurtDir.z
	
	# enemy pushback
	if (isInState([SPAWN]) == false):
		enemyPush = Vector3.ZERO
		for area in $enemyPushback.get_overlapping_areas():
			enemyPush.x += translation.x - area.get_parent().translation.x
			enemyPush.z += translation.z - area.get_parent().translation.z
		enemyPush = 3*enemyPush.normalized()
		velocity.x += enemyPush.x
		velocity.z += enemyPush.z
	
	# barrier pushback / bounceback
	if ambushEnemy and (isInState([HURTFLOOR, HURTLAUNCH])):
		alreadyBounced = false
	if isInState([HURTLAUNCH, HURTRISING, HURTFALLING]):
		if (onRightWall and (velocity.x > 0) and ambushEnemy and !alreadyBounced):
			velocity = Vector3(-25, 15, 0)
			alreadyBounced = true
		elif onLeftWall and (velocity.x < 0) and ambushEnemy and !alreadyBounced:
			velocity = Vector3(25, 15, 0)
			alreadyBounced = true
	else:
		if onRightWall and (velocity.x > 0) and ambushEnemy:
			velocity.x = 0
		elif onLeftWall and (velocity.x < 0) and ambushEnemy:
			velocity.x = 0
		
	
	# snapping setup
	if isInState([HURTLAUNCH, HURTRISING, SPAWN]):
		snapVect = Vector3.ZERO
	else:
		snapVect = Vector3(0, -5, 0)
	# move and slide
	move_and_slide(windVect, Vector3.UP, true)
	velocity = move_and_slide_with_snap(velocity, snapVect, Vector3.UP, true)
	
	# mirror enemy if necessary
	if (lookRight == true):
		sprite.set_rotation_degrees(Vector3(-15, 90, 0))
		$"zeroPoint".set_rotation_degrees(Vector3(0, 180, 0))
	else:
		sprite.set_rotation_degrees(Vector3(15, 90, 0))
		$"zeroPoint".set_rotation_degrees(Vector3(0, 0, 0))
	
	
	# animations
	if isInState([IDLE, SPAWN]):
		anim.play("idle")
	elif isInState([HURT]):
		anim.play("hurt")
		if (hurtAgain):
			hurtAgain = false
			anim.seek(0)
	elif isInState([HURTRISING]):
		anim.play("hurt_air")
	elif isInState([HURTFALLING]):
		anim.play("hurt_air")
	elif isInState([HURTFLOOR]):
		anim.play("hurt_floor")
	elif isInState([BLOCK]):
		anim.play("block")
	elif isInState([BLOCKHIT]):
		anim.play("block_hit")
		if (hurtAgain):
			hurtAgain = false
			anim.seek(0)
	elif isInState([A_H]):
		anim.play("attack_heavy")
	elif isInState([A_L]):
		anim.play("attack_light")
	elif isInState([A_P]):
		anim.play("attack_pierce")
	elif isInState([DODGE]):
		anim.play("dodge")
	elif isInState([WALK]):
		anim.play("walk")
	elif isInState([KO]):
		anim.play("dead")
	
	# fall off world
	if (translation.y <= deathFloorHeight):
		despawn()
	
	# waits for a cycle before turning aggro box back on
	if (aggroReset):
		aggroReset = false
		get_node("aggro/CollisionShape").disabled = false
	if (get_node("aggro/CollisionShape").disabled == true):
		aggroReset = true
	
	# labels/prints for testing
#	if (printVals == true) and (target != null):
#		$Label.text = str(state) + "\n" + str(hp) + "\n" + str(targetFound) + "\n" + str(target.translation)
#	elif (printVals == true):
#		$Label.text = str(state) + "\n" + str(hp) + "\n" + str(targetFound) + "\n"


func _on_AnimationPlayer_animation_finished(_anim_name):
	animFinished = true
	# note: only applies nor non-looping animations

func _on_hurtbox_area_entered(area):
	# one way barriers for ambushes
	if area.is_in_group("oneWayRight"):
		onLeftWall = true
		return
	elif area.is_in_group("oneWayLeft"):
		onRightWall = true
		return
	# environmental stuff
	elif area.is_in_group("windboxes"):
		windVect = area.direction.normalized() * area.magnitude
		return
	# identifies attacker
	var attacker = area.get_parent().get_parent()
	# returns if in an invincible state (just got hit)
	if (invincible == false) and (invincibleState == false):
		justHurt = true
	else:
		return
	# makes enemy unhittable until it leaves a hitbox
	invincible = true
	# Produces hit vfx
	var vfx = vfxScene.instance()
	get_parent().add_child(vfx)
	vfx.playEffect("hit", 0.5*(translation + attacker.translation))
	# sets attacker as the target and tells attacker that the hit occurred
	if (attacker.playerChar != "proj") and (attacker.playerChar != "hazard"):
		target = attacker
	attacker.hitLanded = true
	# stores damage/knockback variables
	hurtDamage = attacker.hitDamage
	hurtType = attacker.hitType
	hurtDir = attacker.hitDir
	# increases damage from hazards compared to players
	if (attacker.playerChar == "hazard"):
		hurtDamage *= 2
	# changes knockback values depending on the type and situation (type should end up as either weak or strong):
	# changes x-z knokback angle to be away from player if an angled attack
	if (hurtType == KB_ANGLED) or (hurtType == KB_ANGLED_PIERCE):
		var mag = abs(attacker.hitDir.x)
		var ve = Vector2(translation.x, translation.z)
		var vp = Vector2(attacker.translation.x, attacker.translation.z)
		var newDir = Vector2.ZERO
		newDir = ve - vp
		newDir = newDir.normalized() * mag
		hurtDir.x = newDir.x
		hurtDir.z = newDir.y
	# changes attack type to weak if hit with air attack while grounded (and attacker is not rising)
	elif (hurtType == KB_AIR) and (is_on_floor() and (attacker.velocity.y <= 0)):
		hurtType = KB_WEAK
	# changes attack type to strong and sets knock back equal to player movement if hit with air attack in mid air or rising attack while grounded
	elif (hurtType == KB_AIR):
		hurtType = KB_STRONG
		# adds an additional boost if player is falling
		if attacker.velocity.y <= mini_jump_boost:
			hurtDir = Vector3(attacker.velocity.x, mini_jump_boost, attacker.velocity.z)
			attacker.mini_jump_boost = mini_jump_boost # caused player to get velocity boost too
		else:
			hurtDir = attacker.velocity
	# changes attack type to strong and signals attacker if hit with a move that has knockback
	elif (hurtType == KB_STRONG_RECOIL):
		hurtType = KB_STRONG
		attacker.recoilStart = true
	elif (hurtType == KB_AIR_UP):
		hurtType = KB_STRONG
		hurtDir = Vector3(attacker.velocity.x, hurtDir.y, attacker.velocity.z)
	if (hurtType == KB_WEAK) and (hp <= 0):
		hurtType = KB_ANGLED
		hurtDir = Vector3(hurtDir.x * 10, 30, 0)
	# makes enemy look at attacker
	if (attacker.translation.x > translation.x):
		lookRight = true
	else:
		lookRight = false
	# plays sfx
	if isInState([BLOCK, BLOCKHIT]):
		soundManager.playSound("block")
	else:
		soundManager.playSound(attacker.hitSound)
		
func _on_hurtbox_area_exited(area):
	if area.is_in_group("oneWayRight"):
		onLeftWall = false
		return
	elif area.is_in_group("oneWayLeft"):
		onRightWall = false
		return
	elif area.is_in_group("windboxes"):
		windVect = Vector3.ZERO
		return
	else:
		invincible = false



func _on_aggro_area_entered(area):
	if (targetFound == false):
		target = area.get_parent().get_parent()
		targetFound = true

func _on_aggro_area_exited(area):
	if (area.get_parent().get_parent() == target):
		targetFound = false
		target = null
		get_node("aggro/CollisionShape").disabled = true

