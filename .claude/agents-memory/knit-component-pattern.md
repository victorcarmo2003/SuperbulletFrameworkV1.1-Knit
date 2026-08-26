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
`KnitServer.lua`/`KnitClient.lua` dentro do pacote Wally publicado (desde
2026-08-26, ver [[decisions-log]]), em
`Packages/_Index/victorcarmo2003_superbullet-knit@0.1.1/superbullet-knit/knit/`,
que chama `Components.ComponentInitializer.Initialize(service, service.Instance)`
(e depois `.Start`) pra todo service/controller com `Instance` setado — arquivo
real: `Packages/_Index/victorcarmo2003_superbullet-knit@0.1.1/superbullet-knit/knit/Components/ComponentInitializer.lua`.
Repo fonte: `github.com/victorcarmo2003/superbullet-knit`. **Caminho muda a
cada bump de versão** (`@0.1.1` vira parte do nome da pasta) — conferir
`framework/wally.toml` pela versão atual antes de assumir esse caminho
literal.

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

`framework/Packages/Superbullet.lua` é um único `require` que reexporta o
pacote publicado `victorcarmo2003/superbullet-knit` — o Knit modificado de
verdade vive dentro desse pacote Wally (`_Index`), não em código solto do
repo nem vendorizado à mão (era vendor local até 2026-08-26, ver
[[decisions-log]] pro porquê da mudança). Se precisar entender o mecanismo
interno de `CreateService`/`CreateController` (não só como usar), tem que
abrir esse pacote indexado, ou o repo fonte
`github.com/victorcarmo2003/superbullet-knit`. `Packages/` fica fora de
`framework/src/` (gerenciado pelo Wally, mapeado automático pelo Rogen — ver
[[rogen-migration-notes]]).

**Atenção ao editar `framework/wally.toml`:** não declarar `Knit = "sleitnick/
knit@..."` de novo — já causou um incidente (`wally install` resolveu essa
entrada literal, baixou Knit vanilla e sobrescreveu o `Packages/Knit.lua`/
`_Index/` que apontava pro fork, apagando-o do working tree sem commit). A
única entrada correta é `Superbullet = "victorcarmo2003/superbullet-knit@..."`.
