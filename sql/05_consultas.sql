-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 05 - CONSULTAS (Marco 1)
-- Autor: Pedro
--
-- 10 consultas de complexidade crescente sobre o schema "academico".
-- Cobrem obrigatoriamente: junção externa com agregação (Consulta 3),
-- consulta recursiva para a árvore de pré-requisitos (Consulta 6),
-- consulta recursiva para disciplinas que um aluno já pode cursar
-- (Consulta 7), função de janela com ranking e percentil (Consulta 8)
-- e função de janela com LAG para evolução do rendimento (Consulta 9).
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- Consulta 1 — filtro simples
-- Lista os alunos ativos de um curso específico (CCO), em ordem
-- alfabética. Serve de ponto de partida: sem junção, só filtro e
-- ordenação.
-- ---------------------------------------------------------------------
SELECT a.matricula, a.nome, a.email
FROM aluno a
JOIN curso c ON c.id = a.curso_id
WHERE a.ativo = true
  AND c.codigo = 'CCO'
ORDER BY a.nome;

-- ---------------------------------------------------------------------
-- Consulta 2 — junção interna simples
-- Grade de oferta do período 2026/2: turma, disciplina, professor e
-- turno. Três tabelas ligadas por INNER/LEFT JOIN (professor pode ser
-- nulo, por isso LEFT).
-- ---------------------------------------------------------------------
SELECT t.codigo AS turma, d.codigo AS disciplina, d.nome AS disciplina_nome,
       p.nome AS professor, t.turno, t.vagas
FROM turma t
JOIN disciplina d ON d.id = t.disciplina_id
JOIN periodo_letivo pl ON pl.id = t.periodo_letivo_id
LEFT JOIN professor p ON p.id = t.professor_id
WHERE pl.ano = 2026 AND pl.semestre = 2
ORDER BY d.codigo, t.codigo;

-- ---------------------------------------------------------------------
-- Consulta 3 — [OBRIGATÓRIA] junção externa com agregação
-- Ocupação de cada turma: vagas totais, ocupadas e restantes. O LEFT
-- JOIN garante que turmas sem NENHUMA matrícula ainda apareçam no
-- resultado (com ocupadas = 0) — é exatamente o papel da junção
-- externa aqui: se fosse INNER JOIN, turmas vazias sumiriam do relatório.
-- ---------------------------------------------------------------------
SELECT t.id AS turma_id, t.codigo, d.codigo AS disciplina, t.vagas,
       COUNT(m.id) FILTER (WHERE m.status = 'MATRICULADO')            AS ocupadas,
       t.vagas - COUNT(m.id) FILTER (WHERE m.status = 'MATRICULADO')  AS vagas_restantes
FROM turma t
JOIN disciplina d       ON d.id = t.disciplina_id
LEFT JOIN matricula m   ON m.turma_id = t.id
GROUP BY t.id, t.codigo, d.codigo, t.vagas
ORDER BY vagas_restantes;

-- ---------------------------------------------------------------------
-- Consulta 4 — anti-junção (NOT EXISTS)
-- Alunos que não têm nenhuma matrícula registrada. Usa NOT EXISTS em
-- vez de NOT IN de propósito: NOT IN quebra silenciosamente se a
-- subconsulta trouxer NULL, NOT EXISTS não tem esse risco.
-- ---------------------------------------------------------------------
SELECT a.matricula, a.nome
FROM aluno a
WHERE NOT EXISTS (
    SELECT 1 FROM matricula m WHERE m.aluno_id = a.id
)
ORDER BY a.nome;

-- ---------------------------------------------------------------------
-- Consulta 5 — agregação com HAVING
-- Disciplinas cuja média geral de rendimento (média das médias finais
-- de todos os alunos já avaliados) está abaixo de 6. HAVING filtra
-- sobre o resultado já agregado, diferente do WHERE da Consulta 1.
-- ---------------------------------------------------------------------
SELECT d.codigo, d.nome,
       ROUND(AVG(h.media_final), 2) AS media_disciplina,
       COUNT(*) AS avaliacoes_consideradas
FROM historico h
JOIN matricula m  ON m.id = h.matricula_id
JOIN turma t      ON t.id = m.turma_id
JOIN disciplina d ON d.id = t.disciplina_id
WHERE h.media_final IS NOT NULL
GROUP BY d.codigo, d.nome
HAVING AVG(h.media_final) < 6
ORDER BY media_disciplina;

-- ---------------------------------------------------------------------
-- Consulta 6 — [OBRIGATÓRIA] consulta recursiva: árvore de pré-requisitos
-- Dada uma disciplina (ENG001 = Engenharia de Software), sobe a cadeia
-- completa de pré-requisitos, direto e indireto (ENG001 exige POO001,
-- que exige ALG001 — dois níveis). O caso-base pega os requisitos
-- diretos; o passo recursivo persegue os requisitos dos requisitos até
-- não haver mais nenhum.
-- ---------------------------------------------------------------------
WITH RECURSIVE arvore_prereq AS (
    SELECT pr.disciplina_id, pr.requisito_id, 1 AS nivel
    FROM pre_requisito pr
    WHERE pr.disciplina_id = (SELECT id FROM disciplina WHERE codigo = 'ENG001')

    UNION ALL

    SELECT ap.disciplina_id, pr.requisito_id, ap.nivel + 1
    FROM arvore_prereq ap
    JOIN pre_requisito pr ON pr.disciplina_id = ap.requisito_id
)
SELECT ap.nivel, d.codigo, d.nome
FROM arvore_prereq ap
JOIN disciplina d ON d.id = ap.requisito_id
ORDER BY ap.nivel, d.codigo;

-- ---------------------------------------------------------------------
-- Consulta 7 — [OBRIGATÓRIA] consulta recursiva: disciplinas que o
-- aluno já pode cursar
-- Para um aluno específico (troque a matrícula 'ALU20260001' pela que
-- quiser testar), lista as disciplinas do seu currículo que ele ainda
-- não cursou/aprovou E cujos pré-requisitos — inclusive os indiretos —
-- já foram todos aprovados. Primeiro monta o fecho transitivo de
-- pré-requisitos (fechamento_prereq, recursivo), depois cruza com o
-- que o aluno já aprovou.
-- ---------------------------------------------------------------------
WITH RECURSIVE fechamento_prereq AS (
    SELECT disciplina_id, requisito_id
    FROM pre_requisito

    UNION

    SELECT fp.disciplina_id, pr.requisito_id
    FROM fechamento_prereq fp
    JOIN pre_requisito pr ON pr.disciplina_id = fp.requisito_id
),
aprovadas_aluno AS (
    SELECT DISTINCT t.disciplina_id
    FROM matricula m
    JOIN turma t      ON t.id = m.turma_id
    JOIN historico h  ON h.matricula_id = m.id
    WHERE m.aluno_id = (SELECT id FROM aluno WHERE matricula = 'ALU20260001')
      AND h.situacao = 'APROVADO'
)
SELECT d.codigo, d.nome
FROM curriculo_disciplina cd
JOIN disciplina d ON d.id = cd.disciplina_id
JOIN aluno al     ON al.curriculo_id = cd.curriculo_id
WHERE al.matricula = 'ALU20260001'
  AND d.id NOT IN (SELECT disciplina_id FROM aprovadas_aluno)
  AND NOT EXISTS (
      SELECT 1
      FROM fechamento_prereq fp
      WHERE fp.disciplina_id = d.id
        AND fp.requisito_id NOT IN (SELECT disciplina_id FROM aprovadas_aluno)
  )
ORDER BY d.codigo;

-- ---------------------------------------------------------------------
-- Consulta 8 — [OBRIGATÓRIA] função de janela: ranking e percentil
-- Posição de cada aluno dentro do seu curso, por média final (RANK —
-- empates recebem a mesma posição e pulam a próxima), e o percentil em
-- que ele se encontra dentro do curso (PERCENT_RANK, 0 a 100%).
-- ---------------------------------------------------------------------
SELECT c.codigo AS curso, a.nome AS aluno, h.media_final,
       RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_final DESC) AS posicao_no_curso,
       ROUND(
           PERCENT_RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_final) * 100,
           1
       ) AS percentil
FROM historico h
JOIN matricula m ON m.id = h.matricula_id
JOIN aluno a     ON a.id = m.aluno_id
JOIN curso c     ON c.id = a.curso_id
WHERE h.media_final IS NOT NULL
ORDER BY c.codigo, posicao_no_curso;

-- ---------------------------------------------------------------------
-- Consulta 9 — [OBRIGATÓRIA] função de janela: LAG para evolução do
-- rendimento
-- Para cada aluno, compara a média final de cada matrícula com a da
-- matrícula imediatamente anterior (ordenadas pela data de matrícula),
-- mostrando se o rendimento melhorou ou piorou ao longo do tempo.
-- ---------------------------------------------------------------------
SELECT a.matricula AS ra, a.nome AS aluno, m.data_matricula,
       d.codigo AS disciplina, h.media_final,
       LAG(h.media_final) OVER (PARTITION BY a.id ORDER BY m.data_matricula) AS media_anterior,
       h.media_final
         - LAG(h.media_final) OVER (PARTITION BY a.id ORDER BY m.data_matricula) AS variacao
FROM historico h
JOIN matricula m  ON m.id = h.matricula_id
JOIN aluno a      ON a.id = m.aluno_id
JOIN turma t      ON t.id = m.turma_id
JOIN disciplina d ON d.id = t.disciplina_id
WHERE h.media_final IS NOT NULL
ORDER BY a.matricula, m.data_matricula;

-- ---------------------------------------------------------------------
-- Consulta 10 — fechamento: CTE + função de janela + filtro
-- Top 3 alunos de cada curso por média final. Não dá para filtrar o
-- resultado de uma window function direto no WHERE (ela só existe
-- depois do SELECT ser calculado), por isso o RANK entra numa CTE e o
-- filtro "posicao <= 3" vem na consulta externa. É a consulta que mais
-- combina conceitos das anteriores.
-- ---------------------------------------------------------------------
WITH ranking_curso AS (
    SELECT c.codigo AS curso, a.nome AS aluno, h.media_final,
           RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_final DESC) AS posicao
    FROM historico h
    JOIN matricula m ON m.id = h.matricula_id
    JOIN aluno a     ON a.id = m.aluno_id
    JOIN curso c     ON c.id = a.curso_id
    WHERE h.media_final IS NOT NULL
)
SELECT curso, posicao, aluno, media_final
FROM ranking_curso
WHERE posicao <= 3
ORDER BY curso, posicao;
