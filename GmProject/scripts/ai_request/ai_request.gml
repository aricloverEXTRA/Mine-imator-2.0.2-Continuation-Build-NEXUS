/// ai_request(prompt)
/// @arg prompt
/// @desc Sends a prompt to the AI companion asynchronously via http_post.
///       Context is gathered ONLY here (on demand), never in the frame loop.

function ai_request(prompt)
{
	app.ai_busy = true
	app.ai_status = text_get("ai_status_thinking")
	app.ai_error = ""
	app.ai_warnings = ""
	app.ai_reply = ""
	app.ai_usage = ""
	app.ai_applied = 0
	app.ai_pending_prompt = prompt
	
	var mcp = ai_parse_mcp_text(project_ai_mcp_text)
	var context = "null"
	if (project_ai_context_enabled)
		context = ai_gather_context()
	
	var body = ai_build_body(prompt, context, project_ai_model, project_ai_endpoint, project_ai_temperature, project_ai_max_tokens, project_ai_provider, project_ai_api_key, mcp, app.ai_memory, app.ai_memory_summary)
	var url = "http://127.0.0.1:" + string(setting_ai_companion_port) + "/api/chat"
	app.ai_http_id = http_post(url, body)
	return app.ai_http_id
}
