/// ai_add_keyframe(target, frame)
/// @arg target
/// @arg frame
/// @desc Adds a keyframe to a timeline at a frame. Returns true if already present or added.

function ai_add_keyframe(target, frame)
{
	if (target == null)
		return false
	
	with (target)
	{
		if (ai_find_keyframe(id, frame) != null)
			return true
		
		tl_keyframe_add(frame)
		tl_update_values()
		tl_update_matrix()
		tl_update_length()
	}
	return true
}
