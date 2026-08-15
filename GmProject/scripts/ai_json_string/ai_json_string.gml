/// ai_json_string(str)
/// @arg str
/// @desc Escapes a string for embedding in a JSON request body and wraps it in quotes.

function ai_json_string(str)
{
	if (!is_string(str))
		str = ""
	return "\"" + json_string_encode(str) + "\""
}
