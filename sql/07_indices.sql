-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 07 - ÍNDICES: EXPLAIN (ANALYZE, BUFFERS) ANTES E DEPOIS (Marco 2)
-- Frente: Modelagem Física e Desempenho
--
-- Mede o ganho de 4 índices do modelo de 16 tabelas (03_restricoes.sql):
--   1) ix_matricula_turma_ativa  B-tree PARCIAL (status = 'MATRICULADO')
--      -> a contagem de vagas que o trigger fn_valida_vaga() faz
--   2) ix_historico_situacao     B-tree PARCIAL (situacao <> 'CURSANDO')
--      -> consultas de reprovação / indicadores (a situação mora em tb_historico)
--   3) ix_disciplina_ementa_fts  GIN (busca textual na ementa)
--   4) ix_log_ocorrido           BRIN (log ordenado por data)
--
-- POR QUE UM LABORATÓRIO À PARTE?
--   O banco do projeto tem 300 matrículas e 300 históricos: com tabelas tão pequenas o
--   planner (corretamente) prefere varrer a tabela inteira e o índice
--   nunca aparece no plano. Para o ganho ser MEDIDO, este script cria
--   o schema "perf" com cópias SEM índice e muito mais linhas, e mede
--   cada consulta antes e depois de criar o índice. As tabelas do
--   schema "academico" NÃO são tocadas. Os índices criados aqui têm a
--   mesma definição de 03_restricoes.sql.
--
-- Rodar depois de 01..05 (não depende de 06, 08 e 09).
-- Pode ser executado várias vezes. Leva de 30 s a 1 min.
-- Rodar pelo psql, NÃO pelo Query Tool do pgAdmin: o script tem VACUUM, que o
-- PostgreSQL recusa quando o pgAdmin envia vários comandos de uma vez
-- ("VACUUM cannot run inside a transaction block").
--
-- COMO GERAR O ARQUIVO DE EVIDÊNCIAS (saída completa dos EXPLAIN):
--   docker exec -i bd2_postgres psql -U bd2 -d marco3 -e < sql/07_indices.sql > docs/evidencias_indices.txt
--
-- Ao final o schema "perf" é APAGADO (para o pg_dump do backup não
-- carregar ~200 MB de dados de teste). Para MANTÊ-LO e refazer um EXPLAIN
-- ao vivo no pgAdmin (um comando por vez), rode o script assim:
--   docker exec -e 'PGOPTIONS=-c perf.manter=on' bd2_postgres psql -U bd2 -d marco3 -f /tmp/sql/07_indices.sql
-- (antes: docker cp sql bd2_postgres:/tmp/sql). Depois da apresentação:
--   DROP SCHEMA perf CASCADE;
-- =====================================================================

SET client_min_messages = warning;       -- silencia os NOTICE de DROP IF EXISTS
SET search_path TO perf, academico, public;

DROP SCHEMA IF EXISTS perf CASCADE;
CREATE SCHEMA perf;
SET search_path TO perf, academico, public;

SELECT setseed(0.42);                    -- dados reproduzíveis entre execuções

-- ---------------------------------------------------------------------
-- 1. LABORATÓRIO: cópias sem índice, com volume
--    (mesmos tipos de academico: status_mat_t, situacao_t; a matricula do
--    laboratório tem só as colunas que as consultas usam)
-- ---------------------------------------------------------------------
CREATE TABLE perf.tb_matricula (
    id_matricula      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_aluno          integer NOT NULL,
    id_turma          integer NOT NULL,
    data_matricula    date    NOT NULL,
    status_matricula  academico.status_mat_t NOT NULL
);

-- no modelo de 16 tabelas a situação mora no histórico (1:1 com a matrícula)
CREATE TABLE perf.tb_historico (
    id_historico  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_matricula  integer NOT NULL,
    situacao      academico.situacao_t NOT NULL
);

CREATE TABLE perf.tb_disciplina (
    id_disciplina  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo         varchar(20)  NOT NULL,
    nome           varchar(120) NOT NULL,
    ementa         text
);

CREATE TABLE perf.tb_log_matricula (
    id_log_matricula  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_matricula      integer     NOT NULL,
    acao              varchar(50) NOT NULL,
    ocorrido_em       timestamp   NOT NULL
);

-- 600 mil matrículas em 3.000 turmas; ~70% ativas, 20% trancadas, 10% canceladas.
-- Só as ativas têm situação além de CURSANDO: dessas, 43% cursando, 51% aprovadas,
-- 5% reprovadas por nota e 1% por falta (a situação rara que a consulta procura).
-- Os sorteios ficam numa tabela temporária para que matrícula e histórico
-- usem EXATAMENTE os mesmos valores (id_matricula = g).
CREATE TEMP TABLE gen AS
SELECT g, random() AS r, random() AS r2 FROM generate_series(1, 600000) g;

INSERT INTO perf.tb_matricula (id_aluno, id_turma, data_matricula, status_matricula)
SELECT 1 + (g::bigint * 7919) % 40000,
       1 + (g::bigint * 104729) % 3000,
       date '2026-01-01' + (g % 365),
       CASE WHEN r < 0.70 THEN 'MATRICULADO'
            WHEN r < 0.90 THEN 'TRANCADO'
            ELSE 'CANCELADO' END::academico.status_mat_t
FROM gen ORDER BY g;

INSERT INTO perf.tb_historico (id_matricula, situacao)
SELECT g,
       CASE WHEN r >= 0.70 THEN 'CURSANDO'
            WHEN r2 < 0.43 THEN 'CURSANDO'
            WHEN r2 < 0.94 THEN 'APROVADO'
            WHEN r2 < 0.99 THEN 'REPROVADO_NOTA'
            ELSE 'REPROVADO_FALTA' END::academico.situacao_t
FROM gen ORDER BY g;

-- 30 mil disciplinas com ementa de 12 palavras sorteadas; a palavra
-- "serialização" aparece em 1 a cada 500 ementas
INSERT INTO perf.tb_disciplina (codigo, nome, ementa)
SELECT 'D' || g,
       'Disciplina ' || g,
       (SELECT string_agg(
                  (ARRAY['algoritmos','estruturas','dados','redes','sistemas','programação',
                         'modelagem','análise','projeto','arquitetura','software','testes',
                         'segurança','desempenho','interfaces','objetos','computação',
                         'matemática','lógica','engenharia'])[1 + floor(random() * 20)::int],
                  ' ')
          FROM generate_series(1, 12) w WHERE w > 0 AND g > 0)
       || CASE WHEN g % 500 = 0 THEN ' serialização' ELSE '' END
FROM generate_series(1, 30000) g;

-- 1 milhão de linhas de log, gravadas em ordem cronológica (como um log real)
INSERT INTO perf.tb_log_matricula (id_matricula, acao, ocorrido_em)
SELECT 1 + (g * 31) % 600000,
       (ARRAY['INSERT','UPDATE','CANCELAR'])[1 + g % 3],
       timestamp '2026-01-01' + g * interval '30 seconds'
FROM generate_series(1, 1000000) g;

DROP TABLE gen;
VACUUM ANALYZE perf.tb_matricula;
VACUUM ANALYZE perf.tb_historico;
VACUUM ANALYZE perf.tb_disciplina;
VACUUM ANALYZE perf.tb_log_matricula;

-- ---------------------------------------------------------------------
-- 2. FERRAMENTA DE MEDIÇÃO
--    perf.medir() roda a consulta 5 vezes com EXPLAIN (ANALYZE, BUFFERS),
--    guarda a MEDIANA do tempo e o plano usado. O quadro-resumo do final
--    sai dessa tabela. (Tabela e função temporárias: somem com a sessão.)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE resultado (
    ordem        serial,
    indice       text,
    fase         text,
    no_do_plano  text,
    tempo_ms     numeric,
    buffers      bigint,
    linhas_lidas bigint
);

CREATE FUNCTION pg_temp.medir(p_indice text, p_fase text, p_sql text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    j       jsonb;
    tempos  numeric[] := '{}';
    i       int;
    no      text;
    buf     bigint;
    lidas   bigint;
BEGIN
    EXECUTE p_sql;                                          -- aquece o cache
    FOR i IN 1..5 LOOP
        EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_sql INTO j;
        tempos := tempos || (j -> 0 ->> 'Execution Time')::numeric;
    END LOOP;
    -- nó de varredura (Seq Scan, Index Scan, Bitmap Heap Scan...) e nome do índice
    no := trim(both '"' from jsonb_path_query_first(j, '$.**."Node Type" ? (@ like_regex "Scan")')::text);
    no := no || coalesce(' [' || trim(both '"' from jsonb_path_query_first(j, '$.**."Index Name"')::text) || ']', '');
    buf   := coalesce((j -> 0 -> 'Plan' ->> 'Shared Hit Blocks')::bigint, 0)
           + coalesce((j -> 0 -> 'Plan' ->> 'Shared Read Blocks')::bigint, 0);
    lidas := coalesce(jsonb_path_query_first(j, '$.**."Rows Removed by Filter"')::text::bigint, 0);
    INSERT INTO pg_temp.resultado (indice, fase, no_do_plano, tempo_ms, buffers, linhas_lidas)
    SELECT p_indice, p_fase, no, round((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY t)
                                          FROM unnest(tempos) t)::numeric, 3), buf, lidas;
END $$;

-- =====================================================================
-- ÍNDICE 1 — ix_matricula_turma_ativa  (B-tree PARCIAL)
-- Consulta: quantas matrículas ATIVAS tem a turma 1500? É exatamente o
-- que o trigger fn_valida_vaga() pergunta a cada matrícula nova.
-- =====================================================================
SELECT '=== ÍNDICE 1: ix_matricula_turma_ativa (parcial) — ANTES ===' AS bloco;
-- mede (5 execuções, aquece o cache) e, em seguida, o plano completo:
SELECT pg_temp.medir('1 ix_matricula_turma_ativa', 'antes',
   $q$SELECT count(*) FROM perf.tb_matricula WHERE id_turma = 1500 AND status_matricula = 'MATRICULADO'$q$);
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM perf.tb_matricula
 WHERE id_turma = 1500 AND status_matricula = 'MATRICULADO';

CREATE INDEX ix_matricula_turma_ativa
    ON perf.tb_matricula(id_turma)
    WHERE status_matricula = 'MATRICULADO';
VACUUM ANALYZE perf.tb_matricula;

SELECT '=== ÍNDICE 1: ix_matricula_turma_ativa (parcial) — DEPOIS ===' AS bloco;
-- mede (5 execuções, aquece o cache) e, em seguida, o plano completo:
SELECT pg_temp.medir('1 ix_matricula_turma_ativa', 'depois',
   $q$SELECT count(*) FROM perf.tb_matricula WHERE id_turma = 1500 AND status_matricula = 'MATRICULADO'$q$);
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM perf.tb_matricula
 WHERE id_turma = 1500 AND status_matricula = 'MATRICULADO';

-- =====================================================================
-- ÍNDICE 2 — ix_historico_situacao  (B-tree PARCIAL)
-- Consulta: quantos reprovados por falta? A situação é rara (0,5%) e o
-- índice só guarda as linhas já encerradas (situacao <> 'CURSANDO').
-- =====================================================================
SELECT '=== ÍNDICE 2: ix_historico_situacao (parcial) — ANTES ===' AS bloco;
-- mede (5 execuções, aquece o cache) e, em seguida, o plano completo:
SELECT pg_temp.medir('2 ix_historico_situacao', 'antes',
   $q$SELECT count(*) FROM perf.tb_historico WHERE situacao = 'REPROVADO_FALTA'$q$);
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM perf.tb_historico WHERE situacao = 'REPROVADO_FALTA';

CREATE INDEX ix_historico_situacao
    ON perf.tb_historico(situacao)
    WHERE situacao <> 'CURSANDO';
VACUUM ANALYZE perf.tb_historico;

SELECT '=== ÍNDICE 2: ix_historico_situacao (parcial) — DEPOIS ===' AS bloco;
-- mede (5 execuções, aquece o cache) e, em seguida, o plano completo:
SELECT pg_temp.medir('2 ix_historico_situacao', 'depois',
   $q$SELECT count(*) FROM perf.tb_historico WHERE situacao = 'REPROVADO_FALTA'$q$);
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM perf.tb_historico WHERE situacao = 'REPROVADO_FALTA';

-- =====================================================================
-- ÍNDICE 3 — ix_disciplina_ementa_fts  (GIN)
-- Consulta: disciplinas cuja ementa fala de "serialização". B-tree não
-- serve para busca textual; o GIN é um índice invertido (palavra -> linhas).
-- =====================================================================
SELECT '=== ÍNDICE 3: ix_disciplina_ementa_fts (GIN) — ANTES ===' AS bloco;
-- mede (5 execuções, aquece o cache) e, em seguida, o plano completo:
SELECT pg_temp.medir('3 ix_disciplina_ementa_fts', 'antes',
   $q$SELECT id_disciplina, codigo FROM perf.tb_disciplina WHERE to_tsvector('portuguese', coalesce(ementa, '')) @@ plainto_tsquery('portuguese', 'serialização')$q$);
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_disciplina, codigo FROM perf.tb_disciplina
 WHERE to_tsvector('portuguese', coalesce(ementa, '')) @@ plainto_tsquery('portuguese', 'serialização');

CREATE INDEX ix_disciplina_ementa_fts
    ON perf.tb_disciplina
    USING gin (to_tsvector('portuguese', coalesce(ementa, '')));
VACUUM ANALYZE perf.tb_disciplina;

SELECT '=== ÍNDICE 3: ix_disciplina_ementa_fts (GIN) — DEPOIS ===' AS bloco;
-- mede (5 execuções, aquece o cache) e, em seguida, o plano completo:
SELECT pg_temp.medir('3 ix_disciplina_ementa_fts', 'depois',
   $q$SELECT id_disciplina, codigo FROM perf.tb_disciplina WHERE to_tsvector('portuguese', coalesce(ementa, '')) @@ plainto_tsquery('portuguese', 'serialização')$q$);
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_disciplina, codigo FROM perf.tb_disciplina
 WHERE to_tsvector('portuguese', coalesce(ementa, '')) @@ plainto_tsquery('portuguese', 'serialização');

-- =====================================================================
-- ÍNDICE 4 — ix_log_ocorrido  (BRIN)
-- Consulta: o que aconteceu num dia específico? O log é gravado em ordem
-- de data, então a posição física acompanha ocorrido_em e o BRIN (que só
-- guarda mín/máx por faixa de páginas) funciona com um tamanho minúsculo.
-- =====================================================================
SELECT '=== ÍNDICE 4: ix_log_ocorrido (BRIN) — ANTES ===' AS bloco;
-- mede (5 execuções, aquece o cache) e, em seguida, o plano completo:
SELECT pg_temp.medir('4 ix_log_ocorrido', 'antes',
   $q$SELECT count(*) FROM perf.tb_log_matricula WHERE ocorrido_em >= timestamp '2026-03-15' AND ocorrido_em < timestamp '2026-03-16'$q$);
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM perf.tb_log_matricula
 WHERE ocorrido_em >= timestamp '2026-03-15' AND ocorrido_em < timestamp '2026-03-16';

CREATE INDEX ix_log_ocorrido
    ON perf.tb_log_matricula
    USING brin (ocorrido_em);
VACUUM ANALYZE perf.tb_log_matricula;

SELECT '=== ÍNDICE 4: ix_log_ocorrido (BRIN) — DEPOIS ===' AS bloco;
-- mede (5 execuções, aquece o cache) e, em seguida, o plano completo:
SELECT pg_temp.medir('4 ix_log_ocorrido', 'depois',
   $q$SELECT count(*) FROM perf.tb_log_matricula WHERE ocorrido_em >= timestamp '2026-03-15' AND ocorrido_em < timestamp '2026-03-16'$q$);
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM perf.tb_log_matricula
 WHERE ocorrido_em >= timestamp '2026-03-15' AND ocorrido_em < timestamp '2026-03-16';

-- ---------------------------------------------------------------------
-- 3. TAMANHO DOS ÍNDICES (o custo do ganho: espaço em disco)
-- ---------------------------------------------------------------------
SELECT '=== TAMANHO: tabela x índice ===' AS bloco;
SELECT c.relname                                   AS indice,
       pg_get_indexdef(c.oid)                      AS definicao,
       pg_size_pretty(pg_relation_size(c.oid))     AS tamanho_indice,
       pg_size_pretty(pg_relation_size(i.indrelid)) AS tamanho_tabela
FROM pg_class c
JOIN pg_index i ON i.indexrelid = c.oid
WHERE c.relnamespace = 'perf'::regnamespace
  AND c.relname LIKE 'ix\_%'
ORDER BY c.relname;

-- ---------------------------------------------------------------------
-- 4. LIMPEZA (a menos que perf.manter = 'on')
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF coalesce(current_setting('perf.manter', true), '') <> 'on' THEN
        DROP SCHEMA perf CASCADE;
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 5. QUADRO-RESUMO: o ganho medido (mediana de 5 execuções)
--    ganho = tempo antes / tempo depois ("quantas vezes mais rápido")
-- ---------------------------------------------------------------------
SELECT a.indice,
       a.no_do_plano                 AS plano_antes,
       d.no_do_plano                 AS plano_depois,
       a.tempo_ms                    AS antes_ms,
       d.tempo_ms                    AS depois_ms,
       round(a.tempo_ms / NULLIF(d.tempo_ms, 0), 1) AS ganho_x,
       a.buffers                     AS buffers_antes,
       d.buffers                     AS buffers_depois
FROM pg_temp.resultado a
JOIN pg_temp.resultado d ON d.indice = a.indice AND d.fase = 'depois'
WHERE a.fase = 'antes'
ORDER BY a.indice;
