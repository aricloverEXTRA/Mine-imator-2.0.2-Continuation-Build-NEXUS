/// ai_validate_plan(plan)
/// @arg plan
/// @desc Validates an entire action plan BEFORE any changes are applied.
///       Returns "" if valid, or an error text key. Also fills
///       app.ai_affected_tls with the timelines that will change.

function ai_validate_plan(plan)
{
	// Reset affected-timeline tracking
	app.ai_affected_tls = []
	app.ai_any_render = false
	var count = 0
	
	for (var i = 0; i < ds_list_size(plan); i++)
	{
		var act = plan[|i]
		if (!ds_map_valid(act))
			return "ai_error_plan"
		var type = act[?"type"]
		if (!is_string(type))
			return "ai_error_plan"
		
		// Resolve object + part
		var tl = null
		var objname = act[?"object"]
		if (is_string(objname))
			tl = ai_find_tl(objname)
		
		// Each type has its own requirements
		switch (type)
		{
			case "set_pose":
				if (tl == null)
					return "ai_error_object_missing"
				var part = act[?"part"]
				if (!is_string(part) || ai_find_part(tl, part) == null)
					return "ai_error_part_missing"
				if (ai_validate_values(act) != "")
					return "ai_error_plan"
				ai_track_tl(tl, count)
				break
				
			case "set_object":
				if (tl == null)
					return "ai_error_object_missing"
				if (ai_validate_values(act) != "")
					return "ai_error_plan"
				ai_track_tl(tl, count)
				break
				
			case "move_object":
				if (tl == null)
					return "ai_error_object_missing"
				if (ai_validate_values(act) != "")
					return "ai_error_plan"
				ai_track_tl(tl, count)
				break
				
			case "set_camera":
				var cam = ai_find_camera()
				if (cam == null)
					return "ai_error_object_missing"
				if (ai_validate_values(act) != "")
					return "ai_error_plan"
				ai_track_tl(cam, count)
				break
				
			case "add_keyframe":
			case "remove_keyframe":
				if (tl == null)
					return "ai_error_object_missing"
				var part2 = act[?"part"]
				if (is_string(part2))
				{
					var p = ai_find_part(tl, part2)
					if (p == null)
						return "ai_error_part_missing"
					ai_track_tl(p, count)
				}
				else
					ai_track_tl(tl, count)
				var frame = act[?"frame"]
				if (is_real(frame) && round(frame) < 0)
					return "ai_error_plan"
				break
				
			case "set_render":
				if (ai_validate_render(act) != "")
					return "ai_error_plan"
				app.ai_any_render = true
				break
				
			default:
				return "ai_error_plan"
		}
	}
	return ""
}

/// ai_validate_values(act)
/// @arg act
/// @desc Checks that the "values" map only contains known axes with numeric
///       values. Returns an error key or "".

function ai_validate_values(act)
{
	var values = act[?"values"]
	if (!ds_map_valid(values))
		return "ai_error_plan"
	
	var key = ds_map_find_first(values)
	while (!is_undefined(key))
	{
		var vid = ai_value_to_enum(key)
		if (vid < 0)
			return "ai_error_plan"
		if (!is_real(values[?key]))
			return "ai_error_plan"
		key = ds_map_find_next(values, key)
	}
	return ""
}

/// ai_validate_render(act)
/// @arg act
/// @desc Checks that the "values" map only contains known render settings.

function ai_validate_render(act)
{
	var values = act[?"values"]
	if (!ds_map_valid(values))
		return "ai_error_plan"
	
	var key = ds_map_find_first(values)
	while (!is_undefined(key))
	{
		switch (key)
		{
			case "samples":
			case "render_distance":
			case "exposure":
			case "gamma":
			case "aa_power":
				if (!is_real(values[?key]))
					return "ai_error_plan"
				break
			default:
				return "ai_error_plan"
		}
		key = ds_map_find_next(values, key)
	}
	return ""
}

/// ai_track_tl(tl, count)
/// @arg tl
/// @arg count
/// @desc Adds a timeline to the affected list if not already present.

function ai_track_tl(tl, count)
{
	var list = app.ai_affected_tls
	for (var i = 0; i < array_length(list); i++)
	{
		if (list[i] = tl)
			return
	}
	list[array_length(list)] = tl
	app.ai_affected_tls = list
}
