/// action_ai_toggle_enabled(value)
/// @arg value
/// @desc Toggles the AI Assistant on/off for this project.

function action_ai_toggle_enabled(value)
{
	project_ai_enabled = value
	if (value)
	{
		// Low-RAM warning (recommended spec is 8 GB or more)
		var ram = system_total_ram_mb()
		if (ram > 0 && ram < 8192)
			toast_new(e_toast.WARNING, text_get("ai_warning_ram8gb", string(ram)))
		
		// Cloud endpoints require an API key
		var ep = string_lower(project_ai_endpoint)
		if (string_length(project_ai_api_key) < 1 && (string_pos("generativelanguage", ep) > 0 || string_pos("anthropic", ep) > 0 || string_pos("api.openai.com", ep) > 0))
			toast_new(e_toast.WARNING, text_get("ai_warning_apikey"))
	}
	project_changed = true
}
