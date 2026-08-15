/// action_ai_compact_memory()
/// @desc Sends the session transcript to the companion's /api/compact and
///       stores the returned summary as the new session memory.

function action_ai_compact_memory()
{
	if (app.ai_busy || app.ai_memory_compacting)
	{
		toast_new(e_toast.NEGATIVE, text_get("ai_error_busy_compact"))
		return 0
	}
	if (array_length(app.ai_memory) = 0)
	{
		toast_new(e_toast.NEGATIVE, text_get("ai_error_empty_memory"))
		return 0
	}
	
	var body = ai_build_compact_body(project_ai_model, project_ai_endpoint, project_ai_temperature, project_ai_max_tokens, project_ai_provider, project_ai_api_key, app.ai_memory, app.ai_memory_summary)
	var url = "http://127.0.0.1:" + string(setting_ai_companion_port) + "/api/compact"
	app.ai_compact_id = http_post(url, body)
	app.ai_memory_compacting = true
	app.ai_busy = true
	app.ai_status = text_get("ai_status_compacting")
	return 0
}
