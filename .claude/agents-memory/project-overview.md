---
name: project-overview
description: O que é o SuperbulletFrameworkV1-Knit, stack, estrutura atual e roadmap de 4 fases combinado com o usuário
metadata:
  type: project
---

## O que é

`SuperbulletFrameworkV1-Knit` é um fork/wrapper do [Knit](https://github.com/Sleitnick/Knit)
para Roblox, mantido pela Superbullet Studios, pensado para dev iniciante e para
ser operado majoritariamente por uma IA treinada no seu uso (SuperbulletAI —
app desktop que faz debug/live-edit via ponte websocket, ver
[[logger-system]]). Filosofia: clareza acima de elegância, erros que ensinam em
vez de stacktrace gigante do Promise, Knit usado só como "sistema pai" pra expor
métodos públicos e evitar dependência cíclica — a lógica real fica em
ModuleScripts comuns.

## Stack

- Luau / Roblox, projeto Rojo (`framework/default.project.json` — **gerado**
  por `rogen build`, não editado à mão, ver [[rogen-migration-notes]]).
- Knit modificado, exposto via `framework/Packages/Superbullet.lua`
  (`Superbullet.CreateService`/`Superbullet.CreateController`).
- Dados de jogador: ProfileService + ProfileStore (loleris/MAD STUDIO).
- Toolchain: `framework/foreman.toml` (selene, wally, luau-lsp, remodel,
  luau-analyze) **e** `framework/rokit.toml` (rogen, rojo) coexistindo —
  decisão deliberada, ver `.claude/rules/tooling.md`.
- `SuperbulletFrameworkV1-ECS` (sobre JECS) é um framework **futuro e separado**,
  citado no README como próximo passo pra devs avançados — não faz parte deste
  repo.

## Estrutura atual (feature-based, via Rogen — migrado em 2026-08-26)

```
framework/
├── rokit.toml / .rogen.json / default.project.json (gerado)
├── Packages/                    << Wally, fora do scan do Rogen (ver rogen-migration-notes)
├── documentations/templates/    << TemplateService/TemplateController, fora de src/, só referência
└── src/
    ├── Bootstrap/{client,server}/       << loaders (SuperbulletServer/Client)
    ├── Profile/{client,server,shared}/  << ProfileService, DataController, ProfileTemplate
    └── SuperbulletLogger/{client,server,shared}/  << debug bridge, Studio-only
```

Cada feature tem `client/` (vira `StarterPlayerScripts`), `server/` (vira
`ServerScriptService`) e/ou `shared/` (vira `ReplicatedStorage`) — o Rogen
roteia automaticamente pelo nome da pasta, sem `$path` manual. Ver
[[rogen-migration-notes]] para o mecanismo de roteamento completo e
[[knit-component-pattern]] para o padrão interno de cada Service/Controller.

Antes da migração a estrutura era layer-based
(`ReplicatedStorage/ClientSource`, `SharedSource`; `ServerScriptService/ServerSource`)
— não existe mais, só mencionada aqui pra quem for ler histórico/commits
antigos.

## Roadmap combinado com o usuário (2026-08-26) — concluído

1. **Infra `.claude`** — `agents/`, `rules/`, `skills/`, `agents-memory/`
   documentando o estado do projeto, pra qualquer agente futuro ter contexto
   sem re-explorar o repo do zero.
2. Auditoria de componentes (Accessor/Mutator/Others) e do sistema de logger —
   achados em [[audit-findings-fase2]].
3. Refinamentos aplicados: ProfileService migrado pro wrapper Superbullet e
   separado em Accessor/Mutator, bugs de race/timeout corrigidos, loggers
   quebrados em módulos <300 linhas.
4. Migração pra estrutura feature-based via **Rogen** — feita. Ver
   [[rogen-migration-notes]] pro mecanismo técnico confirmado no código-fonte
   real do CLI.

Próximas mudanças no projeto não têm mais um roadmap de fases pré-definido —
ver [[decisions-log]] pra decisões pontuais que forem surgindo.
