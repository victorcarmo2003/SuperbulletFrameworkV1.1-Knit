---
name: rogen-migration-notes
description: Como o Rogen CLI funciona de verdade (confirmado lendo o código-fonte e rodando de verdade) — migração pra estrutura feature-based concluída em 2026-08-26
metadata:
  type: reference
---

**Migração concluída em 2026-08-26.** Projeto usa Rogen 1.4.4 desde então
(`framework/rokit.toml`, `framework/.rogen.json`). `framework/foreman.toml`
(selene/wally/luau-lsp/remodel/luau-analyze) continua existindo **de
propósito**, não foi consolidado no Rokit — decisão do usuário registrada em
[[decisions-log]], não é resquício esquecido. Nota de correção: o
`rokit.toml` foi criado por engano na raiz do repo na primeira execução (cwd
não persistiu entre chamadas de shell como esperado) e movido pra
`framework/rokit.toml` depois — confirmado por `rogen version`/`rojo
--version`/`rogen build` que Rokit resolve o manifest andando pra cima na
árvore de diretórios, então nada quebrou funcionalmente no meio tempo, só a
localização do arquivo estava errada.

Este arquivo documenta o
mecanismo real (confirmado lendo o código-fonte E rodando `rogen build` de
verdade neste repo) — útil pra quem for criar uma feature nova, reorganizar
uma existente, ou depurar um `default.project.json` gerado que não bateu com
o esperado. Fontes: `src/types.ts`, `src/cli.ts`, `src/route.ts`,
`src/tree.ts`, `src/config.ts`, `src/constants.ts` (github.com/LDGerrits/rogen,
branch `main`), `docs/content/docs/v1/{configuration,cli,index}.mdx`,
`docs/content/docs/v1/core-concepts/{routing-rules,advanced-routing-rules}.mdx`,
`docs/content/docs/v1/setups/luau.mdx`, e execução real de `rogen build`
dentro de `framework/`.

## Confirmado — pronto pra planejar em cima

**Extensão de arquivo**: suporta `.lua` **e** `.luau` igualmente
(`isScript = /\.(tsx?|luau|lua)$/i` em `src/tree.ts`). Não precisa renomear
nenhum arquivo do projeto (que hoje é todo `.lua`). Isso era a maior dúvida
antes de planejar a migração — resolvida.

**Instalação**: não instalado ainda nesta máquina (`rogen` não está no PATH,
não está no npm global). Via Rokit: adicionar entrada em `rokit.toml`
(inexistente no repo ainda) + `rokit install`. Via npm:
`npm i @ldgerrits/rogen`, roda com `npx rogen`.

**Comandos** (`src/cli.ts`):
- `rogen init` — gera `.rogen.json` default na raiz do projeto.
- `rogen build` (ou só `rogen`, é o comando default) — build único.
- `rogen watch` — observa `source` e builda automático a cada mudança.
- Flags: `-c/--config`, `-m/--mode`, `-s/--source`, `-t/--tag`, `-p/--project`,
  `-b/--build`, `-o/--output`, `-h/--help`, `-v/--version`.

**Fluxo de trabalho** (`docs/setups/luau.mdx`): `rogen watch` numa aba +
`rojo serve` noutra aba (lendo o `default.project.json` que o Rogen gera).
Rogen não substitui o Rojo, só gera o project file que o Rojo consome.

## Formato do `.rogen.json` (`src/types.ts` + `src/constants.ts`)

Fica na raiz do projeto (equivalente a `framework/`, onde já está `src/` e
`default.project.json` hoje). Schema real (`defaultConfig` em
`constants.ts`):

```json
{
	"source": ["src"],
	"tags": {},
	"verbatim": false,
	"casing": "camelCase",
	"unwrap": false,
	"aliases": {},
	"globIgnorePaths": [],
	"luau": {
		"output": "default.project.json",
		"build": "src",
		"tags": {},
		"globIgnorePaths": []
	},
	"project": { "name": "roblox-game", "tree": { "$className": "DataModel" } }
}
```

- `luau.output`/`luau.build` já batem com o setup atual do projeto (Luau puro,
  sem transpile) — `source` e `build` seriam o mesmo dir (`src`), sem etapa
  intermediária.
- `project.tree` é a árvore Rojo **base** que o Rogen faz merge com os `$path`
  que ele gera — só precisa conter o que **não** vem de `src/` (ver seção
  Wally abaixo). O `default.project.json` atual do repo vira quase só esse
  campo, sem os `$path` manuais (o Rogen assume esse trabalho).
- `aliases`: mapeamento customizado de affix → serviço Roblox. Dá pra
  registrar `"Service": "ServerScriptService"`/`"Controller":
  "StarterPlayerScripts"` — mas o projeto já resolve isso por **pasta**
  (`server`/`client`/`shared` dentro de cada feature), então aliases talvez
  nem sejam necessários. Avaliar na hora do plano se algum caso pontual
  precisa.

## Regras de roteamento (`src/route.ts`, `src/constants.ts`)

Três formas, "a regra mais profunda vence" (arquivo > pasta):

1. **Nome de pasta**: pasta chamada `server`/`client`/`shared` (case
   insensitive) ou nome exato de serviço Roblox (`ReplicatedFirst`,
   `ServerStorage`, etc.) roteia tudo dentro dela. A pasta some do caminho
   final, o conteúdo não. Mapeamento embutido:
   `Server→ServerScriptService`, `Client→StarterPlayerScripts`,
   `Shared→ReplicatedStorage`, mais nomes exatos de serviço. `serviceParents`
   sabe aninhar `StarterPlayerScripts`/`StarterCharacterScripts` dentro de
   `StarterPlayer` automaticamente.
2. **Afixo no nome do arquivo**: `Combat_Server.lua`, `CombatClient.lua` —
   separadores aceitos `.`, `-`, `_`, `+`, ou PascalCase/camelCase direto. O
   afixo é removido do nome final.
3. **Marker file vazio** (`.server`, `.client` dentro de uma pasta): roteia a
   pasta inteira, mas **preserva** o nome da pasta no caminho final (diferente
   da regra 1, que remove o nome da pasta).

Fallback sem nenhuma regra: `ReplicatedStorage`.

**Avançado** (`advanced-routing-rules.mdx`):
- `(nome)` — pasta invisível: agrupa localmente, não aparece no Studio.
- `^prefixo` — hoisting: sobe o arquivo pra raiz do serviço.
- Marker files por pasta (aplicam à pasta e subpastas): `.structure`
  (preserva layout exato, mas mantém tag filtering), `.sync` (sync bruto,
  ignora toda regra), `.verbatim` (mantém afixo no nome final), `.unwrap`
  (não cria pasta wrapper `server`/`client`/`shared`).
- Pasta com `init.lua`/`init.luau`: aplica roteamento normal, mas **para** de
  aplicar regras pro conteúdo dela (a pasta vira uma unidade). Bate com o
  padrão atual (`Components/` dentro de um `init.lua` de Service/Controller).

## Wally `Packages/` — resolvido, mas com uma pegadinha real (leia antes de editar `project.tree`)

`Packages/` mora em `framework/Packages/` (**fora** de `src/`, movido de
`src/ReplicatedStorage/Packages/` na migração) — não é escaneado pelo Rogen,
não segue convenção `client/server/shared`.

`createFallbackConfig` (`src/config.ts`) detecta sozinho: se existe
`wally.toml` no diretório onde o Rogen roda (`framework/`) E existe uma pasta
`Packages/` no mesmo diretório, ele adiciona
`ReplicatedStorage.Packages.$path = "Packages"` automaticamente no
`project.tree` **fallback** — não precisa declarar isso a mão.

**A pegadinha**: essa detecção automática só vale enquanto o `.rogen.json`
**não** declarar `project` explicitamente. `loadConfig` (`src/config.ts`) faz
merge **raso** — quando `project` aparece no `.rogen.json`, ele
**substitui inteiro** o `project` do fallback (não faz merge profundo dos
campos internos como faz com `luau`/`ts`/`darklua`). Isso foi confirmado
rodando de verdade nesta migração: ao declarar `project.tree` manual (pra
setar `$ignoreUnknownInstances: true` em `ReplicatedStorage`/
`ServerScriptService`, ver abaixo), `Packages` sumiu do `default.project.json`
gerado até eu adicionar `"Packages": {"$path": "Packages"}` manualmente
dentro do meu próprio `project.tree`. **Regra prática: se o `.rogen.json` do
projeto declarar `project.tree`, ele tem que incluir `Packages` manualmente
— a auto-detecção do Wally não roda mais.**

## `$ignoreUnknownInstances` — por que `framework/.rogen.json` declara `project.tree`

Sem declarar nada, o Rogen gera nós `ReplicatedStorage`/`ServerScriptService`
**sem** `$ignoreUnknownInstances` (só seta `false` em nós criados que não são
"root service" — `getOrCreateNode` em `src/tree.ts`; serviços raiz ficam sem
a flag). O projeto original tinha `$ignoreUnknownInstances: true` explícito
nesses dois (necessário porque o `SuperbulletServerLogger` cria RemoteEvents/
RemoteFunction em runtime direto em `ReplicatedStorage`, fora de qualquer
`$path` gerenciado — sem essa flag, um sync do Rojo pode removê-los). Por
isso `framework/.rogen.json` declara `project.tree` com essas duas flags
explícitas — e por causa da pegadinha acima, também precisa declarar
`Packages` ali dentro.

## `default.project.json` final confirmado (rodando `rogen build` de verdade)

```
ReplicatedStorage      (project.tree base: $ignoreUnknownInstances=true)
  Packages              -> Packages/                    (Wally, $path estático)
  Profile               -> src/Profile/shared/           (ProfileTemplate.lua)
  SuperbulletLogger      -> src/SuperbulletLogger/shared/  (LogLevel, CodeExecutorCore)
ServerScriptService     (project.tree base: $ignoreUnknownInstances=true)
  Bootstrap              -> src/Bootstrap/server/         (SuperbulletServer.server.lua)
  Profile                -> src/Profile/server/           (ProfileService/, Externals/)
  SuperbulletLogger      -> src/SuperbulletLogger/server/  (init.server.lua + módulos)
StarterPlayer
  StarterPlayerScripts   (antes SEM $path — bug real, sumia — ver abaixo)
    Bootstrap             -> src/Bootstrap/client/         (SuperbulletClient.client.lua)
    Profile                -> src/Profile/client/           (DataController.lua)
    SuperbulletLogger      -> src/SuperbulletLogger/client/  (init.client.lua + módulos)
```

`unwrap: true` no `.rogen.json` — sem isso, cada feature ganharia uma pasta
extra `server`/`client`/`shared` visível no Studio dentro do container (ex.:
`Profile > server > ProfileService`); com `unwrap`, fica direto
`Profile > ProfileService`.

## Bug pré-existente que a migração corrigiu de graça

O `default.project.json` de antes da migração não tinha `$path` em
`StarterPlayer` — então `src/StarterPlayer/**` nunca sincronizava pro Studio
(o bootstrap client, o loader de Controllers e o `SuperbulletClientLogger`
inteiro nunca rodavam de verdade). O `default.project.json` **gerado pelo
Rogen** cria `StarterPlayer > StarterPlayerScripts` automaticamente (via
`serviceParents` em `src/constants.ts`, que sabe aninhar
`StarterPlayerScripts`/`StarterCharacterScripts` sob `StarterPlayer`) assim
que encontra uma pasta `client/` em qualquer feature — corrigido sem
precisar de nenhuma ação manual.

## Requires que mudaram na migração (pattern pra seguir em features novas)

- Loader do server (`Bootstrap/server/SuperbulletServer.server.lua`) agora
  escaneia `ServerScriptService:GetDescendants()` inteiro (antes: só
  `ServerSource.Server`), filtra `Name:match("Service$")` e **exclui**
  qualquer módulo dentro de uma pasta `Externals` (evita pegar código
  vendorizado tipo `Profile/server/Externals/ProfileService.lua`, que
  termina em "Service" mas não é um Superbullet Service).
- Loader do client (`Bootstrap/client/SuperbulletClient.client.lua`) agora
  escaneia `script.Parent:GetDescendants()` — o próprio script já roda dentro
  de `StarterPlayerScripts`/`PlayerScripts`, não precisa mais alcançar
  `ReplicatedStorage.ClientSource` por fora.
- Requires cross-shared ficaram mais curtos: `ReplicatedStorage.<Feature>.<Modulo>`
  em vez do caminho de 4 níveis antigo (`ReplicatedStorage.SharedSource.Utilities.X`).
- Dentro da mesma feature, `script.Parent`/`script.Parent.Parent` continuam
  funcionando igual — a reestruturação de pastas não muda relação relativa
  entre arquivos da mesma feature.

## Bugs introduzidos na migração e corrigidos (achados pelo `superbullet-architecture-reviewer` pós-migração)

Erro de contagem de `.Parent` — o colapso de pasta+`init.lua` num nó só
(ver `.claude/rules/knit-architecture.md`) muda quantos `.Parent` são
necessários comparado ao que pareceria "óbvio" olhando só a árvore de
arquivos em disco. Os dois bugs abaixo vieram desse mesmo erro de contagem:

1. `Profile/server/ProfileService/init.lua` — escrevi
   `script.Parent.Parent:WaitForChild("Externals")`, mas `ProfileService/`
   (pasta+`init.lua`) colapsa num nó só chamado `ProfileService`, então
   `script.Parent` **já é** `Profile` (não `ProfileService`) — `Externals` é
   filho direto de `script.Parent`, não de `script.Parent.Parent` (que sobe
   demais, até `ServerScriptService`). Sem timeout no `WaitForChild`, isso
   travava o boot do server inteiro pra sempre (silencioso, sem erro).
   Corrigido pra `script.Parent:WaitForChild("Externals", 10)`.
2. `Bootstrap/client/SuperbulletClient.client.lua` — escrevi
   `script.Parent:GetDescendants()` achando que `script.Parent` seria
   `PlayerScripts` em runtime. Na verdade `Bootstrap`, `Profile` e
   `SuperbulletLogger` são pastas **irmãs** direto sob `StarterPlayerScripts`
   (cada feature mantém seu próprio nome de pasta) — `script.Parent` é só
   `Bootstrap`, que não contém `DataController` (está em `Profile/client/`).
   O loader nunca via nenhum Controller fora da própria pasta `Bootstrap` —
   `DataController` nunca carregava, silencioso. Corrigido pra escanear
   `Players.LocalPlayer:WaitForChild("PlayerScripts"):GetDescendants()`
   (raiz de verdade, não depende de contar níveis).

**Lição pra próxima vez que mexer em `script.Parent`/`.Parent.Parent` depois
de mover arquivo de pasta**: sempre conferir a árvore real no
`default.project.json` gerado (não presumir pela estrutura de pastas em
disco) — pasta com `init.lua` dentro colapsa num nó só, pasta sem `init.lua`
vira nó normal com filhos, e isso muda a contagem de `.Parent` necessária.

## Ainda não confirmado (baixo risco, não bloqueou a migração)

- Comportamento exato de `.rogen.json` `project` quando é string (path pra
  JSON externo) vs objeto inline — usamos objeto inline, não testamos string.
- v2 (`docs/content/docs/v2/`) só tem `index.mdx` — parece incompleto/não
  lançado. Projeto ficou na v1 (1.4.4).
- Sync real no Studio (`rojo serve` + abrir o `.rbxl`) não foi testado nesta
  sessão (sem acesso a Roblox Studio) — só validado estaticamente
  (`rogen build` real + inspeção do JSON gerado + `selene` sem erro). Rodar
  isso é o próximo passo de verificação de quem for usar o projeto depois
  dessa migração.
