/// action_ai_apply()
/// @desc Undo/redo handler for the AI apply history slot.

function action_ai_apply()
{
	if (history_undo)
	{
		// Undo: restore snapshots in place
		with (history_data)
		{
			for (var t = 0; t < tl_save_amount; t++)
			{
				var save = tl_save_obj[t]
				var tl = save_id_find(save.save_id)
				if (tl != null)
					ai_restore_tl_inplace(save, tl)
			}
			if (save_obj_old != null)
				history_copy_render_settings(save_obj_old)
		}
		tl_update_values()
		tl_update_matrix()
		tl_update_length()
		app_update_tl_edit()
	}
	else if (history_redo)
	{
		// Redo: decode the stored plan JSON string and re-apply it
		var root = json_decode(history_data.ai_plan)
		if (ds_map_valid(root))
		{
			var plan = root[?"plan"]
			if (ds_list_valid(plan))
			{
				for (var i = 0; i < ds_list_size(plan); i++)
					ai_apply_action(plan[|i])
			}
			ds_map_destroy(root)
		}
		tl_update_values()
		tl_update_matrix()
		tl_update_length()
		app_update_tl_edit()
	}
}
