# Datastore (ProfileService/ProfileStore) — resumo operacional

Guia completo com exemplos:
`framework/documentations/codebase/DataStore-Guide.md`. Este arquivo é só o
resumo que um agente precisa para não errar o básico.

## Os três arquivos (feature `Profile`)

- Schema: `framework/src/Profile/shared/ProfileTemplate.lua`
- Server: `framework/src/Profile/server/ProfileService/init.lua` (Service,
  leitura em `Components/Accessor.lua`, escrita em `Components/Mutator.lua`)
- Client: `framework/src/Profile/client/DataController.lua` (Controller)

## Regras obrigatórias

1. **Nunca** mutar `profile.Data` diretamente. Sempre
   `ProfileService:ChangeData(player, redirectories, newValue)`.
   `redirectories` é um array de chaves até o campo:
   `{"Settings", "MusicVolume"}` = `data.Settings.MusicVolume`.
2. Ao modificar uma tabela (array/dicionário) dentro de `Data`, criar uma
   referência nova (`table.clone(data.Inventory)` + `table.insert` na cópia,
   depois `ChangeData`). Modificação in-place não é detectada.
3. Adicionar campo novo sempre em `ProfileTemplate.lua` primeiro —
   `Profile:Reconcile()` preenche o campo em perfis existentes automaticamente.
4. Client é **read-only**: lê via `DataController:GetPlayerData()`, nunca escreve
   direto. Mudança sempre via RemoteEvent que o server valida (ver `security.md`).
5. Sempre checar `profile`/`data` não-nil antes de usar — perfil pode não estar
   carregado ainda. Usar `ProfileService:WaitUntilProfileLoaded(player)` /
   `DataController:WaitUntilProfileLoaded()` quando precisar garantir que carregou.
