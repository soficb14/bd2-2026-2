# Índices e desempenho — `sql/07_indices.sql`

Frente: **Modelagem Física e Desempenho**. Este documento explica o que o
script mede, por que mede num laboratório à parte e como ler o resultado.

## 1. O que foi medido

Quatro dos índices de desempenho do modelo de 16 tabelas (criados em `sql/03_restricoes.sql`; os demais são B-trees comuns nas chaves estrangeiras), cada um com
`EXPLAIN (ANALYZE, BUFFERS)` **antes** e **depois** de existir:

| # | Índice | Tipo | Consulta medida |
|---|---|---|---|
| 1 | `ix_matricula_turma_ativa` | B-tree **parcial** (`status_matricula = 'MATRICULADO'`) em `tb_matricula(id_turma)` | matrículas ativas de uma turma (é a contagem do trigger `fn_valida_vaga`) |
| 2 | `ix_historico_situacao` | B-tree **parcial** (`situacao <> 'CURSANDO'`) em `tb_historico` | quantos históricos com situação `REPROVADO_FALTA` (a situação mora em `tb_historico`) |
| 3 | `ix_disciplina_ementa_fts` | **GIN** sobre `to_tsvector('portuguese', ementa)` | disciplinas cuja ementa contém "serialização" |
| 4 | `ix_log_ocorrido` | **BRIN** em `ocorrido_em` | eventos de log de um único dia |

Resultado esperado (mediana de 5 execuções; **os tempos variam de máquina para máquina,
as páginas lidas não**). Os tempos e o ganho reais, medidos no Docker do grupo
em 09/11/2026 (PostgreSQL 16, modelo de 16 tabelas), estão em `docs/evidencias_indices.txt`
(§4):

| Índice | Plano antes | Plano depois | Buffers antes → depois |
|---|---|---|---|
| 1 `ix_matricula_turma_ativa` | Seq Scan | Index Only Scan | 3.822 → 4 |
| 2 `ix_historico_situacao` | Seq Scan | Index Only Scan | 3.244 → 6 |
| 3 `ix_disciplina_ementa_fts` | Seq Scan | Bitmap (GIN) | 658 → 62 |
| 4 `ix_log_ocorrido` | Seq Scan | Bitmap (BRIN) | 6.712 → 130 |

O custo do ganho é espaço e escrita: o BRIN ocupa 24 kB para uma tabela de
52 MB; os B-tree parciais ocupam 1,6–2,8 MB para tabelas de 25–30 MB; todo
`INSERT`/`UPDATE` passa a manter também o índice.

## 2. Por que um laboratório (`schema perf`) e não o `academico`?

O banco do projeto tem 300 matrículas, 300 históricos e 120 alunos. Com tabelas desse
tamanho o planner escolhe, **corretamente**, varrer a tabela inteira: ler
poucas páginas custa menos do que navegar num índice. O índice nunca
apareceria no plano e não haveria ganho a medir.

Por isso o script cria o schema `perf` com cópias **sem índice** e muito
mais linhas (600 mil matrículas e 600 mil históricos com a situação; 30 mil disciplinas;
1 milhão de linhas de log), mede, cria o índice (mesma definição de
`03_restricoes.sql`), mede de novo e, no fim, **apaga** o `perf` — o
`pg_dump` do backup não carrega dados de teste. As tabelas de `academico`
não são tocadas. Os dados são gerados com `generate_series` e semente fixa
(`setseed`), então a distribuição é a mesma a cada execução.

## 3. Como ler o `EXPLAIN (ANALYZE, BUFFERS)`

- **`Seq Scan` → `Index Only Scan` / `Bitmap Index Scan`**: o planner passou
  a usar o índice.
- **`Buffers: shared hit=… read=…`**: páginas de 8 kB lidas (já em memória
  = `hit`; trazidas do disco/cache do SO = `read`). A queda de milhares para
  poucas páginas é o ganho real; o tempo depende da máquina, as páginas não.
- **`Heap Fetches: 0`** (índices 1 e 2): o `VACUUM` marcou as páginas como
  visíveis e a resposta saiu só do índice, sem ler a tabela.
- **`Rows Removed by Filter`** (antes): linhas lidas e descartadas — o
  desperdício que o índice elimina.
- **`Rows Removed by Index Recheck`** (BRIN): o BRIN guarda só mínimo/máximo
  por faixa de páginas, então devolve páginas *candidatas* e o banco
  reconfere as linhas. Imprecisão aceita em troca de um índice minúsculo.

## 4. Como reproduzir

O `07` roda pelo **`psql`**, não pelo Query Tool do pgAdmin: ele tem `VACUUM`,
e o PostgreSQL recusa `VACUUM` quando o pgAdmin envia vários comandos de uma
vez (`VACUUM cannot run inside a transaction block`).

Gerar o arquivo de evidências da entrega (PowerShell, na raiz do repositório):

```powershell
docker cp sql bd2_postgres:/tmp/sql
docker exec bd2_postgres bash -c "psql -U bd2 -d marco3 -e -f /tmp/sql/07_indices.sql > /tmp/evidencias_indices.txt 2>&1"
docker cp bd2_postgres:/tmp/evidencias_indices.txt docs\evidencias_indices.txt
```

**Para mostrar um `EXPLAIN` ao vivo no pgAdmin**, mantenha o laboratório (o
schema `perf` fica no `marco3` até você apagá-lo):

```powershell
docker exec -e 'PGOPTIONS=-c perf.manter=on' bd2_postgres psql -U bd2 -d marco3 -f /tmp/sql/07_indices.sql
```

Depois, no Query Tool, **um comando por vez** (selecione o comando e F5):
`DROP INDEX perf.ix_matricula_turma_ativa;` → `EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM perf.tb_matricula WHERE id_turma = 1500 AND status_matricula = 'MATRICULADO';`
(Seq Scan) → recriar o índice (definição em `sql/07_indices.sql`) →
`VACUUM ANALYZE perf.tb_matricula;` → o mesmo `EXPLAIN` (Index Only Scan).
Ao terminar: `DROP SCHEMA perf CASCADE;`.

## 5. Perguntas prováveis na arguição

**Por que o índice 1 é parcial?** Só as matrículas `MATRICULADO` contam para
a vaga. O índice guarda ~70% das linhas, é menor e é exatamente o que o
trigger consulta. (Para a consulta do trigger o planner só pode usá-lo
porque o `WHERE` da consulta implica o predicado do índice.)

**Por que `ix_historico_situacao` exclui `CURSANDO`?** `CURSANDO` é a
situação mais comum (~43% das matrículas ativas) e a menos interessante para relatórios de
reprovação; deixá-la fora reduz o índice e o custo de manutenção. Uma
consulta por `situacao = 'CURSANDO'` **não** pode usar esse índice.

**Por que BRIN no log e não B-tree?** O log é gravado em ordem de data, então
a posição física acompanha `ocorrido_em` (correlação alta). O BRIN ocupa
kilobytes onde um B-tree ocuparia dezenas de megabytes. Se os dados fossem
inseridos fora de ordem, o BRIN perderia a eficácia.

**Por que GIN na ementa?** Busca textual (`@@`) precisa de índice invertido
(palavra → linhas); B-tree não atende. Custo: escrita mais lenta e
atualização em lote ("pending list").

**Por que não há um índice só em `id_aluno`?** O `UNIQUE (id_aluno, id_turma)`
de `tb_matricula` já cria um índice que começa por `id_aluno` e atende buscas por aluno; um
índice extra seria redundante (só custaria escrita).
