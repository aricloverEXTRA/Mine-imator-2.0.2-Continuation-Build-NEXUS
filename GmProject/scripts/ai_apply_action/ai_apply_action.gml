/// ai_apply_action(act)
/// @arg act
/// @desc Applies a single validated action map. Returns true on success.

function ai_apply_action(act)
{
	if (!ds_map_valid(act))
		return false
	var type = act[?"type"]
	if (!is_string(type))
		return false
	var frame = ai_action_frame(act)
	
	switch (type)
	{
		case "set_pose":
		case "set_object":
		{
			var tl = ai_find_tl(act[?"object"])
			if (tl == null)
				return false
			var part = act[?"part"]
			if (is_string(part))
			{
				var p = ai_find_part(tl, part)
				if (p == null)
					return false
				tl = p
			}
			return ai_set_values(tl, act[?"values"], "set", frame)
		}
		
		case "move_object":
		{
			var tl = ai_find_tl(act[?"object"])
			if (tl == null)
				return false
			return ai_set_values(tl, act[?"values"], "move", frame)
		}
		
		case "set_camera":
		{
			var cam = ai_find_camera()
			if (cam == null)
				return false
			return ai_set_values(cam, act[?"values"], "set", frame)
		}
		
		case "add_keyframe":
		{
			var tl = ai_find_tl(act[?"object"])
			if (tl == null)
				return false
			var part = act[?"part"]
			if (is_string(part))
			{
				var p = ai_find_part(tl, part)
				if (p == null)
					return false
				tl = p
			}
			return ai_add_keyframe(tl, frame)
		}
		
		case "remove_keyframe":
		{
			var tl = ai_find_tl(act[?"object"])
			if (tl == null)
				return false
			var part = act[?"part"]
			if (is_string(part))
			{
				var p = ai_find_part(tl, part)
				if (p == null)
					return false
				tl = p
			}
			return ai_remove_keyframe(tl, frame)
		}
		
		case "set_render":
			return ai_set_render(act[?"values"])
	}
	return false
}
