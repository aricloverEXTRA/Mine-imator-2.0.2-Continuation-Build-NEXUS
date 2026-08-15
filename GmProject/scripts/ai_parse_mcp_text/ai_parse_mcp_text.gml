/// ai_parse_mcp_text(text)
/// @arg text
/// @desc Parses the MCP server textarea into an array of [name, url] pairs.
///       Each line should be "name=url" or "name|url". Blank lines are ignored.

function ai_parse_mcp_text(text)
{
	var result = []
	var count = 0
	if (!is_string(text))
		return result
	
	var lines = string_split(text, "\n")
	for (var i = 0; i < array_length(lines); i++)
	{
		var line = string_trim(lines[i])
		if (line == "")
			continue
		var eq = string_pos("=", line)
		var pipe = string_pos("|", line)
		var sep = 0
		if (eq > 0 && (pipe == 0 || eq < pipe))
			sep = eq
		else if (pipe > 0)
			sep = pipe
		if (sep > 0)
		{
			var name = string_trim(string_copy(line, 1, sep - 1))
			var url = string_trim(string_copy(line, sep + 1, string_length(line) - sep))
			if (name != "" && url != "")
			{
				result[count] = [name, url]
				count++
			}
		}
	}
	return result
}
