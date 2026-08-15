/// action_ai_send()
/// @desc Sends the current prompt from the AI tab to the assistant.

function action_ai_send()
{
	if (!project_ai_enabled)
	{
		toast_new(e_toast.NEGATIVE, text_get("ai_error_disabled"))
		return 0
	}
	if (app.ai_busy)
	{
		toast_new(e_toast.NEGATIVE, text_get("ai_error_busy"))
		return 0
	}
	var prompt = tab.ai.tbx_prompt.text
	if (string_length(prompt) < 1)
	{
		toast_new(e_toast.NEGATIVE, text_get("ai_error_noprompt"))
		return 0
	}
	ai_request(prompt)
	tab.ai.tbx_prompt.text = ""
}
