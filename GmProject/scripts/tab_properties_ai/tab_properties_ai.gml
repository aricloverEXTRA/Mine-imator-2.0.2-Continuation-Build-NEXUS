/// tab_properties_ai()
/// @desc Draws the AI Assistant panel in the Projects tab.

function tab_properties_ai()
{
	// Assistant enabled (per project)
	tab_control_switch()
	draw_switch("aienabled", dx, dy, project_ai_enabled, action_ai_toggle_enabled, "aienabledtip")
	tab_next()
	
	// Context gathering (project understanding only, never telemetry)
	tab_control_switch()
	draw_switch("aicontext", dx, dy, project_ai_context_enabled, action_ai_toggle_context, "aicontexttip")
	tab_next()
	
	// Status
	tab_control(36)
	draw_label_value(dx, dy, dw, 36, text_get("aistatus"), app.ai_status, true)
	tab_next()
	
	// Session memory (per project, in-memory only) + compact/clear
	tab_control(36)
	var memtext = ""
	if (app.ai_memory_compacting)
		memtext = text_get("ai_status_compacting")
	else if (app.ai_memory_summary != "")
		memtext = text_get("aimemorycompacted", array_length(app.ai_memory))
	else
		memtext = text_get("aimemorycount", array_length(app.ai_memory))
	draw_label_value(dx, dy, dw - 60, 36, text_get("aimemory"), memtext, false)
	var memdisabled = app.ai_busy || app.ai_memory_compacting || array_length(app.ai_memory) = 0
	if (draw_button_icon("aicompact", dx + dw - 56, dy + 6, 24, 24, false, icons.COMPACT, null, memdisabled, "aimemorycompacttip"))
		action_ai_compact_memory()
	if (draw_button_icon("aiclear", dx + dw - 28, dy + 6, 24, 24, false, icons.DELETE, null, memdisabled, "aimemorycleartip"))
		action_ai_clear_memory()
	tab_next()
	
	// Model
	tab.ai.tbx_model.text = project_ai_model
	tab_control_textfield()
	if (draw_textfield("aimodel", dx, dy, dw, 24, tab.ai.tbx_model, null, "", "top"))
	{
		project_changed = true
		project_ai_model = tab.ai.tbx_model.text
	}
	tab_next()
	
	// Endpoint
	tab.ai.tbx_endpoint.text = project_ai_endpoint
	tab_control_textfield()
	if (draw_textfield("aiendpoint", dx, dy, dw, 24, tab.ai.tbx_endpoint, null, "", "top"))
	{
		project_changed = true
		project_ai_endpoint = tab.ai.tbx_endpoint.text
	}
	tab_next()
	
	// Provider
	tab.ai.tbx_provider.text = project_ai_provider
	tab_control_textfield()
	if (draw_textfield("aiprovider", dx, dy, dw, 24, tab.ai.tbx_provider, null, "", "top"))
	{
		project_changed = true
		project_ai_provider = string_lower(tab.ai.tbx_provider.text)
	}
	tab_next()
	
	// API key (optional, for cloud providers)
	tab.ai.tbx_api_key.text = project_ai_api_key
	tab_control_textfield()
	if (draw_textfield("aiapikey", dx, dy, dw, 24, tab.ai.tbx_api_key, null, "", "top"))
	{
		project_changed = true
		project_ai_api_key = tab.ai.tbx_api_key.text
	}
	tab_next()
	
	// Temperature
	tab.ai.tbx_temperature.text = string(project_ai_temperature)
	tab_control_textfield()
	if (draw_textfield("aitemperature", dx, dy, dw, 24, tab.ai.tbx_temperature, null, "", "top"))
	{
		project_changed = true
		project_ai_temperature = clamp(string_get_real(tab.ai.tbx_temperature.text, project_ai_temperature), 0, 1)
	}
	tab_next()
	
	// Max tokens
	tab.ai.tbx_max_tokens.text = string(project_ai_max_tokens)
	tab_control_textfield()
	if (draw_textfield("aimaxtokens", dx, dy, dw, 24, tab.ai.tbx_max_tokens, null, "", "top"))
	{
		project_changed = true
		project_ai_max_tokens = max(1, round(string_get_real(tab.ai.tbx_max_tokens.text, project_ai_max_tokens)))
	}
	tab_next()
	
	// MCP servers (one "name|url" per line)
	tab.ai.tbx_mcp.text = project_ai_mcp_text
	tab_control_textfield(true, 56)
	if (draw_textfield("aimcp", dx, dy, dw, 56, tab.ai.tbx_mcp, null, "", "top"))
	{
		project_changed = true
		project_ai_mcp_text = tab.ai.tbx_mcp.text
	}
	tab_next()
	
	// Errors / warnings
	if (app.ai_error != "" || app.ai_warnings != "")
	{
		tab_control(44)
		var info = ""
		if (app.ai_error != "")
			info = "! " + app.ai_error
		if (app.ai_warnings != "")
		{
			if (info != "")
				info += "\n"
			info += app.ai_warnings
		}
		draw_box(dx, dy, dw, 44, false, c_level_bottom, 1)
		draw_set_font(font_value)
		draw_label(string_limit(info, dw), dx + 8, dy + 8, fa_left, fa_top, c_error, 1)
		tab_next()
	}
	
	// Assistant reply
	if (app.ai_reply != "")
	{
		tab_control(64)
		draw_box(dx, dy, dw, 64, false, c_level_bottom, 1)
		draw_set_font(font_value)
		draw_label(string_limit(app.ai_reply, dw), dx + 8, dy + 8, fa_left, fa_top, c_text_main, a_text_main)
		tab_next()
	}
	
	// Prompt + send
	tab_control_textfield(true, 76)
	draw_textfield("aiprompt", dx, dy, dw - 32, 76, tab.ai.tbx_prompt, null, text_get("aipromptplaceholder"), "top")
	if (draw_button_icon("aisend", dx + dw - 28, dy + 50, 24, 24, false, icons.PLAY, null, app.ai_busy || !project_ai_enabled, "aisendtip"))
		action_ai_send()
	tab_next()
}
