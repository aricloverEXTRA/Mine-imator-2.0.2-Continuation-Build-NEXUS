/// ai_find_tl(name)
/// @arg name
/// @desc Finds a timeline by display name (case-insensitive).

function ai_find_tl(name)
{
	if (!is_string(name))
		return null
	var upper = string_upper(string_trim(name))
	if (upper == "")
		return null
	
	with (obj_timeline)
	{
		if (temp != null)
			continue
		if (string_upper(string_trim(display_name)) = upper)
			return id
		if (string_upper(string_trim(name)) = upper)
			return id
	}
	return null
}
