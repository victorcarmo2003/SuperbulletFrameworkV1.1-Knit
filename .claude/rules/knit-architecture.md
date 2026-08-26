# Arquitetura de componentes (Knit modificado / Superbullet)

Regras obrigatórias para qualquer Service ou Controller criado com
`Superbullet.CreateService` / `Superbullet.CreateController`
(`framework/src/ReplicatedStorage/Packages/Superbullet.lua`).

## Estrutura de um sistema

```
NomeService/
├── init.lua                 << arquivo principal, Instance = script
└── Components/
    ├── Accessor.lua         << operações de leitura
    ├── Mutator.lua          << operações de escrita
    └── Others/
        └── AlgumaCoisa.lua  << componentes especializados
```

Templates de referência prontos para copiar:
`framework/documentations/templates/TemplateController/` e
`framework/documentations/templates/TemplateService/`. Ficam fora de
`framework/src/` de propósito (nunca rodam, são só esqueleto) — copiar pra
dentro de `src/{Feature}/client/` ou `src/{Feature}/server/` ao criar um
sistema novo.

`Instance = script` no `init.lua` é obrigatório para o autoload funcionar. Quem
carrega os componentes é `Components.ComponentInitializer` **dentro do pacote
Wally** `Packages/_Index/superbullet_knit@0.0.1/knit/Components/ComponentInitializer.lua`
— chamado automaticamente por `KnitServer`/`KnitClient` pra todo serviço/controller
que tenha `Instance` setado. Sem `Instance = script`, os componentes nunca são
carregados.

**Atenção:** existe também um arquivo
`framework/src/ReplicatedStorage/SharedSource/Utilities/ScriptsLoader/ComponentsInitializer.lua`
com nome parecido — esse é **código morto**, não é `require`-ado por nada no
repo (confirmado por grep). Não é ele quem faz o autoload. Não editar esperando
efeito no autoload real.

### O que o `ComponentInitializer.Initialize` real faz (importante — não é merge de métodos)

- `Service.Accessor = require(Components/Accessor.lua)` — expõe o **módulo
  inteiro** como propriedade `Accessor` do service/controller. Alias de
  retrocompat: `Service.GetComponent` aponta pro mesmo módulo.
- `Service.Mutator = require(Components/Mutator.lua)` — idem, alias
  `Service.SetComponent`.
- `Service.Components[NomeDoArquivo] = require(...)` para cada `ModuleScript`
  dentro de `Components/Others/` (achatado, mesmo se estiver em subpasta).
- Chama `.Init()` de **todo** módulo dentro de `Components/` (Accessor, Mutator,
  Others), **sem passar `self`/argumento nenhum** — os componentes usam dot
  syntax (`module.FunctionName()`), não colon syntax, exceto quando o próprio
  módulo implementa seu próprio objeto OOP com `.new()`.
- Não existe merge automático de método individual no service (ex.: chamar
  `Service:GetPlayerLevel()` direto não funciona só por existir em
  `Accessor.lua`). Pra chamar, é sempre via `Service.Accessor.GetPlayerLevel(player)`
  (de dentro do `init.lua`) ou, como qualquer outro sistema também enxerga essa
  propriedade, `OutroSistema.Accessor.Algo(...)` também é tecnicamente possível
  — a matriz de comunicação abaixo é **convenção de arquitetura obrigatória**,
  não uma restrição técnica do framework. Nada no `ComponentInitializer` impede
  um módulo de dar `require` direto em outro; a disciplina é responsabilidade
  de quem escreve o código.

## Aliases legados (manter funcionando, não usar em código novo)

`Get().lua` e `Set().lua` ainda funcionam como aliases de `Accessor.lua` e
`Mutator.lua` por retrocompatibilidade. Código novo usa sempre `Accessor.lua`/
`Mutator.lua`.

## Matriz de comunicação (obrigatória)

| De \ Para        | Accessor          | Mutator            | Others (mesmo sistema) | Outros sistemas |
|-------------------|--------------------|---------------------|--------------------------|-------------------|
| Accessor.lua      | —                  | ❌ PROIBIDO         | ✅                       | ✅                |
| Mutator.lua       | ❌ PROIBIDO         | —                  | ✅                       | ✅                |
| Others/*.lua      | ❌ só via parent    | ❌ só via parent     | ❌ só via parent          | ❌ só via parent   |
| init.lua (parent) | ✅                  | ✅                  | ✅                       | ✅                |

- Accessor e Mutator **nunca** se `require`-am um ao outro. Coordenação sempre
  passa pelo `init.lua` do sistema.
- `Others/*.lua` só fala com o sistema pai (`init.lua`). Não chama outro sistema
  nem outro `Others/` diretamente, nem mesmo do mesmo sistema.

## Ciclo de vida — regra de ouro: Init nunca faz yield

- `:SuperbulletInit()` / `:KnitInit()` (e `.Init()` de componente) **não podem**
  chamar `WaitForChild`, `:await()`, `task.wait()` ou qualquer coisa que bloqueie.
  Init trava o startup inteiro do Knit/Superbullet se yieldar.
- Init serve só para: `Knit.GetService()` / `Knit.GetController()`, guardar
  referências síncronas, `Knit.RegisterClient*`.
- Trabalho assíncrono (esperar assets, conectar eventos, I/O) vai em
  `:SuperbulletStart()` / `:KnitStart()` (ou `.Start()` do componente), envolto em
  `task.spawn()`.

## Regra das 300 linhas

- Acima de ~300 linhas num `init.lua`, quebrar em Accessor/Mutator/Others.
- Abaixo de ~100 linhas ou CRUD simples: **não** criar Accessor/Mutator/Others,
  é overhead desnecessário — tudo direto no `init.lua`.
- Lógica fortemente acoplada (sempre muda junto) não deve ser separada só para
  seguir a regra.

## Agrupamento de sistemas em pastas

Com 3+ serviços/controllers relacionados, agrupar em subpasta temática
(`Server/Combat/{DamageService,WeaponService,HealthService}`). Projetos pequenos
(menos de 3 sistemas relacionados) não precisam desse agrupamento.

Referência completa (com exemplos de código):
`framework/documentations/codebase/organizing-project-structure.md`.
