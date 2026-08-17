/// ai_gather_context()
/// @desc Builds a compact read-only JSON snapshot of the current project.
///       This is the AI's "understanding" of the project (the telemetry toggle).
///       It only runs when the user sends a prompt, never in the frame loop.
///       Enhanced v2: includes object transforms, keyframe data, lighting,
///       world settings, and an object-count summary for better AI reasoning.

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
	
	// World / background summary (lighting, sky, fog)
	s += ",\"world\":" + ai_context_world()
	
	// Object-count summary (helps AI understand the scene at a glance)
	s += ",\"scene_summary\":" + ai_context_scene_summary()
	
	// All top-level objects (now with transforms + keyframe data)
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
/// @desc JSON fragment describing one timeline (name, kind, transforms,
///       visibility, keyframe data, and direct child parts).

function ai_context_object(tl)
{
	var s = "{"
	s += "\"name\":" + ai_json_string(tl.display_name)
	s += ",\"kind\":" + ai_json_string(ai_tl_kind(tl))
	
	// Transforms — the AI needs to know where objects are
	s += ",\"pos_x\":" + string(tl.value[e_value.POS_X])
	s += ",\"pos_y\":" + string(tl.value[e_value.POS_Y])
	s += ",\"pos_z\":" + string(tl.value[e_value.POS_Z])
	s += ",\"rot_x\":" + string(tl.value[e_value.ROT_X])
	s += ",\"rot_y\":" + string(tl.value[e_value.ROT_Y])
	s += ",\"rot_z\":" + string(tl.value[e_value.ROT_Z])
	s += ",\"sca_x\":" + string(tl.value[e_value.SCA_X])
	s += ",\"sca_y\":" + string(tl.value[e_value.SCA_Y])
	s += ",\"sca_z\":" + string(tl.value[e_value.SCA_Z])
	
	// Visibility
	s += ",\"visible\":" + (tl.value[e_value.ALPHA] > 0 ? "true" : "false")
	
	// Keyframe data — so the AI can read existing animation
	var kfcount = ds_list_size(tl.keyframe_list)
	s += ",\"keyframe_count\":" + string(kfcount)
	if (kfcount > 0)
	{
		s += ",\"keyframe_first\":" + string(tl.keyframe_list[|0].position)
		s += ",\"keyframe_last\":" + string(tl.keyframe_list[|kfcount - 1].position)
		// List all keyframe positions (up to 80 — covers most animations)
		s += ",\"keyframe_frames\":["
		var fkf = true
		var kfmax = min(kfcount, 80)
		for (var k = 0; k < kfmax; k++)
		{
			if (!fkf)
				s += ","
			fkf = false
			s += string(tl.keyframe_list[|k].position)
		}
		s += "]"
	}
	
	// Camera-specific fields
	if (tl.type = e_tl_type.CAMERA)
	{
		s += ",\"fov\":" + string(tl.value[e_value.CAM_FOV])
		s += ",\"exposure\":" + string(tl.value[e_value.CAM_EXPOSURE])
	}
	
	// Light-specific fields
	if (tl.type = e_tl_type.POINT_LIGHT || tl.type = e_tl_type.SPOT_LIGHT)
	{
		s += ",\"light_range\":" + string(tl.value[e_value.LIGHT_RANGE])
		s += ",\"light_color\":" + string(tl.value[e_value.LIGHT_COLOR])
		s += ",\"light_strength\":" + string(tl.value[e_value.LIGHT_STRENGTH])
		s += ",\"light_fade_size\":" + string(tl.value[e_value.LIGHT_FADE_SIZE])
	}
	
	// Parts (direct body parts / children)
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

/// ai_context_world()
/// @desc JSON fragment for world/background settings (sky, fog, time).

function ai_context_world()
{
	// Find the background timeline if one exists
	var bg = null
	with (obj_timeline)
	{
		if (type = e_tl_type.BACKGROUND && temp = null && part_of = null)
		{
			bg = id
			break
		}
	}
	if (bg = null)
		return "null"
	
	var s = "{"
	s += "\"name\":" + ai_json_string(bg.display_name)
	// Sky / time
	s += ",\"sky_time\":" + string(bg.value[e_value.BG_SKY_TIME])
	s += ",\"sky_sun_angle\":" + string(bg.value[e_value.BG_SKY_SUN_ANGLE])
	s += ",\"sky_color\":" + string(bg.value[e_value.BG_SKY_COLOR])
	s += ",\"sky_rotation\":" + string(bg.value[e_value.BG_SKY_ROTATION])
	s += ",\"sky_clouds_show\":" + string(bg.value[e_value.BG_SKY_CLOUDS_SHOW])
	s += ",\"sky_clouds_height\":" + string(bg.value[e_value.BG_SKY_CLOUDS_HEIGHT])
	s += ",\"sky_clouds_speed\":" + string(bg.value[e_value.BG_SKY_CLOUDS_SPEED])
	// Fog
	s += ",\"fog_show\":" + string(bg.value[e_value.BG_FOG_SHOW])
	s += ",\"fog_color\":" + string(bg.value[e_value.BG_FOG_COLOR])
	s += ",\"fog_distance\":" + string(bg.value[e_value.BG_FOG_DISTANCE])
	s += ",\"fog_size\":" + string(bg.value[e_value.BG_FOG_SIZE])
	// Sunlight
	s += ",\"sunlight_angle\":" + string(bg.value[e_value.BG_SUNLIGHT_ANGLE])
	s += ",\"sunlight_color\":" + string(bg.value[e_value.BG_SUNLIGHT_COLOR])
	s += ",\"sunlight_strength\":" + string(bg.value[e_value.BG_SUNLIGHT_STRENGTH])
	// Ambient
	s += ",\"ambient_color\":" + string(bg.value[e_value.BG_AMBIENT_COLOR])
	// Ground
	s += ",\"ground_show\":" + string(bg.value[e_value.BG_GROUND_SHOW])
	s += ",\"ground_slot\":" + string(bg.value[e_value.BG_GROUND_SLOT])
	s += ",\"ground_direction\":" + string(bg.value[e_value.BG_GROUND_DIRECTION])
	// Weather
	s += ",\"wind_direction\":" + string(bg.value[e_value.BG_WIND_DIRECTION])
	s += ",\"wind_speed\":" + string(bg.value[e_value.BG_WIND_SPEED])
	s += ",\"twilight\":" + string(bg.value[e_value.BG_TWILIGHT])
	s += "}"
	return s
}

/// ai_context_scene_summary()
/// @desc JSON object counting objects by type — gives the AI a quick overview.
///       Uses ds_map to avoid struct dependency (compatible with older GMS).

function ai_context_scene_summary()
{
	var counts = ds_map_create()
	var total = 0
	with (obj_timeline)
	{
		if (part_of != null || temp != null)
			continue
		var kind = ai_tl_kind(id)
		if (ds_map_exists(counts, kind))
			counts[?kind]++
		else
			counts[?kind] = 1
		total++
	}
	var s = "{"
	s += "\"total\":" + string(total)
	// Add counts per kind
	var key = ds_map_find_first(counts)
	while (!is_undefined(key))
	{
		s += ",\"" + key + "\":" + string(counts[?key])
		key = ds_map_find_next(counts, key)
	}
	s += "}"
	ds_map_destroy(counts)
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
///       Includes full transforms, keyframe data, and body part list so the
///       AI has everything it needs to make precise edits.

function ai_context_selected()
{
	if (tl_edit == null)
		return "null"
	var s = "{"
	s += "\"name\":" + ai_json_string(tl_edit.display_name)
	s += ",\"kind\":" + ai_json_string(ai_tl_kind(tl_edit))
	s += ",\"frame\":" + string(round(app.timeline_marker))
	
	// Full transforms
	s += ",\"pos_x\":" + string(tl_edit.value[e_value.POS_X])
	s += ",\"pos_y\":" + string(tl_edit.value[e_value.POS_Y])
	s += ",\"pos_z\":" + string(tl_edit.value[e_value.POS_Z])
	s += ",\"rot_x\":" + string(tl_edit.value[e_value.ROT_X])
	s += ",\"rot_y\":" + string(tl_edit.value[e_value.ROT_Y])
	s += ",\"rot_z\":" + string(tl_edit.value[e_value.ROT_Z])
	s += ",\"sca_x\":" + string(tl_edit.value[e_value.SCA_X])
	s += ",\"sca_y\":" + string(tl_edit.value[e_value.SCA_Y])
	s += ",\"sca_z\":" + string(tl_edit.value[e_value.SCA_Z])
	s += ",\"alpha\":" + string(tl_edit.value[e_value.ALPHA])
	
	// Camera-specific
	if (tl_edit.type = e_tl_type.CAMERA)
	{
		s += ",\"fov\":" + string(tl_edit.value[e_value.CAM_FOV])
		s += ",\"exposure\":" + string(tl_edit.value[e_value.CAM_EXPOSURE])
		s += ",\"gamma\":" + string(tl_edit.value[e_value.CAM_GAMMA])
	}
	
	// Light-specific
	if (tl_edit.type = e_tl_type.POINT_LIGHT || tl_edit.type = e_tl_type.SPOT_LIGHT)
	{
		s += ",\"light_range\":" + string(tl_edit.value[e_value.LIGHT_RANGE])
		s += ",\"light_color\":" + string(tl_edit.value[e_value.LIGHT_COLOR])
		s += ",\"light_strength\":" + string(tl_edit.value[e_value.LIGHT_STRENGTH])
		s += ",\"light_fade_size\":" + string(tl_edit.value[e_value.LIGHT_FADE_SIZE])
	}
	
	// Keyframe data
	var kfcount = ds_list_size(tl_edit.keyframe_list)
	s += ",\"keyframe_count\":" + string(kfcount)
	if (kfcount > 0)
	{
		s += ",\"keyframe_first\":" + string(tl_edit.keyframe_list[|0].position)
		s += ",\"keyframe_last\":" + string(tl_edit.keyframe_list[|kfcount - 1].position)
		// List ALL keyframe positions (up to 120)
		s += ",\"keyframe_frames\":["
		var fkf = true
		var kfmax = min(kfcount, 120)
		for (var k = 0; k < kfmax; k++)
		{
			if (!fkf)
				s += ","
			fkf = false
			s += string(tl_edit.keyframe_list[|k].position)
		}
		s += "]"
	}
	
	// Body parts (for characters)
	s += ",\"parts\":["
	var first = true
	with (obj_timeline)
	{
		if (part_of != tl_edit)
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
