# csv_fetcher.gd
# Purpose: Download CSV from Google Sheets and emit result
# Inputs: name (String), url (String), headers (Array), output paths
# Outputs: Signal 'csv_fetched' (result: int, response_code: int, headers: Array, body: PackedByteArray, csv_path: String)
#
# Interface:
#   - fetch_csv(name: String, url: String, headers: Array, csv_path: String) -> void
#   - Signal: csv_fetched(result, response_code, headers, body, csv_path)
#
# Usage Example:
#   var fetcher = csv_fetcher.new()
#   fetcher.connect("csv_fetched", self, "_on_csv_fetched")
#   fetcher.fetch_csv("Test", "http://...", ["User-Agent: ..."], "res://.../file.csv")
#
# Test Template:
#   fetcher.fetch_csv(...)
#   # Wait for signal, assert file exists

extends Node

signal csv_fetched(result, response_code, headers, body, csv_path)

func fetch_csv(name: String, url: String, headers: Array, csv_path: String) -> void:
	if url.strip_edges() == "" or not url.begins_with("http"):
		emit_signal("csv_fetched", HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray(), csv_path)
		return
	var req = HTTPRequest.new()
	add_child(req)
	req.connect("request_completed", Callable(self, "_on_request_completed").bind(req, csv_path))
	var err = req.request(url, headers)
	if err != OK:
		emit_signal("csv_fetched", err, 0, [], PackedByteArray(), csv_path)
		req.queue_free()
		return

func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray, req: HTTPRequest, csv_path: String) -> void:
	if response_code >= 300 and response_code < 400:
		# Find the Location header
		for h in headers:
			var parts = h.split(":", false, 1)
			if parts.size() == 2 and parts[0].strip_edges().to_lower() == "location":
				var new_url = parts[1].strip_edges()
				req.request(new_url, []) # or pass headers if needed
				return
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var f = FileAccess.open(csv_path, FileAccess.WRITE)
		if f:
			f.store_string(body.get_string_from_utf8())
			f.close()
	emit_signal("csv_fetched", result, response_code, headers, body, csv_path)
	req.queue_free()