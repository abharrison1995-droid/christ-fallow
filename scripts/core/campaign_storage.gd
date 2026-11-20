extends RefCounted

const CampaignSave = preload("res://scripts/core/campaign_save.gd")


static func write_snapshot(path: String, snapshot: Dictionary) -> bool:
	var staging_path := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(staging_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(staging_path, path) != OK:
		DirAccess.remove_absolute(staging_path)
		return false
	return true


static func read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "No saved campaign found.", "missing": true}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "Could not read the campaign save."}
	var json := JSON.new()
	var parse_error := json.parse(f.get_as_text())
	f.close()
	var parsed := CampaignSave.unpack(json.data) if parse_error == OK else {}
	if parsed.is_empty():
		return {"error": "The campaign save is incomplete, invalid, or from an unsupported version."}
	return {"data": parsed, "modified": FileAccess.get_modified_time(path)}
