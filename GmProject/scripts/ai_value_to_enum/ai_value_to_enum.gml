/// ai_value_to_enum(key)
/// @arg key
/// @desc Maps a JSON axis key to an e_value id, or -1 if unknown.

function ai_value_to_enum(key)
{
	switch (key)
	{
		case "pos_x": return e_value.POS_X
		case "pos_y": return e_value.POS_Y
		case "pos_z": return e_value.POS_Z
		case "rot_x": return e_value.ROT_X
		case "rot_y": return e_value.ROT_Y
		case "rot_z": return e_value.ROT_Z
		case "sca_x": return e_value.SCA_X
		case "sca_y": return e_value.SCA_Y
		case "sca_z": return e_value.SCA_Z
		case "alpha": return e_value.ALPHA
		case "fov": return e_value.CAM_FOV
		case "exposure": return e_value.CAM_EXPOSURE
		case "gamma": return e_value.CAM_GAMMA
	}
	return -1
}

/// ai_action_frame(act)
/// @arg act
/// @desc Returns the frame for an action (defaults to the current marker).

function ai_action_frame(act)
{
	var frame = act[?"frame"]
	if (is_real(frame))
		return round(frame)
	return round(app.timeline_marker)
}

/// ai_find_keyframe(tl, pos)
/// @arg tl
/// @arg pos
/// @desc Returns the keyframe at the exact position, or null.

function ai_find_keyframe(tl, pos)
{
	if (tl == null)
		return null
	for (var i = 0; i < ds_list_size(tl.keyframe_list); i++)
	{
		var kf = tl.keyframe_list[|i]
		if (kf.position = pos)
			return kf
		if (kf.position > pos)
			break
	}
	return null
}
