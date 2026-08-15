/// action_ai_clear_memory()
/// @desc Clears the per-project AI session memory (transcript and any compacted
///       summary). In-memory only; never touches project files.

function action_ai_clear_memory()
{
	if (app.ai_busy || app.ai_memory_compacting)
	{
		toast_new(e_toast.NEGATIVE, text_get("ai_error_busy_compact"))
		return 0
	}
	
	app.ai_memory = []
	app.ai_memory_summary = ""
	toast_new(e_toast.INFO, text_get("ai_memorycleared"))
	return 0
}
