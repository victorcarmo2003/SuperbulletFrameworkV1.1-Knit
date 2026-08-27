---
name: review
description: Revisa o diff atual (ou um arquivo/branch/PR especificado) contra as regras de arquitetura do framework SuperbulletFrameworkV1-Knit, delegando pro subagente superbullet-architecture-reviewer. Use antes de considerar qualquer mudança no framework pronta, ou quando o usuário pedir "revisa isso", "/review".
---

Você vai rodar uma revisão de arquitetura no código alterado do
`SuperbulletFrameworkV1-Knit`, delegando pro subagente
`superbullet-architecture-reviewer` — **não revise você mesmo inline**, ele
já sabe ler `.claude/rules/knit-architecture.md`,
`.claude/rules/component-architecture.md`,
`.claude/rules/interface-architecture.md` e `.claude/rules/security.md`
antes de revisar, e sinaliza violação sem aplicar fix.

## Passo 1 — determinar o escopo

- Se o usuário passou um argumento (caminho de arquivo, pasta, nome de
  branch, número de PR), use esse escopo.
- Senão, rode `git diff` (staged + unstaged) no repo. Se vier vazio, tente
  `git diff <branch-base>...HEAD` pra pegar os commits do branch atual ainda
  não mergeados em `master`.
- Se não houver nenhuma mudança pra revisar em nenhum dos dois casos, avise
  o usuário e pare — não invente revisão sem diff real.

## Passo 2 — delegar

Use o Agent tool com `subagent_type: "superbullet-architecture-reviewer"`,
passando o diff/conteúdo real do escopo determinado no Passo 1 (não resuma
antes de mandar — o subagente decide o que é relevante lendo o diff
completo).

## Passo 3 — reportar

Repasse os findings do subagente pro usuário no formato que ele já usa
(`arquivo:linha — problema. como corrigir.`), sem adicionar elogio nem
achado que o subagente não reportou. Se a lista vier vazia, diga
explicitamente "sem violação encontrada" — não invente ressalva só pra
preencher espaço.
