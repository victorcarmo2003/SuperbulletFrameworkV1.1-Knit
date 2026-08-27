local PromptMixin = {}

export type PromptOptions = {
	ActionText: string,
	KeyboardKeyCode: Enum.KeyCode?,
	HoldDuration: number?,
}

function PromptMixin.Attach(behavior, options: PromptOptions)
	assert(behavior.Instance, "PromptMixin.Attach: behavior.Instance ainda não existe")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = options.ActionText
	prompt.KeyboardKeyCode = options.KeyboardKeyCode or Enum.KeyCode.E
	prompt.HoldDuration = options.HoldDuration or 0
	prompt.Parent = behavior.Instance

	behavior._promptMixin = { Prompt = prompt }
	return prompt
end

function PromptMixin.Detach(behavior)
	local state = behavior._promptMixin
	if not state then
		return
	end
	state.Prompt:Destroy()
	behavior._promptMixin = nil
end

return PromptMixin
