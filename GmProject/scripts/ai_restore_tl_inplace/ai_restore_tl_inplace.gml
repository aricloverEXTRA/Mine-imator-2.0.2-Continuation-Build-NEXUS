/// ai_restore_tl_inplace(save, tl)
/// @arg save
/// @arg tl
/// @desc Restores a saved timeline INTO an existing timeline instance (destroys its
///       current keyframes first). Unlike history_restore_tl it does NOT insert the
///       timeline back into the parent tree, because the instance already lives there.

function ai_restore_tl_inplace(save, tl)
{
	if (tl == null)
		return 0
	if (!instance_exists(tl))
		return 0
	
	with (tl)
	{
		// Destroy all existing keyframes
		while (ds_list_size(keyframe_list) > 0)
		{
			var kf = keyframe_list[|0]
			ds_list_delete(keyframe_list, 0)
			instance_destroy(kf)
		}
		keyframe_current = null
		keyframe_next = null
		keyframe_prev = null
		
		save_id = save.save_id
		
		// Restore default values
		for (var v = 0; v < e_value.amount; v++)
			value_default[v] = tl_value_find_save_id(v, null, save.value_default[v])
		
		// Restore keyframes
		for (var k = 0; k < save.kf_amount; k++)
		{
			with (new_obj(obj_keyframe))
			{
				position = save.kf_pos[k]
				timeline = tl
				selected = false
				sound_play_index = null
				for (var v = 0; v < e_value.amount; v++)
					value[v] = tl_value_find_save_id(v, null, save.kf_value[k, v])
				ds_list_add(tl.keyframe_list, id)
			}
		}
		
		// Update
		tl_update_scenery_part()
		tl_update_values()
		tl_update_matrix()
		tl_update_length()
	}
}
