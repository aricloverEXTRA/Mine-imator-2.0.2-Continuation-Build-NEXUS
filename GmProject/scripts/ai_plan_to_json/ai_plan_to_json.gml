/// ai_plan_to_json(plan)
/// @arg plan
/// @desc Serializes an action plan (ds_list of ds_maps) into a JSON string so it
///       can be stored in a history slot as a GC'd string (leak-free) and later
///       re-decoded for redo. json_decode CANNOT decode a top-level array, so the
///       plan is wrapped as {"plan":[...]}.

function ai_plan_to_json(plan)
{
	var s = "{\"plan\":["
	for (var i = 0; i < ds_list_size(plan); i++)
	{
		if (i > 0)
			s += ","
		var act = plan[|i]
		s += "{\"type\":" + ai_json_string(act[?"type"])
		var obj = act[?"object"]
		if (is_string(obj))
			s += ",\"object\":" + ai_json_string(obj)
		var part = act[?"part"]
		if (is_string(part))
			s += ",\"part\":" + ai_json_string(part)
		var frame = act[?"frame"]
		if (is_real(frame))
			s += ",\"frame\":" + string(round(frame))
		var values = act[?"values"]
		if (ds_map_valid(values))
		{
			s += ",\"values\":{"
			var first = true
			var key = ds_map_find_first(values)
			while (!is_undefined(key))
			{
				if (!first)
					s += ","
				first = false
				s += ai_json_string(key) + ":" + string(values[?key])
				key = ds_map_find_next(values, key)
			}
			s += "}"
		}
		s += "}"
	}
	s += "]}"
	return s
}
