---
name: knit-component-pattern
description: Padrão Accessor/Mutator/Others do Knit modificado, autoload de componentes, regras de comunicação
metadata:
  type: reference
---

Versão condensada de `framework/documentations/codebase/organizing-project-structure.md`.
Regras vinculantes (o que um agente deve seguir ao editar código) estão em
[[knit-architecture]] (`.claude/rules/knit-architecture.md`) — este arquivo é só
contexto factual de como o mecanismo funciona por baixo.

## Autoload (mecanismo real, confirmado lendo o pacote Wally)

`init.lua` de um Service/Controller declara `Instance = script`. Quem lê isso é
`KnitServer.lua`/`KnitClient.lua` dentro de
`Packages/_Index/superbullet_knit@0.0.1/knit/`, que chama
`Components.ComponentInitializer.Initialize(service, service.Instance)` (e depois
`.Start`) pra todo service/controller com `Instance` setado — arquivo real:
`Packages/_Index/superbullet_knit@0.0.1/knit/Components/ComponentInitializer.lua`.

Existia também um `SharedSource/Utilities/ScriptsLoader/ComponentsInitializer.lua`
de nome parecido mas **código morto** (confirmado por grep em 2026-08-26, sem
nenhum `require` apontando pra ele) — apagado na migração pra Rogen (2026-08-26),
não existe mais no repo.

`ComponentInitializer.Initialize` faz, nessa ordem:

1. Acha `Components/` dentro da instância do sistema.
2. `Others/`: para cada `ModuleScript` descendente de `Components/Others/`,
   `Service.Components[NomeDoArquivo] = require(v)` — acesso achatado
   (`Service.Components["DataValidator"]`), mesmo se estiver em subpasta.
3. `Accessor.lua` (ou `Get()`, legado): `Service.Accessor = require(...)`,
   alias `Service.GetComponent`.
4. `Mutator.lua` (ou `Set()`, legado): `Service.Mutator = require(...)`, alias
   `Service.SetComponent`.
5. Chama `.Init()` de **todo** módulo em `Components/` (Accessor, Mutator,
   Others), sem passar nenhum argumento — nem `self`, nem instância do
   service. Marca atributo `Initialized` no `ModuleScript` pra não rodar duas
   vezes.
6. Depois (`ComponentInitializer.Start`), chama `.Start()` de cada um dentro de
   `task.spawn`, marcando `Started`.

**Isso NÃO é merge de método individual.** O exemplo da doc
(`organizing-project-structure.md`) com `self:GetPlayerLevel(player)` sendo
chamado do parent como se fosse método nativo do Service é enganoso/aspiracional
— na implementação real, pra chamar algo do Accessor é sempre
`Service.Accessor.GetPlayerLevel(player)` (dot syntax, o módulo inteiro fica
pendurado em `Service.Accessor`). A matriz de comunicação (Accessor ↔ Mutator
proibido, Others só via parent) é **convenção de disciplina de arquitetura**,
não uma barreira técnica — nada no `ComponentInitializer` impede um módulo de
dar `require` direto em outro.

Isso explica por que Init não pode yieldar: roda síncrono, no meio do loop que
inicializa todos os componentes de todos os sistemas (`KnitServer`/`KnitClient`
espera essa fase terminar antes de continuar o startup).

## Templates existentes no repo

- `framework/documentations/templates/TemplateController/` — Controller vazio
  com `Components/{Accessor,Mutator,Others/Template}.lua` já com a estrutura
  certa, pronto pra copiar/renomear.
- `framework/documentations/templates/TemplateService/` — mesma coisa, versão
  Service.

Ambos ficam **fora** de `framework/src/` desde a migração pra Rogen
(2026-08-26) — nunca foram sistemas de verdade (`SuperbulletStart`/
`SuperbulletInit` sempre vazios, só esqueleto), então não fazem parte de
nenhuma feature. Ao criar um sistema novo, copiar pra dentro de
`src/{Feature}/server/{NomeService}/` ou `src/{Feature}/client/{NomeController}/`.

## Wrapper Superbullet sobre Knit

`framework/Packages/Superbullet.lua` é um único `require` que reexporta
`Packages/_Index/superbullet_knit@0.0.1/Superbullet` — o Knit modificado de
verdade vive dentro desse pacote Wally (`_Index`), não em código solto do
repo. Se precisar entender o mecanismo interno de
`CreateService`/`CreateController` (não só como usar), tem que abrir esse
pacote indexado. `Packages/` fica fora de `framework/src/` (gerenciado pelo
Wally, mapeado automático pelo Rogen — ver [[rogen-migration-notes]]).
