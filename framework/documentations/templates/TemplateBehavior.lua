local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Component = require(ReplicatedStorage.Packages.Component)

local TemplateBehavior = Component.new({
	Tag = "TemplateTag", -- trocar pela Tag real (Tag Editor do Studio)
})

function TemplateBehavior:Construct()
	-- Setup síncrono. NUNCA yield aqui (WaitForChild, :await(), task.wait())
	-- — mesma regra do SuperbulletInit.
end

function TemplateBehavior:Start()
	-- Trabalho assíncrono, conectar eventos, usar Mixins aqui.
	-- Exemplo: local prompt = SomeMixin.Attach(self, { ... })
end

function TemplateBehavior:Stop()
	-- Cleanup — desconectar tudo que Start conectou.
end

return TemplateBehavior
