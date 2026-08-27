# SuperbulletFrameworkV1-Knit

Fork/wrapper do [Knit](https://github.com/Sleitnick/Knit) para Roblox, focado em ser
beginner-friendly e operado principalmente por uma IA treinada no seu uso
(SuperbulletAI). Prioriza clareza sobre elegância: erros que ensinam, padrões
previsíveis, pouca "mágica" de framework.

- Código do framework vive em `framework/src/` (projeto Rojo, veja
  `framework/default.project.json`).
- Documentação de referência mais longa fica em
  `framework/documentations/codebase/*.md`.
- Roadmap ativo de mudanças (infra `.claude`, refino de componentes/logger,
  migração para Rogen) está registrado em `.claude/agents-memory/project-overview.md`.

## Antes de editar código do framework

Leia as regras relevantes em `.claude/rules/` primeiro:

- [`knit-architecture.md`](.claude/rules/knit-architecture.md) — padrão de
  componentes (Accessor/Mutator/Others), ciclo de vida Init/Start, regra das 300
  linhas.
- [`component-architecture.md`](.claude/rules/component-architecture.md) —
  componente tag-bound via CollectionService (Behaviors) + Mixin, diferente
  do padrão Service/Controller acima.
- [`interface-architecture.md`](.claude/rules/interface-architecture.md) —
  padrão de UI reativa (Vide + UI Labs), Elements/Story.
- [`security.md`](.claude/rules/security.md) — o que nunca confiar vindo do
  client.
- [`naming-conventions.md`](.claude/rules/naming-conventions.md) — convenções de
  nome de arquivo/serviço.
- [`datastore.md`](.claude/rules/datastore.md) — como ler/escrever dados de
  jogador via ProfileService.
- [`tooling.md`](.claude/rules/tooling.md) — toolchain (selene, wally, rojo,
  argon, rokit) e o que rodar antes de considerar uma mudança pronta.

## Antes de pesquisar algo do zero

Confira [`.claude/agents-memory/MEMORY.md`](.claude/agents-memory/MEMORY.md) —
índice do que já foi levantado sobre este projeto (arquitetura, sistema de logger,
notas de migração para Rogen, decisões já tomadas com o usuário). Evita re-explorar
o repositório inteiro toda sessão.

## Subagentes disponíveis

Em `.claude/agents/`: `superbullet-system-builder` (Service/Controller),
`superbullet-behavior-builder` (Behaviors/Mixins tag-bound),
`superbullet-ui-builder` (Vide/UI Labs), `superbullet-investigator`,
`superbullet-architecture-reviewer`, `superbullet-logger-maintainer`,
`rogen-migration-planner`. Use o mais específico para a tarefa em vez de
fazer tudo inline — cada um já sabe quais `rules/` e `agents-memory/` ler
primeiro.

## Antes de considerar uma mudança pronta

Rode `/review` — roda o `superbullet-architecture-reviewer` no diff atual
(ou branch/PR/arquivo passado como argumento). Sempre usar antes de dar uma
mudança de framework por concluída.
