---
name: lync-networking-integration
description: Avaliação do Lync (networking tipado por buffer) como camada de rede do framework — clonado, documentado e integrado; namespace por feature e pin caret decididos e aplicados
metadata:
  type: project
---

Usuário clonou `https://github.com/Axp3cter/Lync` (reescrita completa, v3.0.8,
commit `91b28bea91b32e556b963b83b6e38cd7b30c46b5`) em `lync-temporary/` na raiz
do repo, em 2026-08-26, pedindo documentação completa de uso interno (pacotes,
codecs, payloads, keys, groups, delta values) para preparar integração com o
SuperbulletFrameworkV1-Knit.

**Trabalho feito:** guia técnico completo em
`framework/documentations/codebase/Lync-Guide.md` — cobre ciclo de vida
(define/start/flush/close), os três tipos de definição (packet/query/set),
catálogo de codecs com custo de bits exato, motor de replicação/delta de
Sets, wire format, e uma seção final de integração com o framework (onde
colocar `Net.luau` por feature, hook de `Lync.start()`/`flush()` nos
Bootstrap loaders, mapeamento com `security.md`).

**Why:** o objetivo é usar Lync como camada de networking de gameplay —
hoje o framework não tem nenhum uso de `RemoteEvent`/`RemoteFunction` fora
da ponte de debug do `SuperbulletLogger` (Studio-only, sistema à parte). O
Knit/Superbullet interno (`Service.Client.Method`) continua existindo para
RPC simples; Lync entraria como complemento para packets/queries/estado
replicado.

**Estado atual — decidido e aplicado em `framework/src/Profile/**`:**
- `lync-temporary/` foi o clone de referência usado só para escrever o guia;
  removido do disco depois de cumprir esse papel (não fazia parte de
  `framework/src/` nem de `framework/wally.toml`, e nunca foi commitado).
- Decisões (ver `Lync-Guide.md`, seção 11.7) confirmadas pelo usuário e
  aplicadas: namespace Lync por feature (não um namespace geral único) —
  ex. `framework/src/Profile/shared/Net.luau`; pin caret `^3.0.8` (não pin
  exato) em `framework/wally.toml`, mesmo padrão já usado para `vide`/
  `Signal`/`Component` (bibliotecas de terceiro absorvendo patch/minor
  automaticamente).

**How to apply (próximos usos do padrão):** para uma feature nova que
precise de Lync, seguir o mesmo modelo — `Net.luau` dentro de
`shared/` da própria feature, sem namespace geral compartilhado. Ver
[[project-overview]] para o estado geral do framework e [[decisions-log]]
para o registro da decisão.
