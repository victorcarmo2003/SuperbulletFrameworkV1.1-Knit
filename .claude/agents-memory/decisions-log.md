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
