/// ai_compact_response()
/// @desc Handles the HTTP reply from the companion's /api/compact. On success,
///       replaces the session memory with the compacted summary.

function ai_compact_response()
{
	app.ai_busy = false
	app.ai_memory_compacting = false
	
	if (async_load[?"status"] = -1)
	{
		ai_show_error("ai_error_connection")
		return 0
	}
	
	var rootmap = json_decode(async_load[?"result"])
	if (!ds_map_valid(rootmap))
	{
		ai_show_error("ai_error_json")
		return 0
	}
	
	if (rootmap[?"status"] = "error")
	{
		var errmap = rootmap[?"error"]
		var code = ds_map_valid(errmap) ? errmap[?"code"] : "internal_error"
		var msg = ds_map_valid(errmap) ? errmap[?"message"] : ""
		app.ai_error_detail = is_string(msg) ? msg : ""
		ds_map_destroy(rootmap)
		ai_show_error(ai_map_error(code))
		return 0
	}
	
	var summary = rootmap[?"summary"]
	var usage = rootmap[?"usage"]
	var warnings = rootmap[?"warnings"]
	
	app.ai_usage = ai_usage_string(usage)
	app.ai_warnings = ai_warnings_string(warnings)
	
	if (is_string(summary) && string_length(summary) > 0)
	{
		app.ai_memory_summary = summary
		app.ai_memory = []
		app.ai_status = text_get("ai_status_ok")
		toast_new(e_toast.POSITIVE, text_get("ai_memorycompacted_done"))
	}
	else
	{
		ai_show_error("ai_error_json")
	}
	
	ds_map_destroy(rootmap)
	return 0
}
