class_name LevelData
extends Resource
## One planet / level. Edit these in the Godot inspector (data/levels/*.tres) to tune the game.

@export var planet := ""
@export var tagline := ""
@export_multiline var fact := ""
## Alien rows, top row first. Kinds: drone, crab, squid, beetle, wraith, cruiser.
@export var rows: PackedStringArray = []
@export var cols := 9
## Base formation speed in pixels per second.
@export var speed := 46.0
## Enemy shots per second for the whole formation.
@export var fire_rate := 0.45
@export var bullet_speed := 360.0
## Chance per second that one alien breaks formation and dives at the player.
@export var dive_chance := 0.0
## Seconds between bonus saucers (roughly).
@export var saucer_every := 26.0
## Index used to pick the tinted alien sprites (assets/sprites/aliens/<kind>_<index>_<frame>.png).
@export var alien_tint := 0
## Colour tint shift (degrees) used for shots and effects.
@export var hue_shift := 0.0
@export var bunker_dust := Color.GRAY
@export var background: Texture2D
@export var bunker_texture: Texture2D
@export var music: AudioStream
## Pluto: spawns the boss after the fleet is destroyed.
@export var boss := false
