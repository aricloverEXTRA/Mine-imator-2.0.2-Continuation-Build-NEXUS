/// ai_remove_keyframe(target, frame)
/// @arg target
/// @arg frame
/// @desc Removes the keyframe at a frame from a timeline (if present). Returns true.

function ai_remove_keyframe(target, frame)
{
	if (target == null)
		return false
	
	var kf = ai_find_keyframe(target, frame)
	if (kf == null)
		return true
	
	with (target)
	{
		var idx = ds_list_find_index(keyframe_list, kf)
		if (idx >= 0)
			ds_list_delete(keyframe_list, idx)
		
		if (keyframe_current = kf)
			keyframe_current = null
		if (keyframe_next = kf)
			keyframe_next = null
		if (keyframe_prev = kf)
			keyframe_prev = null
		
		instance_destroy(kf)
		
		tl_update_values()
		tl_update_matrix()
		tl_update_length()
	}
	return true
}
