---
name: decisions-log
description: Decisões já tomadas com o usuário sobre o roadmap de mudanças no framework, com data
metadata:
  type: project
---

## 2026-08-26

- **Escopo do Rogen**: adotar o CLI real (instalação via Rokit ou npm, config
  própria, integração com Rojo/Argon existentes), não só copiar a convenção de
  pastas manualmente. Motivo: usuário quer auto-routing e as outras features do
  Rogen (env tags, multi-place), não só a organização visual.
- **Ordem de execução**: infra `.claude/` (agents/rules/skills/agents-memory)
  primeiro, mudanças no framework (componentes, logger, migração Rogen) depois,
  usando essa infra já montada. Motivo: usuário quer que agentes futuros tenham
  contexto do projeto sem precisar re-explorar do zero a cada tarefa.
- **Escopo do refino de componentes/logger**: usuário não tinha pontos
  específicos em mente — eu faço a auditoria (Accessor/Mutator/Others,
  `SuperbulletServerLogger`/`SuperbulletClientLogger`) e proponho os pontos de
  melhoria antes de mexer em qualquer código. Já identificado na leitura inicial
  (ver [[logger-system]]): os dois arquivos principais do logger passam da
  regra das 300 linhas do próprio framework.
- **Refino de componentes/logger aplicado**: usuário pediu "tudo" (altos +
  médios + baixos) da auditoria — ver [[audit-findings-fase2]] pro detalhe de
  cada item e status.
- **Bug do `StarterPlayer` sem `$path`** (achado durante o planejamento da
  migração Rogen — `src/StarterPlayer/**` nunca sincronizava pro Studio):
  usuário decidiu não corrigir separado, deixar o `default.project.json`
  gerado pela migração Rogen já nascer correto (e nasceu — ver
  [[rogen-migration-notes]]).
- **Templates (`TemplateService`/`TemplateController`)**: usuário decidiu
  tirar de `framework/src/` na migração Rogen, viraram referência estática em
  `framework/documentations/templates/` (nunca rodavam de verdade mesmo).
- **`ScriptsLoader/ComponentsInitializer.lua`** (código morto confirmado):
  usuário decidiu apagar na migração, não manter por precaução.
- **Instalação do Rogen**: usuário decidiu via Rokit, mantendo `foreman.toml`
  existente intacto (não migrou selene/wally/luau-lsp/remodel/luau-analyze
  pra Rokit) — `framework/rokit.toml` novo só com `rogen` + `rojo`.
- **Migração Rogen concluída**: estrutura feature-based no ar
  (`Bootstrap`/`Profile`/`SuperbulletLogger`), validada com `rogen build` real
  + inspeção do `default.project.json` gerado + `selene` sem erro. Sync real
  no Studio (`rojo serve` + abrir o `.rbxl`) ainda precisa ser confirmado pelo
  usuário — sem acesso a Roblox Studio nesta sessão.

## 2026-08-26 (sessão UI + publish do fork)

- **Vide + UI Labs integrados**: usuário analisou dois projetos próprios
  (Frozen_Faithless, PLANE) e decidiu trazer Vide (UI reativa) + padrão UI
  Labs (storybook de Studio, não é dependência Wally) pro framework. Feature
  nova `Interface/client/`. Decisões de nome confirmadas com o usuário:
  subpasta de componentes chama `Elements/` (não `Components/`, pra não
  colidir em vocabulário com o `Components/` do padrão Accessor/Mutator do
  Knit), componente de exemplo é barra de progresso, `vide` fixado com caret
  (`^0.4.1`, consistente com Knit/Signal no `wally.toml`).
- **Sistema de "componente" tag-bound (CollectionService + mixin) discutido,
  NÃO implementado ainda**: usuário curte o padrão usado no Modux (Frozen_
  Faithless/PLANE) de classe isolada por comportamento ligada por Tag, trait
  compartilhado via Mixin central. Recomendação dada: não portar o motor
  Modux inteiro (Container/Composition próprios, resolução cíclica de mixin
  — é a "mágica de framework" que a regra do projeto evita); usar
  `sleitnick/component` (mesmo autor do Knit, `github.com/Sleitnick/RbxUtil`,
  ainda mantido em 2026) + convenção simples de mixin sem engine de
  composição. Planejamento formal desse sistema ainda não começou.
- **`wally install` apagou o fork Superbullet do working tree** (achado, não
  intencional): `wally.toml` sempre declarou `Knit = "sleitnick/knit@^1.7.0"`
  mesmo com o fork vendorizado à mão rodando de verdade em
  `Packages/_Index/superbullet_knit@0.0.1/` — nunca foi gerenciado pelo Wally
  de fato. Rodar `wally install` (pra baixar o `vide` novo) resolveu a
  declaração literal, baixou Knit vanilla e sobrescreveu `Packages/Knit.lua`
  + `_Index/`, apagando o fork (não commitado, restaurado via
  `git checkout --`).
- **Fork Superbullet publicado como pacote Wally real**, corrigindo a causa
  raiz do problema acima: `victorcarmo2003/superbullet-knit` (repo
  `github.com/victorcarmo2003/superbullet-knit`, público, MIT — copyright
  original do Sleitnick preservado + nota de modificação). `framework/
  wally.toml` não declara mais `Knit` nenhum, só `Superbullet =
  "victorcarmo2003/superbullet-knit@0.1.1"` — não existe mais entrada que
  resolve pra Knit vanilla por engano. Achado técnico: o scope do pacote no
  Wally **tem que bater com a conta GitHub autenticada** no `wally login`
  (testado: `hakor` deu 401 mesmo sem estar reservado por ninguém; publicar
  como `victorcarmo2003` — a conta usada de fato — funcionou). Achado
  estrutural: pacote publicado de verdade ganha uma pasta wrapper extra
  (`_Index/<scope>_<nome>@<versão>/<nome>/`) que o vendor à mão não tinha —
  precisou de `init.lua` raiz novo + ajuste de profundidade de `script.Parent`
  em `Comm.lua`/`Promise.lua` internos (fixado na v0.1.1, testado em pasta
  isolada antes de aplicar no framework real).
- **`Packages/Loadstring/` movido pra `src/SuperbulletLogger/shared/`**, não
  publicado no Wally: mesma classe de problema do fork (vendor à mão que
  `wally install` sempre vai apagar de novo, achado só depois de restaurar o
  fork). Decisão: **não publicar publicamente** — é uma reimplementação de
  `loadstring` pra Roblox (Yueliang + Rerubi/LBI, atribuído no próprio código
  ao projeto Adonis), ferramenta dual-use sensível o suficiente pra não valer
  a pena expor genérica num índice público só pra evitar um passo manual.
  Movido pra dentro de `src/` (fora do `Packages/`, então nenhum `wally
  install` futuro toca nele de novo) — requires em `ClientCodeExecutor.lua`/
  `CodeExecutor.lua` atualizados de `Packages.Loadstring` pra
  `SuperbulletLogger.Loadstring`. Precisou excluir esse caminho do
  `selene.toml` (`exclude = [...]`) porque o código vendorizado nunca foi
  escrito pros padrões de lint do projeto e nunca tinha sido lintado antes
  (ficava fora de `src/`).
- Testado em Studio de verdade pelo usuário depois de tudo: `Superbullet
  Server/Client initiated`, `SuperbulletLogger` client+server ok,
  `ProfileService`/`ProfileStore` ok — sem erro relacionado a nenhuma dessas
  mudanças.
