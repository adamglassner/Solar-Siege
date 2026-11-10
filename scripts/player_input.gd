class_name PlayerInput
extends RefCounted
## Where one player's controls come from: the keyboard, one specific controller,
## a friend's game over the network, or the test bot.

enum Source { KEYBOARD, PAD, ANY, REMOTE, BOT }

var source := Source.ANY
var device := 0 # controller index for PAD
## Remote / bot state (set from outside)
var remote_axis := 0.0
var remote_fire := false
var remote_bombs := 0 # counts up each time the remote player presses bomb
var _seen_bombs := 0
var _bomb_was := false


static func keyboard() -> PlayerInput:
	var p := PlayerInput.new()
	p.source = Source.KEYBOARD
	return p


static func pad(dev: int) -> PlayerInput:
	var p := PlayerInput.new()
	p.source = Source.PAD
	p.device = dev
	return p


## Single player and online: the keyboard and every controller all work.
static func any() -> PlayerInput:
	return PlayerInput.new()


static func remote() -> PlayerInput:
	var p := PlayerInput.new()
	p.source = Source.REMOTE
	return p


static func bot() -> PlayerInput:
	var p := PlayerInput.new()
	p.source = Source.BOT
	return p


func label() -> String:
	match source:
		Source.KEYBOARD:
			return "Keyboard"
		Source.PAD:
			return "Controller %d" % (device + 1)
		Source.REMOTE:
			return "Online"
		Source.BOT:
			return "Bot"
	return "Keyboard / Controller"


func axis() -> float:
	var v := 0.0
	match source:
		Source.ANY:
			v = Input.get_axis("move_left", "move_right")
		Source.KEYBOARD:
			v = _key_axis()
		Source.PAD:
			v = _pad_axis(device)
		Source.REMOTE, Source.BOT:
			v = remote_axis
	return 0.0 if absf(v) < 0.3 else clampf(v, -1.0, 1.0)


func fire() -> bool:
	match source:
		Source.ANY:
			return Input.is_action_pressed("fire")
		Source.KEYBOARD:
			return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_Z)
		Source.PAD:
			return Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	return remote_fire


func bomb_held() -> bool:
	match source:
		Source.ANY:
			return Input.is_action_pressed("bomb")
		Source.KEYBOARD:
			return Input.is_physical_key_pressed(KEY_B) or Input.is_physical_key_pressed(KEY_SHIFT)
		Source.PAD:
			return Input.is_joy_button_pressed(device, JOY_BUTTON_B) or Input.is_joy_button_pressed(device, JOY_BUTTON_X)
	return false


## True once per bomb press.
func bomb_pressed() -> bool:
	if source == Source.REMOTE or source == Source.BOT:
		if remote_bombs != _seen_bombs:
			_seen_bombs = remote_bombs
			return true
		return false
	var held := bomb_held()
	var pressed := held and not _bomb_was
	_bomb_was = held
	return pressed


func _key_axis() -> float:
	var v := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		v -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		v += 1.0
	return v


static func _pad_axis(dev: int) -> float:
	var v := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT):
		v = -1.0
	elif Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT):
		v = 1.0
	return v
