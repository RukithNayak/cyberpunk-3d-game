extends RefCounted
class_name SaveMigrations
## Pure, ordered save-schema transformations. Does not access files or live owners.

const CURRENT_VERSION: int = 1


func migrate_snapshot(source_version: int, source_snapshot: Dictionary) -> Dictionary:
	if source_version > CURRENT_VERSION:
		return {"ok": false, "error": ERR_UNAVAILABLE}
	if source_version < 0 or source_version > CURRENT_VERSION:
		return {"ok": false, "error": ERR_FILE_UNRECOGNIZED}
	var snapshot: Dictionary = source_snapshot.duplicate(true)
	var version: int = source_version
	while version < CURRENT_VERSION:
		var migration: Callable = _migration_for(version)
		if not migration.is_valid():
			return {"ok": false, "error": ERR_FILE_UNRECOGNIZED}
		var result: Variant = migration.call(snapshot)
		if typeof(result) != TYPE_DICTIONARY or not result.get("ok", false) or typeof(result.get("snapshot")) != TYPE_DICTIONARY:
			return {"ok": false, "error": ERR_INVALID_DATA}
		snapshot = result["snapshot"].duplicate(true)
		version += 1
	return {"ok": true, "error": OK, "version": version, "snapshot": snapshot}


func _migration_for(source_version: int) -> Callable:
	match source_version:
		0:
			return Callable(self, "_migrate_v0_to_v1")
		_:
			return Callable()


func _migrate_v0_to_v1(source: Dictionary) -> Dictionary:
	if not source.has("player") or typeof(source["player"]) != TYPE_DICTIONARY:
		return {"ok": false}
	if not source.has("entities") or typeof(source["entities"]) != TYPE_ARRAY:
		return {"ok": false}
	if not source.has("factions") or typeof(source["factions"]) != TYPE_DICTIONARY:
		return {"ok": false}
	if source.has("domains") or not source.has("domain_records") or typeof(source["domain_records"]) != TYPE_DICTIONARY:
		return {"ok": false}
	var migrated: Dictionary = source.duplicate(true)
	migrated["domains"] = migrated["domain_records"].duplicate(true)
	migrated.erase("domain_records")
	return {"ok": true, "snapshot": migrated}
