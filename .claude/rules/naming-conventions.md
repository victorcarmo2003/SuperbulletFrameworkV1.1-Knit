# Convenções de nomenclatura

- Services (server) terminam em `Service`: `ProfileService`, `TemplateService`.
- Controllers (client) terminam em `Controller`: `DataController`,
  `TemplateController`.
- Componentes de leitura: `Accessor.lua` (código novo). `Get().lua` só existe por
  retrocompatibilidade — não criar novos.
- Componentes de escrita: `Mutator.lua` (código novo). `Set().lua` idem, legado.
- Componentes especializados adicionais: dentro de `Others/`, nome descreve a
  responsabilidade (`DataValidator.lua`, `DamageCalculator.lua`), sem sufixo fixo.
- Ao criar um sistema novo, copiar a estrutura de
  `framework/documentations/templates/TemplateController/` (Controller) ou
  `framework/documentations/templates/TemplateService/` (Service) em vez de
  escrever do zero. Esses templates ficam fora de `framework/src/` de
  propósito (nunca rodam, são só esqueleto de referência) — ver
  `.claude/rules/tooling.md` sobre a estrutura feature-based.
- RemoteEvents/RemoteFunctions: nome de ação, verbo no imperativo
  (`AttackTarget`, `PurchaseItem`, `TurnInQuest`) — nunca nome de valor
  (`SetPoints`, `AddCoins` vindo do client). Ver `security.md`.
