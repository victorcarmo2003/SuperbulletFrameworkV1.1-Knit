# Lync — Guia de Referência e Integração

> **Fonte:** clone de `https://github.com/Axp3cter/Lync` em `lync-temporary/`
> (raiz do repositório), commit `91b28bea91b32e556b963b83b6e38cd7b30c46b5`,
> versão de pacote `3.0.8` (`wally.toml`/`package.json`). Esta é uma reescrita
> completa do Lync — não tem relação de código com versões anteriores da
> biblioteca que o time possa ter visto antes; todo este documento descreve
> só o que está em `lync-temporary/src/`.
>
> Este guia existe para preparar a integração do Lync como camada de
> networking do SuperbulletFrameworkV1-Knit. A seção final,
> [Integração com o SuperbulletFramework](#integração-com-o-superbulletframeworkv1-knit),
> é a que importa para decisões de arquitetura; as seções anteriores são
> referência técnica de como o Lync funciona por dentro, necessária para
> tomar essas decisões com segurança (ex.: por que um `query` nunca pode
> ter campo `:monotonic()`, ou o que acontece de fato quando o budget de
> replicação estoura).

---

## 1. Visão geral

Lync é uma biblioteca de networking tipada para Roblox: o schema é escrito
**uma vez**, em um módulo `require`-ado pelos dois lados (server e client), e
tanto os tipos Luau quanto o formato de wire (bit-level, empacotado em
`buffer`) derivam inteiramente dele. Não há passo de geração de código
separado nem arquivo `.rbxmx` a sincronizar manualmente.

```lua
-- Net.luau, required pelos dois lados
return Lync.define("arena", {
    Fighters = Lync.replicate(Lync.struct({
        name  = Lync.str(1, 20),
        team  = Lync.enum({ "red", "blue" }),
        score = Lync.int(0, 1000000):monotonic(),
        pos   = Lync.vec3(Lync.quant(-512, 512, 0.1)):newest(10),
    })):keyBy("team"),

    Strike = Lync.packet(Lync.vec3(Lync.quant(-512, 512, 0.1))):unreliable(),

    Sell = Lync.query(
        Lync.struct({ item = Lync.enum({ "sword", "shield" }) }),
        Lync.struct({ earned = Lync.int(0, 1000000) })
    ),
})
```

Três tipos de definição existem dentro de um namespace:

| Tipo | Carrega | Enviar | Receber |
| --- | --- | --- | --- |
| `packet` | eventos | `fireServer` `fireClient` | `onServer` `onClient` |
| `query` | um pedido e sua resposta | `request` | `onServer` `onClient` |
| `replicate` (Set) | registros do servidor, replicados incrementalmente | `add` `update` `remove` `clear` | `onAdded` `onChanged` `onRemoved` |

Um `Codec` (`Lync.int`, `Lync.struct`, etc.) descreve **um valor**: como ele
valida, quantos bits ocupa no wire, como codifica e decodifica. Nada em um
codec sabe sobre packets/queries/sets — essa composição acontece na camada
de cima (`Lync.packet(codec)`, `Lync.replicate(codec)`, ...).

### Pipeline interno (para quem for depurar)

```
Lync.define(name, defs)          -- registra o namespace (src/api/Define.luau)
        |
Lync.start()                     -- sela definições, compila TODOS os namespaces,
        |                           abre RemoteEvents, faz handshake
        v
Compile.build (shape/Compile.luau)
        |
   Legality.definition             -- valida a árvore inteira (64 campos, markers,
        |                             precisão vs. double, cap de unreliable...)
        v
   Lower.of (shape/Lower.luau)     -- decide layout de bits: quem cabe numa
        |                             região compartilhada, quem vira campo
        |                             byte-alinhado próprio
        v
   Emit.emit (shape/emit/*.luau)   -- produz closures Luau de encode/decode
        |                             (upvalues fixados, NÃO gera texto/loadstring)
        v
   Shape.Built { write, read, maxBytes, grid, marker, ... }
```

Todo o trabalho de "descobrir onde cada campo cai em bits" acontece **uma
vez**, dentro de `Lync.start()` — depois disso, `fireServer`/`add`/`request`
só executam as closures já compiladas.

---

## 2. Ciclo de vida do namespace

| Função | Efeito |
| --- | --- |
| `Lync.define(name, defs)` | Registra um namespace. Proibido depois de `start()` (throw). Nome duplicado, campo inválido (não é packet/query/set), ou o mesmo handle de definição reusado em duas `define` — todos throw. |
| `Lync.start()` | Roda **uma vez por lado, no processo inteiro** (não uma vez por namespace) — uma segunda chamada é throw (`"start has already run, and a place starts once"`). Sela `Define`, compila cada namespace (`Compile.build`/`Legality.definition` — é aqui que o limite de 64 campos e as demais regras estruturais são checadas, não em `Lync.define`), abre o transporte, e dispara o handshake. |
| `Lync.flush(budget?)` / `Lync.flush(namespace, budget?)` | Envia tudo que foi bufferizado desde o último flush. Sem argumento, todos os namespaces com budget automático (ver §6.5). `budget < 1024` é throw (`"a flush of {N} bytes is under the floor of 1024"`). Chamar antes de `start()` é throw. Flushes vazios não custam nada. |
| `Lync.close()` | Idempotente (uma segunda chamada não é erro). Faz um flush final, resolve toda `query` pendente como `"shutdown"`, desconecta listeners internos, e por fim fecha o transporte — **sem destruir** as Instances `RemoteEvent`/`Folder`, só desconecta as `RBXScriptConnection`s. |
| `Lync.stats(name)` | Devolve um snapshot **congelado e cumulativo** (nunca reseta) — contadores de `flushes`, `sentBytes`, `receivedBytes`, `drops`, e um sub-registro por definição (`sent`, `sentBytes`, `received`, `receivedBytes`, `drops`). Duas leituras sucessivas subtraem para virar uma taxa; não existe reset embutido. |

Padrão de uso (idêntico nos dois lados):

```lua
Lync.start()
RunService.PostSimulation:Connect(Lync.flush)
```

---

## 3. Packets

```lua
Move = Lync.packet(Lync.vec3()):unreliable(),
Aim  = Lync.packet(Lync.rotation.quat(0.2)):newest(20):timestamped(),
```

- `fireServer(value)` — só pode ser chamado no client.
- `fireClient(recipient, value)` — só pode ser chamado no server. Um pacote
  disparado para ninguém (recipient resolve a lista vazia) é reportado e dá
  throw no Studio.
- `onServer(fn)` / `onClient(fn)` — aceitam **múltiplos listeners**
  independentes (diferente de Query, que só aceita um responder). Assinatura:
  `fn(value, player?, sent?)` — o terceiro argumento (`sent`, um timestamp)
  só chega não-nil se o packet foi declarado `:timestamped()`.
- Um listener que lança exceção é contido (roda isolado via `xpcall`
  numa coroutine própria) e **não impede os outros listeners** nem os outros
  itens de um lote — a exceção só vira um registro de log `"error"`.
- Um pacote decodificado sem nenhum listener registrado naquela máquina:
  em build de desenvolvimento (`__DEV__`) isso é um throw; em build shipada,
  é só um warning.

### As três lanes de entrega, mutuamente exclusivas entre si (exceto `timestamped`)

| Modificador | Comportamento |
| --- | --- |
| (padrão, nenhum) | Confiável e ordenado — via `RemoteEvent` normal. |
| `:unreliable()` | Lossy e sem ordem — via `UnreliableRemoteEvent`. Toda chamada de `fireServer`/`fireClient` ainda vai (não é coalescida). O payload mais largo do packet não pode passar de **1000 bytes** (`Protocol.UNRELIABLE_CAP`) — checado em `start()`, throw se estourar. |
| `:newest(hz?)` | Lossy, só o valor mais recente importa. Reenvio idêntico ao último valor **efetivamente enviado** não sai. Se `hz` for passado, o packet só transmite de novo depois de `1/hz` segundos desde o último envio real (não "buckets" de relógio). Vai sempre pela lane `UnreliableRemoteEvent`, com um número de sequência de 16 bits num anel (`wire/Sequence.luau`) para o lado receptor descartar mensagens fora de ordem. |
| `:timestamped()` | Empilha com qualquer uma das três acima. Adiciona o campo `sent` (um instante no clock compartilhado — ver §8) ao header do wire. Nunca é agrupado num "run" de múltiplos payloads (cada disparo vira seu próprio bloco). |

`:unreliable()` e `:newest()` juntos no mesmo packet é erro de definição
(`"declares two ways of delivering itself, unreliable and newest"`), checado
em `start()`.

### Recipients (`to` de `fireClient`, e `audience` de um Set)

| Forma | Resolve para |
| --- | --- |
| `Lync.all` | Todo client cujo handshake já terminou. |
| `Player` | Aquele client específico (se pronto). |
| `{ Player }` | A lista (deduplicada internamente). |
| `Group` | Os membros atuais do grupo (`Lync.group()`, ver §5). |
| `Lync.except(t)` | Todo mundo, exceto quem `t` (qualquer uma das formas acima, inclusive outro `Except`, recursivamente) cobrir. |

Um client cujo handshake ainda não terminou é descartado silenciosamente de
qualquer resolução — o frame nem chega a ser endereçado a ele.

---

## 4. Queries

```lua
local ok, res, data = Net.Sell:request({ item = "sword" })
if ok then print(res.earned) else print(res, data.elapsed) end
```

- **Client**: `request(value, timeout?)` — dá *yield* (via coroutine) até a
  resposta chegar, timeout vencer, ou a conexão cair.
- **Server**: `request(client, value, complete, timeout?)` — nunca dá yield;
  `complete(ok, result, data)` roda quando o outcome está pronto.
- `onServer(fn)` / `onClient(fn)` — só **um responder por Query por lado**;
  registrar um segundo é throw (`"already has a responder, and a query has
  one"`). O que o responder retornar vira a resposta.
- Timeout padrão: **10 segundos** (`Protocol.QUERY_TIMEOUT`), aplicado
  internamente pelo `Pending` — não é detectado num timer isolado, e sim
  varrido a cada `Lync.flush()` (min-heap de deadlines). Isso significa que
  o outcome `"timeout"` só chega, na prática, no próximo flush **depois**
  do deadline vencer, não no instante exato.
- **Cap de 32768 requests em flight por namespace** (`Protocol.QUERY_CAP`).
  Estourar é throw: `"{namespace} has 32768 requests in flight, which is
  the ceiling"`.

### Os 4 outcomes

| Código | Quando dispara |
| --- | --- |
| `"timeout"` | Deadline (`now + timeout`) vencido, detectado no próximo `Pending:sweep()` de um flush. |
| `"unanswered"` | O responder do lado remoto **lançou exceção**. Não é timeout — a resposta chegou, só que como uma falha contida. |
| `"leave"` | O `Player` do outro lado da conversa (quem perguntou, ou a quem se perguntou) saiu (`Players.PlayerRemoving`). |
| `"shutdown"` | `Lync.close()` rodou para aquele namespace com a query ainda pendente. |

Em todo caso de falha, `data: OutcomeData` carrega `definition` (nome) e
`elapsed` (segundos desde a abertura do request). Uma falha de domínio (ex.:
"saldo insuficiente") **não** é um outcome — é um valor normal dentro do
codec de resposta; outcomes são só sobre a mecânica de transporte.

Uma `query` internamente ocupa **dois ids adjacentes de wire** — um para o
pedido, outro para a resposta — e o `Router` decide qual é qual comparando o
id lido no frame contra o id-base da definição.

---

## 5. Sets (`Lync.replicate`) — replicação com delta

```lua
Net.Fighters:add(id, { name = "Ada", team = "red", score = 0, pos = Vector3.zero })
Net.Fighters:update(id, { score = 10 })   -- só score é enviado
```

O servidor é dono do set; cada client recebe só os registros permitidos por
sua audiência. **Sem `keyBy`, o set inteiro replica para todo mundo** — não
existe conceito de audiência restrita nesse caso, e chamar `:audience(...)`
num set sem `keyBy` é throw.

| Método (server-only) | Efeito |
| --- | --- |
| `add(id, record)` | Throw se `id` já está vivo. |
| `update(id, fields)` | Só os campos nomeados. `Lync.none` limpa um campo opcional (só aceito em campos cujo codec já era `optional` — codificado no próprio sistema de tipos). |
| `remove(id)` / `clear()` | `remove` throw em id ausente. `clear()` dispara uma marca por partição no wire (barato), mas do lado do listener ainda dispara `onRemoved` uma vez por registro. |
| `audience(key, to)` | Só em sets com `keyBy`. Migrar a chave de um registro (`update` mudando o próprio campo de `keyBy`) migra audiências **atomicamente dentro do mesmo flush** — do ponto de vista de quem só via a chave antiga, é um `onRemoved`; de quem só vê a nova, um `onAdded`; de quem via as duas, um `onChanged`. |

| Ambos os lados | Efeito |
| --- | --- |
| `get(id)` | Registro **por referência** (não copia) — copiar antes de guardar. `nil` se não existir ou não estiver visível. |
| `#set`, iteração | Contagem e walk da visão local. Ordem de iteração não é garantida. |
| `onAdded(fn)` | Dispara em: add real, late join, ganho de visibilidade — e no client, também faz **replay do estado inicial** recebido no handshake/join, então conectar `onAdded` funciona mesmo se ligado depois do `start()`. |
| `onChanged(fn)` | `fn(id, record, old)` — `old` é o valor antes do flush atual. |
| `onRemoved(fn)` | `fn(id, cause)` — `cause` é `"removed"` (remove explícito) ou `"cleared"` (via `clear()`). |

Regras de coalescing dentro de **um** flush: duas `update` no mesmo campo
mandam uma vez; `add` seguido de `remove` **não manda nada**; qualquer coisa
seguida de `remove` vira `"remove"`; um `add` só é legal depois de um
`remove` pendente do mesmo id, e nesse caso vira `"replace"` internamente
(mesmo efeito de rede que remove+add, mas contabilizado como uma operação
atômica). Do lado do receptor a mesma regra é espelhada de forma
independente: um id que chega e é removido no mesmo frame nunca dispara
nenhum callback.

### `:monotonic()` e `:newest(hz?)` em campos de Set

Esses dois modificadores são **independentes um do outro** — um campo pode
ter os dois, nenhum, ou só um:

- **`:monotonic()`** — o valor só pode crescer; uma escrita menor que o
  atual é `Log.error` (throw) em `update()`. Ainda vai pela lane confiável
  normal (delta codificado), só que o delta é mais barato de representar
  porque a direção é conhecida.
- **`:newest(hz?)`** — o campo sai da lane confiável inteiramente e vai pela
  lane "unreliable"/lossy, **fora do budget de replicação de estado**. A
  comparação de "mudou?" é feita contra o **último valor efetivamente
  transmitido** (não contra o valor anterior em memória) — então, se uma
  transmissão não coube no pacote unreliable de um flush, o próximo flush
  ainda tenta reenviar até conseguir. Vários campos `:newest()` que mudam
  no mesmo run de slots compartilham uma única seção de wire.

Um campo com marker (`monotonic`/`newest`) só é legal **diretamente** num
campo do record do set — não em algo aninhado dentro dele (`"declares
{mark} at {where}, and a set deltas its own fields"`). Packets e queries,
em contraste, **nunca** podem ter nenhum marker em lugar nenhum da árvore
— é sempre erro de definição.

### Como funciona por dentro (para depuração)

Cada Set mantém, por partição (uma partição por valor distinto de `keyBy`,
ou uma partição única `WHOLE` se não há `keyBy`):

- **`Store`** — os registros vivos, guardados duas vezes: por **coluna**
  (indexado por *slot*, a verdade da rede) e por **linha** (indexado por
  `id`, o que o caller lê). `Store.prev` guarda o baseline usado para
  calcular o delta de cada campo; `Store.sent` (só em campos `:newest()`)
  guarda o último valor de fato transmitido.
- **Fieldset** — a codificação de wire de "quais campos mudaram" numa
  seção: escolhe a forma mais barata entre `LIST` (índices explícitos) e
  `MASK` (1 bit por campo, até 64 campos por set — daí o limite).
- **Sections** — o chunk de wire de uma operação: `KEYFRAME` (dump
  completo dos campos, usado em late-join/catchup), `DELTA` (só o que
  mudou), `REMOVAL` (só os slots — deliberadamente **sem causa**, para não
  vazar para quem não deveria saber que o registro existiu), `CLEAR`.
- **Plan** — o planejador de flush por partição, em 5 estágios fixos:
  `Clearing → Dropping(Removal) → Making(Keyframe) → Moving(Delta) →
  Settled`. Se uma seção não couber no orçamento do flush, ela é
  **descartada e fica pendente para o próximo flush** (recoalescida com
  mudanças novas) — exceto a primeira seção de cada partição, que **sempre**
  é aceita mesmo estourando o orçamento, garantindo que um orçamento
  minúsculo nunca trave o sistema.
- **Catchup** — quando alguém ganha visibilidade de uma chave (late join ou
  `audience()` chamado depois), recebe um `KEYFRAME` do estado que já
  existia, através de uma **fatia reservada** do mesmo orçamento de 32KB/s
  (não compete diretamente com o tráfego normal, mas também não é ilimitado
  — backlogs grandes se esvaziam ao longo de vários flushes).

O budget de replicação (`Lync.flush(budget)` / `Lync.flush(namespace,
budget)`) cobre **só a lane confiável** (Keyframe/Delta/Removal/Clear) mais
a reserva de catchup — a lane `:newest()` não é orçada por esse mecanismo,
só limitada pelo cap de ~1000 bytes por pacote unreliable e pelo throttle de
Hz de cada campo.

---

## 6. Codecs

Um codec (`Base.Cell` internamente) é uma tabela imutável com: `kind`,
`params`, `children` (para composites), `validates` (lista de checagens),
`marker` (`"none"`/`"monotonic"`/`"newest"`), e opcionalmente `lift`/`lower`
(de `:as`). Todos compartilham uma única metatable, e todo modificador
**devolve um novo codec** — nunca muta o original (`table.clone` + mutação
da cópia + `table.freeze`).

### 6.1 Números

| Construtor | Bits no wire | Nota |
| --- | --- | --- |
| `bool()` | 1 | — |
| `int(min, max)` | `ceil(log2(max-min+1))` | Ex.: `int(0,100)` → 7 bits. Bounds devem ser inteiros. |
| `quant(min, max, step)` | mesma fórmula sobre o nº de pontos do grid `floor((max-min)/step)+1` | Arredonda pro ponto de grid mais próximo. |
| `angle(precision)` | idem, grid **cíclico** de `0` a `360-precision` | `precision` precisa dividir 360 exatamente (`Grid.divides`), senão erro em `start()`. Reduz módulo o turno antes de arredondar, para não quebrar simetria no wrap. |
| `f32()` / `f64()` | 32 / 64 (IEEE puro) | Nunca recusa por faixa — só por tipo errado. |
| `vlq()` | variável (LEB128-like, 7 bits/byte, até 8 bytes) | Inteiro sem sinal exato até `2^53 - 1`. |
| `vli()` | idem | Inteiro com sinal exato em `(-2^53, 2^53)`. Não é zigzag clássico — sinal fica no bit baixo do primeiro grupo. |

Todo grid tem um teto: se o número de pontos passar de `2^53`, é erro de
definição (`"declares {at} over {span} points, which is past what a double
counts exactly"`).

### 6.2 Texto

| Construtor | Custo |
| --- | --- |
| `str(min, max)` | prefixo de tamanho (byte-alinhado, 0 bytes se `min==max`) + 8 bits/caractere. |
| `str.alphabet(symbols, min, max)` | idem, mas `ceil(log2(#symbols))` bits/caractere, empacotados sem padding entre caracteres (só o byte final é preenchido com zero e checado). Alfabeto não pode ter símbolo repetido. |
| `str.alphanum` | 62 símbolos (`a-z0-9A-Z`, nessa ordem) → 6 bits/char. |
| `str.base32` | 32 símbolos, RFC4648 sem `01` → 5 bits/char. |
| `str.base64` | 64 símbolos → 6 bits/char. |
| `str.digits` | 10 símbolos → 4 bits/char. |
| `str.hex` | 16 símbolos minúsculos → 4 bits/char. |
| `buffer(min, max)` | como `str` bare, mas bytes opacos (sem alfabeto). |

### 6.3 Tipos Roblox

| Construtor | Custo / mecanismo |
| --- | --- |
| `vec2(c?)` / `vec3(c?)` | Sem componente: 2/3× `f32` (raw). Com componente (`int`/`quant`/`angle`/`enum`/`bool`): esse componente repetido 2/3 vezes, empacotado na mesma região de bits. |
| `vec3.unit(precision)` | Direção unitária via **fold octaédrico**: projeta a esfera num quadrado `[-1,1]²`, 2 leaves de `Grid.of(-1,1,precision/90)`. Reflete a metade inferior da esfera antes de quantizar. |
| `vec3.bounded(max, step)` | Direção (2 leaves octaédricos) + magnitude (1 leaf, `Grid.of(0,max,step)`) — 3 leaves totais. Magnitude 0 mapeia pro centro do quadrado (direção indefinida tratada à parte). |
| `cframe(position, rotation)` | Decomposição byte-a-byte: `rotation` decodifica pra CFrame na origem, `position` (um Vector3) soma por cima. |
| `rotation.none()` | **0 bits.** Sempre `CFrame.identity`. |
| `rotation.axis(axis, precision)` | **1 leaf** — grid cíclico de ângulo em torno de um eixo fixo. 1 grau de liberdade. |
| `rotation.direction(precision)` | **2 leaves** — fold octaédrico do vetor "forward" (`-Z`), sem roll. 2 graus de liberdade. |
| `rotation.quat(precision)` | **4 leaves** — "smallest-three": 1 tag de 2 bits (qual dos 4 componentes de quaternion foi descartado — sempre o de maior módulo) + 3 componentes quantizados em `[-1/√2, 1/√2]`. O 4º é reconstruído por `sqrt(1 - a²-b²-c²)`. 3 graus de liberdade (orientação completa). |
| `color3()` | 3× `f32` raw (12 bytes). |
| `color3.rgb565()` | **2 bytes** — 5 bits red / 6 bits green / 5 bits blue, empacotados num único `u16`. |
| `color3.palette(t)` | 1 leaf — índice ranged na tabela `t` (`ceil(log2(#t))` bits). Cores devem ser únicas por RGB exato. |
| `inst(class?)` | **Não vai no buffer de bytes.** Vira um varint = índice num array "sidecar" de Instances que acompanha o frame por fora. `nil`/ausente = slot 0. Se `class` foi declarado, o receptor valida `:IsA(class)` — soft-reject (nunca throw) porque é dado vindo de outra máquina. |

### 6.4 Composites

Toda ordenação de campos/nomes (structs, variantes de `tagged`, nomes de
`enum`/`bitfield`) é **alfabética**, nunca a ordem de declaração no Luau —
é assim que dois compiladores independentes (server/client) concordam em
layout sem trocar metadado de ordem.

| Construtor | Comportamento |
| --- | --- |
| `struct({k=c})` | Campos particionados em 4 regiões: bits de presença (`optional`) → outros campos empacotáveis (mesma região de bits compartilhada) → campos byte-alinhados fixos → payloads variáveis (por último, cada um atrás do seu bit de presença). Um campo não declarado no encode é **throw**, citando a chave ofensora. Sub-structs fixos são "dissolvidos" (achatados) no struct pai em vez de aninhados. |
| `array(c, min, max)` | Prefixo de contagem (0 bytes se `min==max`). Se o elemento é um único grid, vira um **run empacotado** sem padding entre elementos; senão, cada elemento começa no seu próprio byte. |
| `map(k, v, min, max)` | Como `array`, mas chaves precisam ser ordenáveis: se a chave reduz a 1 grid, vira um run de índices ascendentes; senão, as chaves são ordenadas por comparação lexicográfica dos próprios bytes codificados (assim os dois lados concordam em ordem sem trocar índice). |
| `optional(c)` | 1 bit de presença. Se `0`, o leitor **nunca chama** o decoder do payload — zero bytes consumidos. `c` não pode já ser `optional`. |
| `tagged(field, {k=c})` | Toda variante precisa ser `struct`, e nenhuma pode declarar o próprio campo de tag. A tag é um inteiro byte-alinhado (`ceil(log2(#variantes))` bits, arredondado pro byte) = posição alfabética do nome da variante — nunca é lida de volta do struct, é sintetizada por qual leitor rodou. |
| `enum({...})` | 1 leaf — índice ranged, `ceil(log2(#nomes))` bits. Nomes reordenados alfabeticamente internamente. |
| `bitfield({...})` | 1 bit por nome, todos empacotados juntos. Decodifica sempre com **todos** os nomes presentes (nunca falta chave); um valor não-booleano em qualquer chave recusa o campo inteiro. |
| `unknown(maxBytes)` | Formato auto-descritivo tipo JSON: cada valor grava sua própria tag de 1 byte (`nothing`/`false`/`true`/`whole`/`real`/`text`/`bytes`/`list`/`pairs`) antes do payload. Profundidade máxima de aninhamento: 8. "Custa uma tag por parte, não empacota nada" — é o mecanismo pra dado dinâmico/schemaless. |

Nenhum destes (`array`/`map`/`optional`, e outros como `cframe`/`vec2`/
`vec3`) aceita um `optional` como filho direto — a ausência já é implícita
no próprio slot.

### 6.5 Modificadores

| Modificador | Efeito |
| --- | --- |
| `:validate(fn)` | `fn(value, ctx)` retorna `nil` (passa) ou uma razão em string (recusa). **Empilhável** — cada chamada adiciona uma checagem à lista, rodam em ordem, a primeira que falhar decide. Compõe com `:as`: uma checagem declarada antes de um `:as()` continua rodando (contra o valor pré-transformação) mesmo depois. |
| `:as(to, from)` | Mapeia o tipo de wire pro tipo do domínio do caller e vice-versa. **Empilhável** — `codec:as(a,b):as(c,d)` compõe as duas transformações. |
| `:monotonic()` | Só em campos de Set. Marca o campo como "só cresce". |
| `:newest(hz?)` | Só em campos de Set (estado) ou Packets. Em Set: ver §5. Em Packet: ver §3. `hz`, se passado, precisa ser `> 0`. |

`:monotonic()` e `:newest()` são mutuamente exclusivos **no nível do
codec** (é um único campo `marker`, a última chamada vence silenciosamente
em termos de API) — mas a combinação errada de marker com o **tipo de
definição** (packet/query nunca podem ter marker nenhum) é pega em
`Legality.definition`, no `start()`.

### 6.6 Validação inbound

```lua
Damage = Lync.int(0, 500):validate(function(amount, ctx)
    -- ctx.player, ctx.now, ctx.last
    if ctx.last ~= nil and ctx.now - ctx.last < 0.1 then return "faster than 10 Hz" end
    return nil
end)
```

`ctx.last` é atualizado em **toda** chegada, aceita ou não — um flood de
lixo não reseta o relógio de rate-limit de quem manda. A tabela `ctx` é
reaproveitada entre decodes, então qualquer coisa que o `:validate` queira
guardar precisa ser copiada. Um payload recusado é dropado antes do
código do usuário ver e vira um warning; uma `query` recusada nunca é
respondida (quem perguntou recebe `timeout`).

Do ponto de vista de erro: **out of range na escrita sempre lança** (é erro
do próprio processo, detectável em teste); **bytes malformados/fora de
domínio na leitura sempre são só dropados com log** (é dado hostil vindo de
outra máquina, nunca deve derrubar o processo receptor).

---

## 7. Groups (`Lync.group()`)

- `add(player)` / `remove(player)` — idempotentes (chamar duas vezes não é
  erro nem duplica). `remove` usa a técnica "swap com o último elemento" —
  O(1), mas a ordem de iteração muda depois de uma remoção.
- `has(player)` — O(1).
- `#group`, iteração — cobrem a membership atual.
- `destroy()` — esvazia primeiro (solta as referências a `Player`), depois
  trava o objeto. **Qualquer leitura depois disso (inclusive `#group` ou
  `for _ in group`) lança erro** — deliberado, para nunca deixar alguém
  disparar silenciosamente "pra ninguém" achando que o grupo ainda existe.
- **Thinning automático**: todo grupo vivo é varrido globalmente quando
  qualquer jogador sai (`Players.PlayerRemoving`) — não depende de nenhum
  código do usuário conectar nada por grupo.
- Um `Group` é aceito em qualquer lugar que aceita um `Recipient`
  (`fireClient`, `audience`) e vai sendo resolvido pros membros atuais no
  momento do envio, não no momento em que foi passado.

---

## 8. Wire format e transporte (nível baixo)

Só necessário para depuração profunda ou dúvida sobre compatibilidade —
não afeta o dia a dia de escrever schemas.

- **Transporte real**: `ReplicatedStorage/Lync/<namespace>/{handshake,
  reliable, unreliable}` — três Instances por namespace (`RemoteEvent` para
  `handshake`/`reliable`, `UnreliableRemoteEvent` para `unreliable`). O
  client faz `WaitForChild` sem deadline (um namespace lento é tratado como
  "join lento", não como falha).
- **Handshake**: o client manda um hash FNV-1a de 64 bits do namespace
  compilado inteiro (texto canônico do schema, incluindo a versão do
  protocolo — `"{VERSION}:{name}"`). O servidor compara com o próprio hash;
  se bater, responde `ACCEPT` + um `f64` de epoch (a base do clock
  compartilhado); se não bater, responde `REJECT` + o hash do servidor. O
  servidor que detecta o mismatch só avisa (`Log.warn`); o **client que
  recebe o `REJECT` lança exceção fatal**, citando os dois hashes.
- **Clock compartilhado**: os dois lados já usam `workspace:GetServerTimeNow()`
  (sincronizado pelo próprio engine) — o handshake só fixa um epoch comum
  pra que o campo de timestamp de 24 bits (resolução de 1ms, ~4h39 de
  alcance antes de dar a volta) não ambigue. `:timestamped()` grava esse
  campo comprimido; o receptor desambigua o wraparound comparando contra
  sua própria estimativa de tempo decorrido.
- **Frame** = sequência de blocos concatenados. Cada bloco começa com um
  header de largura mínima (`ceil(log2(nº de definições do namespace))`
  bits) que identifica a definição — não é string nem varint solto, é um
  campo de largura fixa calculado uma vez na compilação. O tipo de
  mensagem (packet/query pedido/query resposta/state) é inferido de qual
  definição o índice aponta, não de um campo de "tipo" separado — todos
  coexistem livremente intercalados no mesmo frame.
- **Varint** (`vlq`/`vli`): esquema estilo LEB128 — 7 bits de payload por
  byte, bit 7 = continuação, little-endian por grupo, até 8 bytes.
  `vli` não é zigzag clássico: o sinal fica dobrado no bit baixo do
  primeiro grupo.
- **Bit-packing físico**: campos que cabem numa "região" compartilhada
  (até 24 bits cada — `Protocol.BIT_CEILING`) são compactados em janelas de
  1/2/4 bytes (`bit32.extract`/`bor`/`lshift` sobre `buffer.readuN`/
  `writeuN`), escolhidas gulosamente pela maior janela que os bits restantes
  ainda preenchem por inteiro. Campos maiores que isso ganham bytes
  próprios, sempre alinhados.
- **Limites de frame**: um fire nunca pode montar um frame de mais de
  **1.000.000 bytes** (`Protocol.MAX_FIRE`, o teto documentado da engine
  Roblox para argumentos de RemoteEvent) — estourar é `Log.error` (throw)
  citando o tamanho exato. Um packet unreliable é fatiado automaticamente
  em múltiplos fires de até 1000 bytes cada, se necessário.
- **Erro vs. drop**: `Log.refuse`/`Log.error` sempre lançam (usados para
  erro do processo local — valor fora de domínio ao escrever, chamada de
  API na sequência errada); `Log.reject`/`Log.warn` nunca lançam, usados
  para bytes hostis chegando de outra máquina (sempre logados com um código
  de diagnóstico do catálogo interno — `Catalog.luau` — e nunca derrubam o
  processo).

---

## 9. Erros e logging

```lua
Lync.onLog(function(kind, message, data)
    if data.player ~= nil then flagSuspicious(data.player, data) end
end)
```

| `kind` | Semântica |
| --- | --- |
| `"warn"` | Nunca é falha do processo — dado recusado, payload dropado. |
| `"error"` | Um throw real que já aconteceu em algum lugar contido (ex.: um listener/responder do usuário que lançou) — reportado com traceback, nunca propaga pro resto do fluxo. |
| `"debug"` | Só existe em Studio (`__DEV__`) — em build shipada a chamada nem roda. |

`data: LogData` sempre carrega `file`/`line` (de onde o log se originou);
`player`/`definition` e qualquer outro campo são convenção de quem chama,
não garantidos. **Nada em `LogData` é congelado** — um listener que quer
guardar um registro precisa copiá-lo. `Lync.console` é só mais uma conexão
de `onLog` (a default, formata `"[lync] {file}:{line} {message}"`) —
desconectar ela (`Lync.console:disconnect()`) e plugar a sua própria é o
caminho suportado para logging custom.

---

## 10. Constantes e limites (consolidado)

| Limite | Valor | Fonte |
| --- | --- | --- |
| Campos por Set | 64 | `Protocol.MAX_FIELDS` — uma máscara "sujo" cobre isso |
| Precisão de inteiro/grid | exato até `2^53` | `Protocol.EXACT` — domínio de double |
| Timeout padrão de query | 10 s | `Protocol.QUERY_TIMEOUT` |
| Requests em flight por namespace | 32768 | `Protocol.QUERY_CAP` |
| Cap de payload unreliable | 1000 bytes | `Protocol.UNRELIABLE_CAP` |
| Cap de um frame (fire) | 1.000.000 bytes | `Protocol.MAX_FIRE` |
| Budget de state padrão | 32768 bytes/s por client | `Protocol.BUDGET_RATE` |
| Piso do budget de flush | 1024 bytes | `Protocol.BUDGET_FLOOR` |
| Teto de região de bits compartilhada | 24 bits | `Protocol.BIT_CEILING` |
| Resolução de timestamp | 1 ms, campo de 24 bits (~4h39 de alcance) | `Protocol.STAMP_RATE`/`STAMP_BITS` |
| Detector de "enfileirou e nunca deu flush" | 1 s | `Protocol.DETECTOR_WINDOW` |

---

## 11. Integração com o SuperbulletFrameworkV1-Knit

Contexto do framework relevante para esta seção: hoje **não existe** uso de
`RemoteEvent`/`RemoteFunction` em código de gameplay do repositório — a
única ocorrência é a ponte de debug Studio-only do `SuperbulletLogger`
(sistema à parte, mantido só pelo `superbullet-logger-maintainer`, fora de
escopo aqui). O Knit/Superbullet interno tem seu próprio mecanismo de RPC
Client/Server (`Service.Client.Method`), que continua existindo — Lync não
o substitui, é uma camada adicional para o tráfego de gameplay que hoje o
projeto ainda não tem (packets de ação, queries de compra/transação, estado
replicado de jogo).

### 11.1 Adicionar a dependência

`framework/wally.toml`, mesmo padrão de caret usado por `Component`/
`Signal`/`vide` (bibliotecas de terceiro ativamente mantidas — ver
`.claude/rules/component-architecture.md`, seção "Dependência"):

```toml
[dependencies]
Lync = "axp3cter/lync@^3.0.8"
```

Depois `wally install` dentro de `framework/` — o pacote entra em
`Packages/_Index/axp3cter_lync@<versão>/` e fica acessível via
`ReplicatedStorage.Packages.Lync`, igual aos outros pacotes Wally do
projeto.

### 11.2 Onde vive o schema (`Net.luau`)

Cada `Lync.define(name, defs)` precisa ser `require`-ado pelos dois lados
antes de `Lync.start()` rodar. Isso mapeia diretamente na estrutura
feature-based já usada pelo framework: um schema de rede por feature, em
`src/{Feature}/shared/Net.luau`, com o `name` do namespace igual ao nome da
feature. Não centralizar tudo num `Net.luau` global — isso quebraria o
isolamento entre features que o `rogen-migration-planner` já mantém para o
resto do código, e forçaria toda feature a recompilar/revalidar o schema de
todas as outras a cada mudança.

```lua
-- src/Arena/shared/Net.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

return Lync.define("Arena", {
    Fighters = Lync.replicate(Lync.struct({ ... })):keyBy("team"),
    Strike = Lync.packet(Lync.vec3()):unreliable(),
})
```

`ArenaService`/`ArenaController` (`init.lua`) fazem `require` desse
`Net.luau` normalmente — isso é o que dispara `Lync.define` cedo o
suficiente (durante o autoload de Services/Controllers) para `Lync.start()`
encontrar a definição pronta depois.

### 11.3 Hook de lifecycle no Bootstrap

`Lync.start()` precisa rodar **uma vez, no processo inteiro**, depois que
todo `Net.luau` de toda feature já foi `require`-ado — ou seja, depois que
o autoload de Services/Controllers/Behaviors terminou. Os dois loaders já
fazem esse `require` de forma síncrona antes de chamar `Superbullet.Start()`
(`framework/src/Bootstrap/{server,client}/Superbullet{Server,Client}.
{server,client}.lua`), então o ponto natural é dentro do `:andThen()` que já
existe:

```lua
-- Bootstrap/server/SuperbulletServer.server.lua (trecho relevante)
local RunService = game:GetService("RunService")
local Lync = require(ReplicatedStorage.Packages.Lync)

Superbullet.Start():andThen(function()
    Lync.start()
    RunService.PostSimulation:Connect(Lync.flush)
    print("Superbullet Server initiated.")
    SuperbulletModule:SetAttribute("SuperbulletServer_Initialized", true)
end):catch(warn)
```

Mesma coisa no client. Não chamar `Lync.start()` antes disso — qualquer
`Net.luau` de feature ainda não carregada nesse ponto ficaria de fora do
namespace compilado.

### 11.4 Onde chamar `fireServer`/`add`/`request` dentro de um Service/Controller

Isso não é um sistema Service/Controller próprio — os handles de Packet/
Query/Set retornados por `Net.luau` são objetos de primeira classe, chamados
de dentro do `init.lua`/`Accessor.lua`/`Mutator.lua` de um sistema normal,
seguindo a mesma matriz de comunicação de `knit-architecture.md`:

- Uma escrita de estado de jogo que precisa **replicar** para clients
  (`Set:add`/`update`/`remove`) é uma operação de escrita → mora em
  `Mutator.lua`, nunca em `Accessor.lua` (mesma regra de "Accessor nunca
  escreve" que já vale hoje).
- Um `Query:onServer` que calcula e devolve um valor (compra, ação de
  combate) é, por definição, um cálculo do servidor sobre uma intenção do
  client — mesma forma que `security.md` já exige de qualquer Remote
  manual. **Lync não elimina a necessidade de validar no servidor** — só
  torna impossível, por construção, mandar um valor numérico fora de faixa
  sem que o codec já recuse (`int(0, 500)` nunca deixa passar `99999`,
  nem na escrita nem na leitura) — a validação de *regra de negócio*
  (cooldown, saldo, distância) continua sendo responsabilidade de
  `:validate(fn)` no schema ou de checagem explícita dentro do
  `onServer`/`onServer` do `Query`.
- `onServer`/`onClient`/`onAdded`/`onChanged`/`onRemoved` (os "ouvintes")
  são registrados durante `Construct`/`SuperbulletInit` do sistema — são
  síncronos e não bloqueiam (não fazem `WaitForChild`/`:await()`), então
  respeitam a regra de "Init nunca faz yield" sem esforço extra.

### 11.5 Mapeamento direto com `security.md`

A convenção do Lync de "packet/query nomeado por ação, nunca por valor" já
É a prática que `security.md` exige de RemoteEvents manuais — não precisa
de checklist adicional além do que o próprio `security.md` já lista, mas
vale registrar a correspondência para quem for revisar código:

| Regra de `security.md` | Como o Lync já resolve / o que ainda cabe ao dev |
| --- | --- |
| "Nunca confiar em valor numérico vindo do client" | Um `int(min,max)`/`quant(...)` já recusa (dropa) qualquer valor fora da faixa declarada antes do `onServer` do usuário rodar — mas a faixa em si (ex.: preço máximo de um item) ainda precisa ser a certa; um `int(0, 1000000)` genérico não impede pagar menos que o preço real. |
| "Remotes baseados em ação, nunca em valor" | `Query`/`Packet` já são inerentemente baseados em ação (`Net.PurchaseItem:onServer(function(itemId, player) ... end)`) — o valor a creditar/debitar nunca é parâmetro do client, é sempre calculado dentro do `onServer`. |
| "Servidor sempre valida e calcula" | `:validate(fn)` cobre validação estrutural/de taxa; lógica de negócio (tem saldo, tem o item, cooldown) continua explícita dentro do `onServer`, igual ao exemplo de `ShopService:PurchaseItem` do `security.md`. |

### 11.6 Sets replicados e a camada de UI (Vide)

Um `Set:onChanged`/`onAdded`/`onRemoved` do lado client é um bom produtor
de eventos para alimentar um `vide.source()` (ver
`.claude/rules/interface-architecture.md`) — o padrão natural é um
Controller do lado client assinar o Set uma vez em `Start()` e escrever num
`source` que os `Elements/` Vide já leem reativamente, em vez de qualquer
`Element` conectar direto no `Net.luau`. Mantém a mesma disciplina de
"quem chama é dono do estado" que a arquitetura de UI já segue.

### 11.7 Decisões em aberto (não assumidas por este documento)

- **Nome de namespace por feature vs. um só namespace geral** — este guia
  recomenda um namespace por feature (§11.2) por alinhar com a estrutura
  feature-based, mas isso ainda não foi decidido/validado com o time.
- **Pin exato vs. caret no `wally.toml`** — seguido aqui o padrão já
  existente para bibliotecas de terceiro (`^3.0.8`), mas cabe confirmar
  se o time quer pin exato dado que Lync ainda está em major `3.x` e o
  projeto está adotando a biblioteca pela primeira vez.
- Este documento **não** cobre o pacote `roblox-ts` do Lync
  (`@axpecter/lync`) nem o modo `unknown()`/dinâmico em profundidade além
  do que está no §6.4 — o framework hoje é Luau puro, sem toolchain
  roblox-ts.
