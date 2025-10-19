extends Node2D
class_name PowerupPickup

@export var powerup_card: BasePowerupCard
@onready var label = $Label
@onready var sprite = $Sprite2D
@onready var glow_effect = $GlowEffect
@onready var area = $Area2D

var player: Node = null
var pickup_available: bool = true

func _ready() -> void:
	if not area:
		area = get_node_or_null("Area2D")
	
	if area and not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if area and not area.body_exited.is_connected(_on_body_exited):
		area.body_exited.connect(_on_body_exited)
	
	if label:
		label.visible = false
	if sprite:
		sprite.visible = true
	
	if powerup_card:
		setup_visual_appearance()
	if glow_effect:
		_setup_glow_animation()

func setup_visual_appearance():
	if not powerup_card:
		return
	
	if sprite:
		if powerup_card.icon_texture:
			sprite.texture = powerup_card.icon_texture
		else:
			var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
			image.fill(powerup_card.rarity_color)
			var texture = ImageTexture.create_from_image(image)
			sprite.texture = texture
		sprite.modulate = Color.WHITE
		sprite.centered = true
	
	if glow_effect and powerup_card:
		if powerup_card.icon_texture:
			glow_effect.texture = powerup_card.icon_texture
		else:
			var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
			image.fill(powerup_card.rarity_color)
			var texture = ImageTexture.create_from_image(image)
			glow_effect.texture = texture
		glow_effect.modulate = Color(powerup_card.rarity_color, 0.5)
		glow_effect.scale = Vector2(1.2, 1.2)
		glow_effect.centered = true
	
	if label:
		label.text = "Press E to collect " + powerup_card.get_display_name()

func _setup_glow_animation():
	if not glow_effect:
		return
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow_effect, "modulate:a", 0.3, 1.0)
	tween.tween_property(glow_effect, "modulate:a", 0.8, 1.0)

func _process(_delta):
	if player and pickup_available and InputManager.is_interact_pressed():
		_attempt_pickup()

func _attempt_pickup():
	if not powerup_card or not player:
		return
	
	if not player.is_multiplayer_authority():
		return
	
	var powerup_manager = player.get_node("PowerupManager")
	if not powerup_manager:
		push_warning("Player doesn't have a PowerupManager component")
		return
	
	var slot_index = powerup_manager.find_empty_slot()
	if slot_index == -1:
		_show_inventory_full_feedback()
		return
	
	_request_pickup.rpc_id(1, player.get_multiplayer_authority(), powerup_card.type, slot_index)

@rpc("any_peer", "call_local", "reliable")
func _request_pickup(player_id: int, card_type: int, slot_index: int):
	if multiplayer.is_server():
		rpc_id(player_id, "_collect_powerup_confirmed", card_type, slot_index)
		delete_pickup.rpc()

@rpc("authority", "call_local", "reliable")
func _collect_powerup_confirmed(card_type: int, slot_index: int):
	if player and player.is_multiplayer_authority():
		var powerup_manager = player.get_node("PowerupManager")
		if powerup_manager:
			powerup_manager.add_powerup_to_slot(card_type, slot_index)

@rpc("authority", "call_local", "reliable")
func delete_pickup():
	queue_free()

func _show_inventory_full_feedback():
	if not label:
		return
	
	label.text = "Inventory Full!"
	label.modulate = Color.RED
	
	var tween = create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 1.0)
	tween.tween_callback(func():
		if label and powerup_card:
			label.text = "Press E to collect " + powerup_card.get_display_name()
	)

func _on_body_entered(body):
	if not body.is_in_group("Player") or not pickup_available:
		return
	
	player = body
	if label:
		label.visible = true
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)

func _on_body_exited(body):
	if not body.is_in_group("Player"):
		return
	
	player = null
	if label:
		label.visible = false
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

func set_powerup_card(card: BasePowerupCard) -> void:
	powerup_card = card
	setup_visual_appearance()

static func create_pickup(card: BasePowerupCard, spawn_position: Vector2) -> PowerupPickup:
	var pickup = PowerupPickup.new()
	pickup.position = spawn_position
	pickup.powerup_card = card
	pickup.z_index = 0
	pickup.z_as_relative = false
	
	var pickup_area = Area2D.new()
	pickup_area.name = "Area2D"
	pickup.add_child(pickup_area)
	
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 30.0
	collision.shape = circle
	collision.debug_color = Color(1, 0, 0, 0.3)
	pickup_area.add_child(collision)
	
	pickup_area.body_entered.connect(pickup._on_body_entered)
	pickup_area.body_exited.connect(pickup._on_body_exited)
	
	var pickup_label = Label.new()
	pickup_label.name = "Label"
	pickup_label.visible = false
	pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_label.position = Vector2(-50, -40)
	pickup.add_child(pickup_label)
	
	var pickup_sprite = Sprite2D.new()
	pickup_sprite.name = "Sprite2D"
	pickup_sprite.visible = true
	pickup_sprite.centered = true
	pickup.add_child(pickup_sprite)
	
	var glow_sprite = Sprite2D.new()
	glow_sprite.name = "GlowEffect"
	glow_sprite.centered = true
	glow_sprite.scale = Vector2(1.2, 1.2)
	glow_sprite.modulate = Color(card.rarity_color, 0.5)
	glow_sprite.z_index = -1
	pickup.add_child(glow_sprite)
	
	pickup.label = pickup_label
	pickup.sprite = pickup_sprite
	pickup.glow_effect = glow_sprite
	
	if card.icon_texture:
		pickup_sprite.texture = card.icon_texture
		glow_sprite.texture = card.icon_texture
	else:
		var placeholder = PlaceholderTexture2D.new()
		placeholder.size = Vector2(64, 64)
		pickup_sprite.texture = placeholder
		pickup_sprite.self_modulate = card.rarity_color
		glow_sprite.texture = placeholder
		glow_sprite.self_modulate = card.rarity_color
	
	pickup_label.text = "Press E to collect " + card.get_display_name()
	pickup.pickup_available = true
	
	return pickup
