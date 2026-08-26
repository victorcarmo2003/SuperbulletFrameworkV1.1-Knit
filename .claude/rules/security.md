# Segurança — regras obrigatórias para Remotes

Se roda no client, um exploiter consegue ler e modificar. Não existe exceção.

## Nunca confiar em valor numérico vindo do client

```lua
-- PROIBIDO: client manda o valor
PointsService.AddPoints:Fire(player, 99999) -- exploitável

-- CORRETO: client pede uma ação, server calcula o valor
QuestService.CompleteQuest:Fire(player, questId)
```

## Remotes baseados em ação, nunca em valor

```lua
CombatService.AttackTarget:Fire(targetId)
QuestService.TurnInQuest:Fire(questId)
ShopService.PurchaseItem:Fire(itemId)
```

## Servidor sempre valida e calcula

```lua
function ShopService:PurchaseItem(player, itemId)
    local item = GameData.Items[itemId]
    if not item then return false end
    if player.Currency.Value < item.Price then return false end
    -- prossegue com a compra...
end
```

## Checklist ao revisar/escrever um RemoteEvent/RemoteFunction

- O parâmetro vindo do client é um valor (quantidade, dinheiro, XP)? Se sim,
  reescrever para o client mandar só a intenção/ID e o server calcular o valor.
- Toda validação (tem o item, tem saldo, cooldown, alcance) acontece no server,
  nunca só no client.
- Dados sensíveis de outros jogadores não vazam via resposta de RemoteFunction
  sem necessidade.

Referência completa com mais exemplos:
`framework/documentations/codebase/organizing-project-structure.md` (seção 13).
