/// action_ai_toggle_context(value)
/// @arg value
/// @desc Toggles per-project context gathering. This only sends project/scene
///       understanding to the model on demand (never telemetry, never tracking).

function action_ai_toggle_context(value)
{
	project_ai_context_enabled = value
	project_changed = true
}
