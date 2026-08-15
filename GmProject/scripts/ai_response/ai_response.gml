/// ai_response()
/// @desc Handles the HTTP reply from the AI companion. Runs in app scope.

function ai_response()
{
	app.ai_busy = false
	
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
	
	// Error response from companion
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
	
	// Success: extract everything BEFORE destroying the response tree
	var message = rootmap[?"message"]
	var plan = rootmap[?"plan"]
	var usage = rootmap[?"usage"]
	var warnings = rootmap[?"warnings"]
	
	app.ai_reply = is_string(message) ? message : ""
	app.ai_usage = ai_usage_string(usage)
	app.ai_warnings = ai_warnings_string(warnings)
	
	// No actions -> pure chat reply
	if (!ds_list_valid(plan) || ds_list_size(plan) = 0)
	{
		app.ai_status = text_get("ai_status_ok")
		toast_new(e_toast.INFO, app.ai_status)
		ai_memory_record()
		ds_map_destroy(rootmap)
		return 0
	}
	
	var err = ai_apply_plan(plan)
	// The history slot already holds its own JSON string copy; free the response
	// tree (recursive, leak-free) including the plan/usage/warnings.
	ds_map_destroy(rootmap)
	
	if (err = "")
	{
		app.ai_status = text_get("ai_status_applied", app.ai_applied)
		toast_new(e_toast.POSITIVE, app.ai_status)
		ai_memory_record()
	}
	else
	{
		app.ai_error = text_get(err)
		app.ai_status = app.ai_error
		toast_new(e_toast.NEGATIVE, app.ai_error)
	}
}

/// ai_memory_record()
/// @desc Records the last successful exchange (user prompt + assistant reply)
///       into the per-project session memory. Runs in app scope.

function ai_memory_record()
{
	if (string_length(app.ai_pending_prompt) > 0)
		ai_memory_add("user", app.ai_pending_prompt)
	app.ai_pending_prompt = ""
	if (string_length(app.ai_reply) > 0)
		ai_memory_add("assistant", app.ai_reply)
	return 0
}

/// ai_memory_add(role, text)
/// @arg role
/// @arg text
/// @desc Appends a [role, text] pair to the session memory, keeping at most
///       60 entries (drops the oldest). In-memory only; never touches files.

function ai_memory_add(role, text)
{
	app.ai_memory = array_add(app.ai_memory, [role, text], false)
	var cap = 60
	var len = array_length(app.ai_memory)
	if (len > cap)
	{
		var tmp = []
		for (var i = len - cap; i < len; i++)
			tmp = array_add(tmp, app.ai_memory[i], false)
		app.ai_memory = tmp
	}
	return 0
}

/// ai_show_error(key)
/// @arg key
/// @desc Shows an error from a text key.

function ai_show_error(key)
{
	app.ai_error = text_get(key)
	app.ai_status = app.ai_error
	toast_new(e_toast.NEGATIVE, app.ai_error)
}

/// ai_map_error(code)
/// @arg code
/// @desc Maps a companion error code to a text key.

function ai_map_error(code)
{
	switch (code)
	{
		case "connection_refused": return "ai_error_connection"
		case "model_not_found": return "ai_error_model"
		case "quota_exceeded": return "ai_error_quota"
		case "rate_limited": return "ai_error_rate"
		case "token_limit": return "ai_error_tokens"
		case "timeout": return "ai_error_timeout"
		case "invalid_request": return "ai_error_invalid"
		case "malformed_llm_response": return "ai_error_json"
	}
	return "ai_error_unknown"
}

/// ai_usage_string(usage)
/// @arg usage
/// @desc Formats a usage map into a short string.

function ai_usage_string(usage)
{
	if (!ds_map_valid(usage))
		return ""
	var s = ""
	var first = true
	var pt = usage[?"prompt_tokens"]
	var ct = usage[?"completion_tokens"]
	var tt = usage[?"total_tokens"]
	if (is_real(pt))
	{
		if (!first)
			s += " "
		first = false
		s += "in:" + string(pt)
	}
	if (is_real(ct))
	{
		if (!first)
			s += " "
		first = false
		s += "out:" + string(ct)
	}
	if (is_real(tt))
	{
		if (!first)
			s += " "
		first = false
		s += "total:" + string(tt)
	}
	return s
}

/// ai_warnings_string(warnings)
/// @arg warnings
/// @desc Joins a warnings ds_list into a single string.

function ai_warnings_string(warnings)
{
	if (!ds_list_valid(warnings))
		return ""
	var s = ""
	for (var i = 0; i < ds_list_size(warnings); i++)
	{
		var w = warnings[|i]
		if (is_string(w))
		{
			if (s != "")
				s += "\n"
			s += w
		}
	}
	return s
}
