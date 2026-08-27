# Interface (Vide + UI Labs)

Regras pro padrão de UI reativa do framework — diferente de Service/
Controller (`knit-architecture.md`) e de Behaviors/Mixins
(`component-architecture.md`), que são lógica de jogo; isto é a camada de
apresentação visual.

## Estrutura

```
src/Interface/client/
├── Elements/    << componentes Vide (Props -> dismount())
└── Story/       << *.storybook.luau + *.story.luau (UI Labs)
```

Nome `Elements/`, não `Components/` — decisão deliberada pra não colidir em
vocabulário com o `Components/` do padrão Accessor/Mutator (Service/
Controller). Mesmo cuidado de nomenclatura que gerou `Behaviors/` (não
`Components/`) pro padrão tag-bound.

## Dependência

`framework/wally.toml`: `vide = "centau/vide@^0.4.1"` — caret, mesmo balde
que `Signal`/`Component` (bibliotecas de terceiro ativamente mantidas,
absorvendo patch/minor automaticamente).

## Padrão de componente Vide

Módulo exporta `function(props: Props): () -> ()`: recebe Props (valores
estáticos e/ou getters reativos — funções `() -> T`), monta via
`vide.mount`, retorna a função de dismount/cleanup que `vide.mount` já
devolve. Sem estado interno — quem chama é dono do estado (mesma disciplina
de "state tem um dono só" que o resto do framework já segue).

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local create = vide.create

export type Props = {
	Parent: Instance,
	Progress: () -> number, -- 0 a 1
}

return function(props: Props): () -> ()
	return vide.mount(function()
		return create "Frame" {
			Name = "ProgressBar",
			Parent = props.Parent,
			Size = function()
				return UDim2.fromScale(math.clamp(props.Progress(), 0, 1), 1)
			end,
		}
	end)
end
```

Exemplo real: `framework/src/Interface/client/Elements/ProgressBar.luau`.

## UI Labs (storybook)

Plugin de Studio, **não** é dependência Wally — convenção de arquivo que o
plugin descobre sozinho escaneando o DataModel:

- Um `*.storybook.luau` por pasta de stories: `return { name = "...",
  storyRoots = { script.Parent } }`.
- Um `*.story.luau` por componente: `return function(target: Instance) ...
  monta o componente ... return function() dismount() end end`.

Exemplos reais: `framework/src/Interface/client/Story/Interface.storybook.luau`,
`framework/src/Interface/client/Story/progressBar.story.luau`.

## Reativo, não engine própria

Estado vem de `vide.source()` (getter/setter), propriedades reativas são
funções anônimas em cima desse getter (`Size = function() return
UDim2.fromScale(props.Progress(), 1) end`). `vide.spring()` pra transição
suave, `vide.indexes()` pra listas reativas. Sem mixin/composição própria
aqui — se um componente precisar de lógica compartilhada com outro, extrair
função Lua comum, não criar engine de composição (mesma filosofia de "pouca
mágica" do resto do framework).
