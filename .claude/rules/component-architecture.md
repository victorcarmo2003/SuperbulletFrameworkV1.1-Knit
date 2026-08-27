# Componente tag-bound (Behaviors) + Mixin

Regras para o padrão de componente ligado a Instance via CollectionService —
diferente do padrão Service/Controller (`knit-architecture.md`), que é ligado
a `Instance = script` fixo, um por sistema. Um Behavior é ligado por **Tag**,
um por cada Instance taggeada no mundo, quantos existirem.

## Estrutura

```
src/{Feature}/{server,client}/Behaviors/
└── PickupBehavior.lua

src/Mixins/{shared,server,client}/
└── PromptMixin.lua
```

`Behaviors/` pode morar solto (`src/Behaviors/server/...`, sem feature de
domínio ainda) ou dentro de uma feature real quando existir
(`src/Combat/server/Behaviors/DamageZoneBehavior.lua`) — a descoberta é por
sufixo de nome de arquivo (`*Behavior.lua`), não por pasta fixa, ver
"Autoload" abaixo.

`Mixins/` fica em pasta própria, fora de qualquer feature de domínio —
compartilhado entre Behaviors não relacionados. Escolher `client/`/
`server/`/`shared/` conforme o mixin precisar (ex.: `Instance.new`/
`:Connect` são universais, então `PromptMixin` fica em `shared/`).

## Dependência

`framework/wally.toml`: `Component = "sleitnick/component@^2.4.8"` —
`sleitnick/component` (`github.com/Sleitnick/RbxUtil`), mesmo autor do Knit
original, ativamente mantida. Caret, não pin exato — mesmo balde que
`Signal`/`vide` (bibliotecas de terceiro absorvendo patch/minor
automaticamente). Diferente do `Superbullet` (pin exato, é fork próprio do
projeto).

## Autoload (mecanismo real)

Um Behavior só ativa se for `require`-ado — `Component.new({Tag = ...})`
liga os listeners de `CollectionService` de forma síncrona no momento do
`require`, sem passo de ativação adicional. Os dois loaders de
`Bootstrap/{server,client}/` descobrem por sufixo de nome de arquivo
(`Service$`/`Controller$`/`Behavior$`) via `GetDescendants()` — um Behavior
em qualquer feature, `client/` ou `server/`, é descoberto automaticamente
desde que o arquivo termine em `Behavior.lua`. Sem isso, `Component.new()`
nunca roda.

## Ciclo de vida — regra de ouro: `Construct` nunca faz yield

Mesma regra do `SuperbulletInit`/`KnitInit` (`knit-architecture.md`):
`Construct()` não pode chamar `WaitForChild`, `:await()`, `task.wait()` ou
qualquer coisa que bloqueie. Trabalho assíncrono (conectar evento, usar
Mixin, I/O) vai em `Start()`; cleanup vai em `Stop()`.

```lua
local Component = require(ReplicatedStorage.Packages.Component)

local MyBehavior = Component.new({ Tag = "MyTag" })

function MyBehavior:Construct()
	-- síncrono só
end

function MyBehavior:Start()
	-- assíncrono, conectar eventos, usar Mixin
end

function MyBehavior:Stop()
	-- desconectar tudo que Start conectou
end
```

## Convenção de nome de Tag

PascalCase, nome de domínio simples (`"Pickup"`, `"DamageZone"`) — não
precisa ser igual ao nome do arquivo. A Tag é usável direto no **Tag
Editor** do Studio (aba Model) por qualquer pessoa do time, não só por quem
programa — é assim que se testa um Behavior sem escrever nenhum harness de
código: marcar uma Instance qualquer no Explorer com a Tag, dar Play.

## Mixin — chamada explícita, sem engine de composição

Mixin é uma tabela Lua comum, funções recebem `self` do Behavior como
primeiro argumento, chamada a mão no ciclo de vida do próprio Behavior.
**Nunca** merge automático de método (tipo `:Extend()`) — mesma disciplina
que `Accessor.lua`/`Mutator.lua`/`Others/*.lua` já usam (nunca merge
automático no parent, sempre `Service.Accessor.Algo(...)` explícito).

```lua
-- Mixins/shared/PromptMixin.lua
function PromptMixin.Attach(behavior, options)
	local prompt = Instance.new("ProximityPrompt")
	-- ...
	behavior._promptMixin = { Prompt = prompt } -- estado namespaced
	return prompt
end

-- Behaviors/server/PickupBehavior.lua
function PickupBehavior:Construct()
	PromptMixin.Attach(self, { ActionText = "Pick Up" })
end
```

Estado do mixin sempre fica namespaced (`self._promptMixin`, prefixo do
nome do mixin) — nunca solto direto em `self`, pra não colidir com campo do
próprio Behavior ou de outro mixin.

**Por que não usar `Extensions` da lib `sleitnick/component`**: são hooks
tipo AOP de ciclo de vida (`ShouldConstruct`/`Constructing`/`Starting`/
`Stopping`/etc — interceptam/decoram UMA classe), não injeção de método
compartilhado entre domínios diferentes. Servem pra outra coisa (ex.:
logging, validação, guard clause condicional), não pra reuso de trait tipo
`PromptMixin`.

## `GetComponent` vs Mixin — não confundir

`self:GetComponent(OutraClasse)` (nativo da lib) é pra dois Behaviors **na
mesma Instance** conversarem entre si (ex.: `DoorBehavior` pega o
`LockBehavior` da mesma porta). Mixin é pra código compartilhado entre
Behaviors de **domínios não relacionados**, cada um com sua própria
Instance/Tag. São mecanismos diferentes, não concorrentes.

## Regra das 300 linhas

Aplica igual ao resto do framework, mas a válvula de escape é diferente:
Behaviors não têm subestrutura tipo Accessor/Mutator/Others. Se um Behavior
está fazendo demais, ou extrai lógica reutilizável pra um Mixin, ou quebra
em Behaviors menores com Tags diferentes — não criar uma pasta
`Components/`/`Others/` interna dentro de um Behavior.

## Template

`framework/documentations/templates/TemplateBehavior.lua` — arquivo único
(não pasta), copiar/renomear ao criar um Behavior novo.
