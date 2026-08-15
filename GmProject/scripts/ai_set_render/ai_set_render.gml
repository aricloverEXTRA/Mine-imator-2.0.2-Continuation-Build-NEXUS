/// ai_set_render(vmap)
/// @arg vmap
/// @desc Applies render settings from a values map. Keys: samples, render_distance,
///       exposure, gamma, aa_power. Returns true on success, false if an unknown key.

function ai_set_render(vmap)
{
	if (!ds_map_valid(vmap))
		return false
	
	var key = ds_map_find_first(vmap)
	while (!is_undefined(key))
	{
		var v = vmap[?key]
		switch (key)
		{
			case "samples":
				project_render_samples = clamp(round(v), 1, 4096)
				render_samples = -1
				break
			case "render_distance":
				project_render_distance = clamp(round(v), 1, 100000)
				render_samples = -1
				break
			case "exposure":
				project_render_exposure = clamp(v, 0.01, 100)
				render_samples = -1
				break
			case "gamma":
				project_render_gamma = clamp(v, 0.1, 10)
				render_samples = -1
				break
			case "aa_power":
				project_render_aa_power = clamp(round(v), 0, 8)
				render_samples = -1
				break
			default:
				return false
		}
		key = ds_map_find_next(vmap, key)
	}
	return true
}
