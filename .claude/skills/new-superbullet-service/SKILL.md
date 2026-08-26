---
name: new-superbullet-service
description: Cria a estrutura de um novo Service (server) ou Controller (client) do SuperbulletFrameworkV1-Knit a partir do template, seguindo o padrão Accessor/Mutator/Others. Use quando o usuário pedir "cria um Service/Controller novo chamado X".
---

Você vai criar um Service ou Controller novo para o `SuperbulletFrameworkV1-Knit`.

## Passo 1 — reunir informação

Pergunte (ou infira do pedido do usuário) se ainda não estiver claro:

1. Nome do sistema (ex.: `InventoryService`, `ShopController`). Segue
   `.claude/rules/naming-conventions.md`: `Service` no server, `Controller` no
   client.
2. Se é server (`Service`) ou client (`Controller`).
3. **Qual feature** ele pertence (`framework/src/{Feature}/`) — projeto usa
   estrutura feature-based (Rogen): cada domínio tem sua própria pasta com
   `client/`, `server/`, `shared/` dentro. Feature existente (ex.: `Profile`,
   `SuperbulletLogger`) ou nome de feature nova.
4. Se precisa de `Accessor.lua`/`Mutator.lua`/`Others/` desde já, ou só
   `init.lua`. Regra de `.claude/rules/knit-architecture.md`: só criar os três
   se o sistema for crescer além de ~300 linhas ou já tiver separação clara
   leitura/escrita/validação em mente. CRUD simples e sistemas pequenos (<100
   linhas) ficam só no `init.lua`.

## Passo 2 — copiar o template certo

- Service: copiar `framework/documentations/templates/TemplateService/` para
  `framework/src/{Feature}/server/{NomeService}/`.
- Controller: copiar `framework/documentations/templates/TemplateController/`
  para `framework/src/{Feature}/client/{NomeController}/`.

Se a feature ainda não existir, a pasta é criada nesse mesmo passo — não
precisa de nenhum arquivo especial pra "registrar" uma feature, o Rogen
detecta a pasta automaticamente no próximo `rogen build`/`rogen watch`.

Renomear todas as ocorrências de `TemplateService`/`TemplateController` dentro
dos arquivos copiados (`init.lua`, e o nome passado em
`Superbullet.CreateService({Name = "..."})`/`Superbullet.CreateController({Name
= "..."})`) para o nome real do sistema.

Se o passo 1 concluiu que não precisa de `Accessor`/`Mutator`/`Others`, apagar
a pasta `Components/` inteira e manter `init.lua` sozinho com `Instance =
script` removido (autoload só faz sentido se `Components/` existir).

## Passo 3 — checklist final

- `Instance = script` presente no `init.lua`, se `Components/` existir (ver
  `.claude/agents-memory/knit-component-pattern.md` pro porquê).
- `:SuperbulletInit()`/`:SuperbulletStart()` (ou `.Init()`/`.Start()` de cada
  componente) não fazem nenhuma chamada bloqueante dentro de Init.
- Se o sistema vai expor RemoteEvent/RemoteFunction pro client, seguir
  `.claude/rules/security.md` (ação, não valor; server sempre valida).
- Se o sistema vai lidar com dados de jogador, seguir
  `.claude/rules/datastore.md` em vez de reinventar acesso a DataStore.

Se o pedido tocar mais de um sistema por vez (ex.: "cria Service de inventário
e Controller de loja"), execute um sistema por vez, um `Skill` por sistema —
não misturar os dois numa única leva de arquivos.
