# Toolchain

## Duas ferramentas de toolchain coexistindo (decisão deliberada)

- `framework/foreman.toml` — ainda lista `selene`, `wally` (dependências em
  `framework/wally.toml`/`wally.lock` — `Component`, `Superbullet`, `Signal`,
  `vide`), `luau-lsp`, `luau-analyze`, `remodel`. Na prática o `foreman` não
  costuma estar instalado nas máquinas do time — o shim genérico do `rokit`
  intercepta o comando (`selene`, `wally`, etc.) no PATH antes do `foreman`
  ter chance de rodar, e falha se a tool não estiver também declarada em
  `framework/rokit.toml`. `wally`, `luau-lsp` e `remodel` ainda têm esse gap
  latente — só `selene` foi migrado até agora (2026-08-27, ver
  `.claude/agents-memory/decisions-log.md`).
- `framework/rokit.toml` — `rogen`, `rojo`, `lune` (runtime standalone usado
  por `framework/scripts/check-architecture.luau`) e `selene` (movido de
  `foreman.toml` em 2026-08-27, pin exato igual aos demais). Rodar
  `rokit install` dentro de `framework/` antes de usar qualquer uma dessas
  ferramentas pela primeira vez numa máquina nova.

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
- Rodar `lune run scripts/check-architecture` (dentro de `framework/`) — verifica
  estaticamente a matriz de comunicação obrigatória (`Accessor.lua`/`Get().lua`
  não requer `Mutator.lua`/`Set().lua` do mesmo sistema e vice-versa;
  `Components/Others/*.lua` só é `require`-ado pelo `init.lua` do mesmo sistema)
  em todo `framework/src/**`. Exit code não-zero e mensagem `arquivo:linha` se
  achar violação. Primeira vez numa máquina nova: `lune` já vem via
  `rokit install` (mesmo passo do `rogen`/`rojo`).
- Se a mudança criou/moveu pasta (nova feature, novo `client`/`server`/
  `shared`), rodar `rogen build` e conferir o `default.project.json` gerado
  antes de considerar pronto — não presumir o mapeamento, os detalhes de
  roteamento (nome de pasta vs afixo de arquivo vs marker file) estão em
  `.claude/agents-memory/rogen-migration-notes.md`.
