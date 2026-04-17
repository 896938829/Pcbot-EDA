class_name DiagnosticsLogTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("record dedupe + resolve", func():
		var root := "user://diag_test"
		DirAccess.make_dir_recursive_absolute(root + "/.pcbot")
		var p := DiagnosticsLog.path(root)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		var a1 := DiagnosticsLog.record_violation(root, "net.floating", "error", "N1", "空")
		var a2 := DiagnosticsLog.record_violation(root, "net.floating", "error", "N1", "空")
		if not a1:
			return "first record should succeed"
		if a2:
			return "second record should be deduped"
		var unresolved := DiagnosticsLog.list_unresolved(root)
		if unresolved.size() != 1:
			return "unresolved count wrong: %d" % unresolved.size()
		DiagnosticsLog.mark_resolved(root, "net.floating", "N1", "abc123")
		var u2 := DiagnosticsLog.list_unresolved(root)
		if u2.size() != 0:
			return "should have 0 unresolved after mark_resolved"
		return ""))
	return r
