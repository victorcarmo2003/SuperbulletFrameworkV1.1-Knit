---
name: logger-system
description: O que o SuperbulletServerLogger/SuperbulletClientLogger fazem, contrato de protocolo, tamanhos atuais dos arquivos
metadata:
  type: reference
---

Ponte de debug **só ativa em Roblox Studio** (`RunService:IsStudio()`), conecta
o playtest ao app desktop SuperbulletAI. Preservar o contrato de protocolo
abaixo é obrigatório ao mexer nesses arquivos — quebrar isso quebra a integração
com o app, não só o jogo.

## Lado servidor — `framework/src/SuperbulletLogger/server/`

**Refatorado em 2026-08-26**: `init.server.lua` e `CodeExecutor.lua` foram
quebrados em módulos menores; comportamento externo validado como idêntico
(ver seção "Contrato de protocolo" abaixo — confirmado ponto a ponto).
**Movido em 2026-08-26** (migração Rogen) de
`ServerScriptService/SuperbulletServerLogger/` pra
`src/SuperbulletLogger/server/` (feature-based) — mesmos arquivos, só o
caminho mudou.

| Arquivo | Linhas | Papel |
|---|---|---|
| `init.server.lua` | 176 | orquestra tudo abaixo (era 423) |
| `RemoteConfig.lua` | 44 | lê config de `ServerStorage.Superbullet.Superbullet_Server`, monta URLs de endpoint (`GetConfig`, `GetEndpointUrl`) |
| `HttpAvailability.lua` | 73 | checa `HttpService` habilitado + notifica client via `SuperbulletHttpDisabled` (`CheckAndNotify`), checa se backend responde (`IsBackendReachable`) |
| `LogBuffer.lua` | 85 | buffer de logs em memória (`Add`/`DrainUpTo`/`IsEmpty`), trim de overflow (`MAX_BATCH_SIZE = 100`, buffer máx = 200) |
| `BackendTransport.lua` | 59 | `POST` de logs e lifecycle (`SendLogs`/`NotifyPlaytestStart`/`NotifyPlaytestStop`) |
| `WebSocketClient.lua` | 155 | conexão WS pro backend (não tocado no refino) |
| `CodeExecutor.lua` | 97 | executa `run_lua_code` recebido via WS, contexto server; usa o núcleo compartilhado `CodeExecutorCore` (ver seção Shared), mantém caso especial `isEndTestCode` fora do núcleo (precisa de execução adiada) |
| `ClientQueryRouter.lua` | 110 | roteia `run_lua_code` de contexto client pro client certo (não tocado no refino) |

### O que `init.server.lua` faz, em ordem

1. Lê config em `ServerStorage.Superbullet.Superbullet_Server`
   (`ConnectionMode`: `"localhost"` ou `"cloud"`; `Port`, padrão `13528`;
   `CloudToken`) via `RemoteConfig.GetConfig()`.
2. Cria `ReplicatedStorage.SuperbulletClientLog` (RemoteEvent, client → server),
   `ReplicatedStorage.SuperbulletHttpDisabled` (RemoteEvent, server → client) e
   `ReplicatedStorage.SuperbulletClientQuery` (RemoteFunction, pra executar
   código no contexto do client a pedido do server) — sempre antes de checar
   HttpAvailability, pra o client já ter os Remotes disponíveis quando o
   server decidir avisar do HttpService desabilitado.
3. Checa se `HttpService` está habilitado via `HttpAvailability.CheckAndNotify`;
   se não, avisa o(s) client(s) via `SuperbulletHttpDisabled` e para (sem
   logging).
4. Bufferiza `LogService.MessageOut` (server) e o conteúdo recebido via
   `SuperbulletClientLog` (client) num `LogBuffer`, em lotes (`BATCH_INTERVAL =
   1s`, `LogBuffer.MAX_BATCH_SIZE = 100`, buffer máx 200), envia por
   `BackendTransport.SendLogs` → `HttpService:PostAsync` pra
   `http://localhost:{port}/playtest/logs` (local) ou
   `https://superbullet-backend-3948693.superbulletstudios.com/api/superbullet/playtest/logs?token=...`
   (cloud).
5. Abre WebSocket (`WebSocketClient.lua`) pro backend pra receber
   `run_lua_code` sob demanda — detecta contexto client vs server (campo
   `context`, ou prefixo `--@client` no código, lógica ainda inline em
   `init.server.lua`) e roteia pra `CodeExecutor` (server) ou
   `ClientQueryRouter` (client via `SuperbulletClientQuery`).
6. Notifica `/playtest/start` no boot (`BackendTransport.NotifyPlaytestStart`)
   e `/playtest/stop` (+ flush final do buffer via `BackendTransport.SendLogs`)
   em `game:BindToClose`.

## Lado client — `framework/src/SuperbulletLogger/client/`

**Refatorado em 2026-08-26** junto com o lado servidor. **Movido em
2026-08-26** (migração Rogen) de
`StarterPlayer/StarterPlayerScripts/SuperbulletClientLogger/` pra
`src/SuperbulletLogger/client/`.

| Arquivo | Linhas | Papel |
|---|---|---|
| `init.client.lua` | 89 | orquestra (era 303) |
| `HttpDisabledUI.lua` | 215 | UI inteira de aviso (`ScreenGui`) quando `HttpService` está desabilitado, via `HttpDisabledUI.Create()` (renomeada de `createHttpDisabledUI`, mesmo desenho/textos) |
| `ClientCodeExecutor.lua` | 51 | executa código recebido via `SuperbulletClientQuery`, usa o núcleo compartilhado `CodeExecutorCore` |

1. Se recebe `SuperbulletHttpDisabled`, chama `HttpDisabledUI.Create()`.
2. Escuta `LogService.MessageOut` local, manda pro server via
   `SuperbulletClientLog` com rate limit de 10 logs/segundo.
3. Escuta `SuperbulletClientQuery.OnClientInvoke`, delega pra
   `ClientCodeExecutor.execute(code)`.

## Compartilhado — `framework/src/SuperbulletLogger/shared/`

Novo desde o refino de 2026-08-26. **Movido em 2026-08-26** (migração Rogen)
de `ReplicatedStorage/SharedSource/Utilities/SuperbulletLoggerShared/` pra
`src/SuperbulletLogger/shared/` — a pasta `shared/` dentro da feature já roda
pra `ReplicatedStorage` automaticamente (nome de pasta = roteamento, ver
[[rogen-migration-notes]]), sem precisar de `$path` manual. Requires viraram
mais curtos: `ReplicatedStorage.SuperbulletLogger.LogLevel`/
`.CodeExecutorCore` em vez do caminho antigo de 4 níveis.

| Arquivo | Linhas | Papel |
|---|---|---|
| `LogLevel.lua` | 20 | `LogLevel.FromMessageType(messageType)` — mapeamento `Enum.MessageType` → string de nível (`"error"/"warning"/"info"/"debug"`), antes duplicado idêntico nos dois `init.*.lua` |
| `CodeExecutorCore.lua` | 53 | `CodeExecutorCore.Run(loadstringFn, code)` → `(success, output, executionTimeMs, errorMessage)`. Compila via `loadstringFn`, roda em `pcall`, captura `print()` via `LogService.MessageOut` (só `Enum.MessageType.MessageOutput`) e concatena com o valor de retorno (prints primeiro, valor de retorno por último, separados por `\n`). **Não** decide o formato de resposta externo — cada lado (`CodeExecutor.lua` server / `ClientCodeExecutor.lua` client) embrulha esse retorno no seu próprio formato (ver contrato abaixo) |

Cuidado ao mexer aqui: qualquer mudança nesse núcleo afeta os dois lados ao
mesmo tempo (é o ponto todo de existir). Se precisar de comportamento
diferente entre server/client, isso pertence ao `CodeExecutor.lua`/
`ClientCodeExecutor.lua` de cada lado, não ao núcleo compartilhado.

## Contrato de protocolo (não quebrar sem atualizar os dois lados)

- RemoteEvent `SuperbulletClientLog` (client→server): `{level, message,
  traceback}`.
- RemoteEvent `SuperbulletHttpDisabled` (server→client): sem payload, só
  dispara a UI.
- RemoteFunction `SuperbulletClientQuery` (server→client, invoke):
  `{code: string, context?}` → `{success, ...}` (formato de retorno definido em
  `ClientCodeExecutor.execute`).
- HTTP: `POST {base}/playtest/start|stop|logs`, `GET {base}/health`. `base` é
  `http://localhost:{port}` ou o backend cloud + `?token=`.
- WS: `ws://localhost:{port}/ws` (localhost) ou endpoint cloud com token;
  mensagem de entrada `{type: "run_lua_code", requestId, code, context?}`,
  resposta `{type: "run_lua_code_response", requestId, result, timestamp}`.
  `result` é `CodeExecutor.execute(requestId, code)` (contexto server) ou
  `ClientQueryRouter:execute(code, requestId)` (contexto client) — os dois
  retornam o mesmo formato `{success, data: {output, executionTime}}` /
  `{success = false, error}`. `ClientQueryRouter` embrulha nesse formato o
  retorno flat `{success, output, executionTime}` de
  `ClientCodeExecutor.execute` (que é o formato de retorno de
  `SuperbulletClientQuery` em si — ver acima).
