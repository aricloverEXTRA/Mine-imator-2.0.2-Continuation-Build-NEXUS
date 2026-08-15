/// ai_find_part(tl, partname)
/// @arg tl
/// @arg partname
/// @desc Finds a body part by name within the given object's hierarchy.

function ai_find_part(tl, partname)
{
	if (tl == null || !is_string(partname))
		return null
	var upper = string_upper(string_trim(partname))
	if (upper == "")
		return null
	return ai_find_part_recursive(tl, upper)
}

function ai_find_part_recursive(tl, upper)
{
	with (obj_timeline)
	{
		if (part_of != tl)
			continue
		if (string_upper(string_trim(display_name)) = upper)
			return id
		var r = ai_find_part_recursive(id, upper)
		if (r != null)
			return r
	}
	return null
}
