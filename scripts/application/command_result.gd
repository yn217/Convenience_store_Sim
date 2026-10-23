class_name CommandResult
extends RefCounted
## 01_ENGINE_CONTRACT §4 / 08 §2. A failure never changes the revision.

var ok: bool = false
var code: StringName = &"INVALID_OPERATION"
var message_key: StringName = &""
var event_ids: Array[String] = []
var new_revision: int = 0
## Command-specific outputs, e.g. {instance_id} for PLACE_FIXTURE.
var data: Dictionary = {}


static func success(revision: int, events: Array[String], message: StringName = &"", out_data: Dictionary = {}) -> CommandResult:
	var r := CommandResult.new()
	r.data = out_data
	r.ok = true
	r.code = &"OK"
	r.message_key = message
	r.event_ids = events
	r.new_revision = revision
	return r


static func failure(fail_code: StringName, revision: int, message: StringName = &"") -> CommandResult:
	var r := CommandResult.new()
	r.ok = false
	r.code = fail_code
	r.message_key = message
	r.new_revision = revision
	return r
