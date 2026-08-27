# Toolchain

## Duas ferramentas de toolchain coexistindo (decisão deliberada)

- `framework/foreman.toml` — `selene` (lint, config em `framework/selene.toml`,
  `std = "roblox"`), `wally` (`framework/wally.toml`/`wally.lock` — deps
  `Component`, `Superbullet`, `Signal`, `vide`), `luau-lsp`, `luau-analyze`,
  `remodel`.
- `framework/rokit.toml` — `rogen` (LDGerrits/rogen) e `rojo`. Adicionado na
  migração para estrutura feature-based (2026-08-26); `foreman.toml`
  propositalmente não foi migrado pra Rokit junto (fora de escopo daquela
  fase). Rodar `rokit install` dentro de `framework/` antes de usar
  `rogen`/`rojo` pela primeira vez numa máquina nova.

## Projeto Rojo — gerado, não editado à mão

`framework/default.project.json` é **gerado por `rogen build`/`rogen watch`**
a partir de `framework/.rogen.json` + `framework/src/**`. Não editar esse
arquivo manualmente — qualquer mudança de estrutura de árvore Rojo
(`$ignoreUnknownInstances`, serviços extras) vai em `.rogen.json` (campo
`project.tree`), e depois rodar `rogen build` de novo. Ver
`.claude/agents-memory/rogen-migration-notes.md` para o formato do
`.rogen.json` e `.claude/agents-memory/project-overview.md` para a estrutura
de pastas feature-based atual.

Fluxo de desenvolvimento: `rogen watch` numa aba (regenera o
`default.project.json` a cada mudança em `src/`) + `rojo serve` noutra (serve
esse project file pro Studio).

## Antes de considerar uma mudança em `framework/src/**` pronta

- Rodar `selene src` (dentro de `framework/`) sobre os arquivos alterados —
  `Packages/` fica fora de `src/` agora, então não precisa mais filtrar ruído
  de pacotes de terceiros.
- Se a mudança criou/moveu pasta (nova feature, novo `client`/`server`/
  `shared`), rodar `rogen build` e conferir o `default.project.json` gerado
  antes de considerar pronto — não presumir o mapeamento, os detalhes de
  roteamento (nome de pasta vs afixo de arquivo vs marker file) estão em
  `.claude/agents-memory/rogen-migration-notes.md`.
