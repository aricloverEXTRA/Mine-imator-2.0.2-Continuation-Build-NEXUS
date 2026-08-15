/// ai_find_camera()
/// @desc Returns the current viewport camera timeline, or the first camera in
///       the project, or null.

function ai_find_camera()
{
	var cam = view_main.camera
	if (is_real(cam) && cam >= 0 && instance_exists(cam) && cam.object_index = obj_timeline)
		return cam
	
	with (obj_timeline)
	{
		if (temp != null)
			continue
		if (type = e_tl_type.CAMERA && part_of = null)
			return id
	}
	return null
}
