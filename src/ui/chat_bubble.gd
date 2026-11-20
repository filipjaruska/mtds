extends Node2D
class_name ChatBubble
## Speech bubble above a player: shows that player's chat messages with a
## typewriter reveal (ChatBubbleView). Sits in the world above the name and
## health bar; hidden while the player is dead.

@onready var player: Node2D = get_parent()

var _view: ChatBubbleView

func _ready() -> void:
	z_index = 20
	_view = ChatBubbleView.new(13, 180.0, ChatBubbleView.Align.CENTER, true)
	add_child(_view)
	ChatManager.message_received.connect(_on_message)

func _exit_tree() -> void:
	if ChatManager.message_received.is_connected(_on_message):
		ChatManager.message_received.disconnect(_on_message)

func _on_message(peer_id: int, text: String) -> void:
	if peer_id == player.get_multiplayer_authority():
		_view.push(text)

func _process(_delta: float) -> void:
	var health = player.get_node_or_null("HealthComponent")
	visible = not (health and health.is_dead)

## For tests and the UI.
func is_showing() -> bool:
	return _view.is_showing()
