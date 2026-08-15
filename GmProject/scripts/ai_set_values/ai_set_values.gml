/// ai_set_values(target, vmap, type, frame)
/// @arg target
/// @arg vmap
/// @arg type
/// @arg frame
/// @desc Applies a values map (key = value name, value = number) to a timeline at a frame.
///       type = "set" replaces, type = "move" offsets the current value.

function ai_set_values(target, vmap, type, frame)
{
	if (target == null || !ds_map_valid(vmap))
		return false
	
	with (target)
	{
		var kf = ai_find_keyframe(id, frame)
		if (kf == null)
			kf = tl_keyframe_add(frame)
		
		var key = ds_map_find_first(vmap)
		while (!is_undefined(key))
		{
			var vid = ai_value_to_enum(key)
			if (vid >= 0)
			{
				var nval = vmap[?key]
				if (type = "move")
					nval = value[vid] + nval
				nval = tl_value_clamp(vid, nval)
				value[vid] = nval
				kf.value[vid] = nval
			}
			key = ds_map_find_next(vmap, key)
		}
		
		tl_update_values()
		tl_update_matrix()
		tl_update_length()
	}
	return true
}
