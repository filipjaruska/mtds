extends Node
## In-match chat (autoload "ChatManager"). Messages go to the host, which cleans
## and rate-limits them (ChatRules) and hands them to every peer. The UI
## (ChatBubble above players, TopBarUI) listens to `message_received`.
##
## While the local player is typing, `is_typing` is true and InputManager
## mutes gameplay input.

## Every peer, for every delivered message (the sender's peer id and the cleaned text).
signal message_received(peer_id: int, text: String)

var is_typing := false

var _recent := {} # host: peer id -> msec of their recent messages

func set_typing(typing: bool) -> void:
	is_typing = typing

## Local player: send a message to everyone.
func send(text: String) -> void:
	var clean := ChatRules.sanitize(text)
	if clean.is_empty() or not multiplayer.has_multiplayer_peer():
		return
	_request_send.rpc_id(1, clean)

## Sender -> host. The sender id comes from the transport, so nobody can speak
## for someone else.
@rpc("any_peer", "call_local", "reliable")
func _request_send(text: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var clean := ChatRules.sanitize(text)
	if clean.is_empty() or not GameManager.players.has(sender):
		return
	var check := ChatRules.rate_ok(_recent.get(sender, []), Time.get_ticks_msec())
	_recent[sender] = check.recent
	if check.allowed:
		_deliver.rpc(sender, clean)

@rpc("authority", "call_local", "reliable")
func _deliver(sender: int, text: String) -> void:
	message_received.emit(sender, text)
