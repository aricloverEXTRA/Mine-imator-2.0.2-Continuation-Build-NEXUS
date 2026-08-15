/// ai_gather_context()
/// @desc Builds a compact read-only JSON snapshot of the current project.
///       This is the AI's "understanding" of the project (the telemetry toggle).
///       It only runs when the user sends a prompt, never in the frame loop.

function ai_gather_context()
{
	var s = "{"
	
	// Project basics
	s += "\"project\":{"
	s += "\"name\":" + ai_json_string(project_name)
	s += ",\"author\":" + ai_json_string(project_author)
	s += ",\"video_width\":" + string(project_video_width)
	s += ",\"video_height\":" + string(project_video_height)
	s += ",\"tempo\":" + string(project_tempo)
	s += ",\"viewport\":" + ai_json_string("This is the scene the user currently sees in the viewport; the active camera below matches it.")
	s += "}"
	
	// Timeline
	s += ",\"timeline\":{"
	s += "\"frame\":" + string(round(app.timeline_marker))
	s += ",\"length\":" + string(app.timeline_length)
	s += "}"
	
	// Render settings
	s += ",\"render\":{"
	s += "\"samples\":" + string(project_render_samples)
	s += ",\"render_distance\":" + string(project_render_distance)
	s += ",\"exposure\":" + string(project_render_exposure)
	s += ",\"gamma\":" + string(project_render_gamma)
	s += ",\"aa_power\":" + string(project_render_aa_power)
	s += "}"
	
	// Current camera
	s += ",\"camera\":" + ai_context_camera()
	
	// Selected object
	s += ",\"selected\":" + ai_context_selected()
	
	// All top-level objects
	s += ",\"objects\":["
	var first = true
	with (obj_timeline)
	{
		if (part_of != null || temp != null)
			continue
		if (!first)
			s += ","
		first = false
		s += ai_context_object(id)
	}
	s += "]"
	
	s += "}"
	return s
}

/// ai_context_object(tl)
/// @arg tl
/// @desc JSON fragment describing one timeline (name, kind, parts).

function ai_context_object(tl)
{
	var s = "{"
	s += "\"name\":" + ai_json_string(tl.display_name)
	s += ",\"kind\":" + ai_json_string(ai_tl_kind(tl))
	
	// Parts (direct body parts)
	s += ",\"parts\":["
	var first = true
	with (obj_timeline)
	{
		if (part_of != tl)
			continue
		if (!first)
			s += ","
		first = false
		s += ai_json_string(display_name)
	}
	s += "]"
	s += "}"
	return s
}

/// ai_tl_kind(tl)
/// @arg tl
/// @desc Human-readable kind string for a timeline type.

function ai_tl_kind(tl)
{
	switch (tl.type)
	{
		case e_tl_type.CHARACTER: return "character"
		case e_tl_type.BODYPART: return "body_part"
		case e_tl_type.CAMERA: return "camera"
		case e_tl_type.SCENERY: return "scenery"
		case e_tl_type.ITEM: return "item"
		case e_tl_type.BLOCK: return "block"
		case e_tl_type.MODEL: return "model"
		case e_tl_type.PARTICLE_SPAWNER: return "particle_spawner"
		case e_tl_type.TEXT: return "text"
		case e_tl_type.AUDIO: return "audio"
		case e_tl_type.PATH: return "path"
		case e_tl_type.SPOT_LIGHT: return "spot_light"
		case e_tl_type.POINT_LIGHT: return "point_light"
		case e_tl_type.BACKGROUND: return "background"
	}
	return "object"
}

/// ai_context_camera()
/// @desc JSON fragment for the current viewport camera.

function ai_context_camera()
{
	var cam = ai_find_camera()
	if (cam == null)
		return "null"
	var s = "{"
	s += "\"name\":" + ai_json_string(cam.display_name)
	s += ",\"pos_x\":" + string(cam.value[e_value.POS_X])
	s += ",\"pos_y\":" + string(cam.value[e_value.POS_Y])
	s += ",\"pos_z\":" + string(cam.value[e_value.POS_Z])
	s += ",\"fov\":" + string(cam.value[e_value.CAM_FOV])
	s += ",\"exposure\":" + string(cam.value[e_value.CAM_EXPOSURE])
	s += "}"
	return s
}

/// ai_context_selected()
/// @desc JSON fragment describing the currently selected timeline (if any).

function ai_context_selected()
{
	if (tl_edit == null)
		return "null"
	var s = "{"
	s += "\"name\":" + ai_json_string(tl_edit.display_name)
	s += ",\"kind\":" + ai_json_string(ai_tl_kind(tl_edit))
	s += ",\"frame\":" + string(round(app.timeline_marker))
	s += ",\"keyframes\":" + string(ds_list_size(tl_edit.keyframe_list))
	s += ",\"pos_x\":" + string(tl_edit.value[e_value.POS_X])
	s += ",\"pos_y\":" + string(tl_edit.value[e_value.POS_Y])
	s += ",\"pos_z\":" + string(tl_edit.value[e_value.POS_Z])
	s += ",\"rot_x\":" + string(tl_edit.value[e_value.ROT_X])
	s += ",\"rot_y\":" + string(tl_edit.value[e_value.ROT_Y])
	s += ",\"rot_z\":" + string(tl_edit.value[e_value.ROT_Z])
	// Frames of the selected object's keyframes so the AI can "read" them
	s += ",\"keyframe_frames\":["
	var first = true
	var kfcount = 0
	for (var k = 0; k < ds_list_size(tl_edit.keyframe_list); k++)
	{
		if (kfcount >= 60)
			break
		if (!first)
			s += ","
		first = false
		s += string(tl_edit.keyframe_list[|k].position)
		kfcount++
	}
	s += "]"
	s += "}"
	return s
}
