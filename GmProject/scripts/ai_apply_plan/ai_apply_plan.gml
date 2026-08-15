/// ai_apply_plan(plan)
/// @arg plan
/// @desc Applies a validated action plan transactionally. Validates EVERY action
///       before changing anything, snapshots all affected timelines + render
///       settings into ONE undo slot, then applies. On any failure the entire
///       plan is rolled back and the history slot removed. Returns "" on success
///       or an error text key.

function ai_apply_plan(plan)
{
	if (!ds_list_valid(plan) || ds_list_size(plan) = 0)
		return ""
	
	// 1) Validate EVERYTHING before touching anything (no history touched on failure)
	var err = ai_validate_plan(plan)
	if (err != "")
		return err
	
	// 2) Snapshot all affected timelines + render settings into one undo slot
	var hobj = history_set(action_ai_apply)
	with (hobj)
	{
		tl_save_amount = 0
		var list = app.ai_affected_tls
		for (var i = 0; i < array_length(list); i++)
		{
			var tl = list[i]
			if (instance_exists(tl))
			{
				tl_save_obj[tl_save_amount] = history_save_tl(tl)
				tl_save_amount++
			}
		}
		save_obj_old = new_obj(obj_history_save)
		with (save_obj_old)
			history_copy_render_settings(app)
		// Plan stored as a JSON string (GC'd) so redo works with zero leaks
		ai_plan = ai_plan_to_json(plan)
	}
	
	// 3) Apply each action; roll back everything on any failure
	for (var i = 0; i < ds_list_size(plan); i++)
	{
		if (!ai_apply_action(plan[|i]))
		{
			ai_rollback_apply(hobj)
			return "ai_error_apply"
		}
	}
	
	// 4) Refresh
	tl_update_values()
	tl_update_matrix()
	tl_update_length()
	app_update_tl_edit()
	
	app.ai_applied = ds_list_size(plan)
	return ""
}

/// ai_rollback_apply(hobj)
/// @arg hobj
/// @desc Rolls back a partially-applied plan and removes its history slot.

function ai_rollback_apply(hobj)
{
	with (hobj)
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
	
	// Remove the failed history slot (hobj sits at index 0 after history_set)
	with (hobj)
	{
		with (obj_history_save)
			if (hobj = other.id)
				instance_destroy()
		instance_destroy()
	}
	for (var h = 1; h <= history_amount; h++)
		history[h - 1] = history[h]
	history_amount--
	history_pos = 0
	
	// Refresh after rollback
	tl_update_values()
	tl_update_matrix()
	tl_update_length()
	app_update_tl_edit()
	render_samples = -1
}
