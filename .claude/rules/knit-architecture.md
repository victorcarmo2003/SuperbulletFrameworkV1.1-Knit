# Arquitetura de componentes (Knit modificado / Superbullet)

Regras obrigatórias para qualquer Service ou Controller criado com
`Superbullet.CreateService` / `Superbullet.CreateController`
(`framework/Packages/Superbullet.lua` — hoje um único `require` que reexporta
o pacote Wally externo publicado `victorcarmo2003/superbullet-knit`, não mais
vendor local; ver `.claude/agents-memory/knit-component-pattern.md`, seção
"Wrapper Superbullet sobre Knit").

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
Wally publicado** (`Packages/_Index/victorcarmo2003_superbullet-knit@<versão>/
superbullet-knit/knit/Components/ComponentInitializer.lua`) — chamado
automaticamente por `KnitServer`/`KnitClient` pra todo serviço/controller que
tenha `Instance` setado. Sem `Instance = script`, os componentes nunca são
carregados. **O caminho muda a cada bump de versão** (a versão vira parte do
nome da pasta) — conferir `framework/wally.toml` pela versão atual antes de
assumir esse caminho literal.

### Uso correto: `Service.Accessor.Foo(...)`, nunca merge de método

Chamar algo de um componente é sempre via dot syntax explícito
(`Service.Accessor.GetPlayerLevel(player)`, `Service.Mutator.SetX(...)`) —
nunca `Service:Foo()` direto esperando merge automático de método individual
no service. `.Init()`/`.Start()` de cada componente (Accessor, Mutator,
Others) é chamado sem receber `self`/argumento nenhum. A matriz de
comunicação abaixo é **convenção de arquitetura obrigatória**, não uma
restrição técnica — nada impede tecnicamente um `require` direto fora dela,
a disciplina é responsabilidade de quem escreve o código. Ver
`.claude/agents-memory/knit-component-pattern.md` (seção "Wrapper
Superbullet sobre Knit") pro mecanismo interno completo do
`ComponentInitializer`, incluindo path do pacote publicado.

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
- Verificado estaticamente por `framework/scripts/check-architecture.luau` (ver
  `.claude/rules/tooling.md`) — falha com exit code não-zero se um `require()`
  violar a matriz.

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
