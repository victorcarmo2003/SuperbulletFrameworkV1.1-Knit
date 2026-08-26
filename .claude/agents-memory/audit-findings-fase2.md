---
name: audit-findings-fase2
description: Achados da auditoria de componentes (ProfileService/DataController) e logger, fase 2 do roadmap, com status de cada um
metadata:
  type: project
---

Auditoria feita em 2026-08-26, cobrindo `ProfileService.lua`, `DataController.lua`
(os dois sistemas reais fora dos templates), `TemplateController`/`TemplateService`
Components (stubs), e os 6 arquivos do sistema de logger (ver [[logger-system]]
para o contrato de protocolo, este arquivo é sobre qualidade/bugs).

Usuário decidiu (2026-08-26): corrigir tudo (altos+médios+baixos) nesta leva.

## Alto — bugs reais

1. **FIXED** — `DataController.lua` agora conecta `UpdateSpecificData` antes
   de `RequestToUpdateData()`/`WaitUntilProfileLoaded()`, e updates que
   chegarem antes do primeiro load ficam numa fila (`pendingUpdates`)
   reaplicada quando `GetData` responde, em vez de descartados. Fila foi
   adicionada depois de o `superbullet-architecture-reviewer` apontar que só
   trocar a ordem do `Connect` não fechava a race (updates entre join e o
   round-trip de `GetData` ainda podiam ser perdidos).
2. **FIXED** — `WaitUntilProfileLoaded` em `ProfileService/init.lua` e em
   `DataController.lua` agora tem timeout (default 30s), loga `warn` e
   retorna `false` em vez de travar pra sempre.

## Médio — inconsistência com o padrão documentado

3. **FIXED** — `ProfileService`/`DataController` migrados para
   `Superbullet.CreateService`/`Superbullet.CreateController`.
4. **FIXED** — `ProfileService` virou pasta
   (`ServerSource/Server/ProfileService/init.lua` +
   `Components/{Accessor,Mutator}.lua`). Leitura (`GetProfile`,
   `GetOtherPlayer_ProfileData`, `GetProfileAge`) em `Accessor.lua`, escrita
   (`ChangeData`) em `Mutator.lua`. `ProfileService:GetProfile()`/`:ChangeData()`
   continuam existindo no `init.lua` como delegados, pra não quebrar quem já
   chama essa API (documentada em `DataStore-Guide.md`). Componentes pegam a
   referência do parent via `Superbullet.GetService("ProfileService")` em
   `Init()` (idioma do framework, não `require(script.Parent.Parent)` —
   funcionava mas era inconsistente, trocado após revisão).
5. **FIXED** — `init.server.lua` (423→176) e `init.client.lua` (303→89)
   quebrados em módulos por responsabilidade (`RemoteConfig`,
   `HttpAvailability`, `LogBuffer`, `BackendTransport` no server;
   `HttpDisabledUI` no client). Validado pelo `superbullet-logger-maintainer`
   — contrato de protocolo (nomes de Remote, payloads, endpoints) confirmado
   idêntico ponto a ponto. Detalhe atualizado em [[logger-system]].
6. **FIXED** — UI extraída pra `HttpDisabledUI.lua` (215 linhas, só
   construção de UI), `init.client.lua` ficou só orquestrador.

## Baixo — estilo

7. **FIXED** — variável morta `local plr = game.Players.LocalPlayer` removida
   do `DataController.lua`.
8. **FIXED** — casing unificado em `redirectories` (minúsculo) nos dois lados.
9. **FIXED** — lógica de compile+pcall+captura de output unificada em
   `ReplicatedStorage/SharedSource/Utilities/SuperbulletLoggerShared/CodeExecutorCore.lua`
   (`CodeExecutorCore.Run(loadstringFn, code)`), usada pelos dois lados. Cada
   lado continua formatando sua própria resposta externa (server envolve em
   `data={...}`, client mantém flat) — só a parte idêntica foi deduplicada.
   Também deduplicado `getLogLevel` em
   `SuperbulletLoggerShared/LogLevel.lua` (achado que surgiu na hora do
   refino, não estava no item 9 original mas era a mesma categoria de
   problema).

## Achado novo (fora do escopo combinado, só registrado — não corrigido)

10. `ProfileService.Client:GetOtherPlayer_ProfileData` (hoje em
    `Components/Accessor.lua`) devolve o `profileData` inteiro de qualquer
    jogador pra qualquer client que chamar o RemoteFunction, sem filtrar
    campos sensíveis — viola o item 3 do checklist de
    `.claude/rules/security.md`. Bug pré-existente no arquivo flat original,
    só ficou mais visível na reescrita (achado pelo
    `superbullet-architecture-reviewer` em 2026-08-26). Não foi corrigido
    porque é decisão de produto (quais campos são "públicos" pra
    leaderboard/trade varia por jogo) — perguntar ao usuário antes de mexer.
