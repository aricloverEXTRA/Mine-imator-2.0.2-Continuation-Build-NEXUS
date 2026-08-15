/// ai_build_body(prompt, context, model, endpoint, temperature, max_tokens, provider, api_key, mcp, history, memory)
/// @arg prompt
/// @arg context
/// @arg model
/// @arg endpoint
/// @arg temperature
/// @arg max_tokens
/// @arg provider
/// @arg api_key
/// @arg mcp
/// @arg history
/// @arg memory
/// @desc Builds the JSON request body for the AI companion. history is a list
///       of [role, content] pairs (most recent last); memory is a compacted
///       session summary string (may be empty).

function ai_build_body(prompt, context, model, endpoint, temperature, max_tokens, provider, api_key, mcp, history, memory)
{
	var s = "{"
	s += "\"prompt\":" + ai_json_string(prompt)
	s += ",\"context\":" + context
	s += ",\"model\":" + ai_json_string(model)
	s += ",\"endpoint\":" + ai_json_string(endpoint)
	s += ",\"provider\":" + ai_json_string(provider)
	s += ",\"api_key\":" + ai_json_string(api_key)
	s += ",\"temperature\":" + string(temperature)
	s += ",\"max_tokens\":" + string(max_tokens)
	s += ",\"memory\":" + ai_json_string(memory)
	s += ",\"history\":["
	for (var i = 0; i < array_length(history); i++)
	{
		if (i > 0)
			s += ","
		s += "{\"role\":" + ai_json_string(history[i][0]) + ",\"content\":" + ai_json_string(history[i][1]) + "}"
	}
	s += "]"
	s += ",\"mcp\":["
	for (var i = 0; i < array_length(mcp); i++)
	{
		if (i > 0)
			s += ","
		s += "{\"name\":" + ai_json_string(mcp[i][0]) + ",\"url\":" + ai_json_string(mcp[i][1]) + "}"
	}
	s += "]"
	s += "}"
	return s
}

/// ai_build_compact_body(model, endpoint, temperature, max_tokens, provider, api_key, history, memory)
/// @arg model
/// @arg endpoint
/// @arg temperature
/// @arg max_tokens
/// @arg provider
/// @arg api_key
/// @arg history
/// @arg memory
/// @desc Builds the JSON request body for the AI companion's /api/compact.

function ai_build_compact_body(model, endpoint, temperature, max_tokens, provider, api_key, history, memory)
{
	var s = "{"
	s += "\"model\":" + ai_json_string(model)
	s += ",\"endpoint\":" + ai_json_string(endpoint)
	s += ",\"provider\":" + ai_json_string(provider)
	s += ",\"api_key\":" + ai_json_string(api_key)
	s += ",\"temperature\":" + string(temperature)
	s += ",\"max_tokens\":" + string(max_tokens)
	s += ",\"memory\":" + ai_json_string(memory)
	s += ",\"history\":["
	for (var i = 0; i < array_length(history); i++)
	{
		if (i > 0)
			s += ","
		s += "{\"role\":" + ai_json_string(history[i][0]) + ",\"content\":" + ai_json_string(history[i][1]) + "}"
	}
	s += "]"
	s += "}"
	return s
}
