-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 05 - CONSULTAS (Marco 1)
-- Autor: Pedro
--
-- 10 consultas de complexidade crescente sobre o schema "academico"
-- (modelo de 16 tabelas, prefixo tb_). O aluno chega ao curso por
-- tb_aluno -> tb_curriculo -> tb_curso; notas e situação ficam em tb_historico.
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
-- ordenação (o curso é alcançado pelo currículo em que o aluno ingressou).
-- ---------------------------------------------------------------------
SELECT a.cpf, a.nome_aluno, a.email_aluno
FROM tb_aluno a
JOIN tb_curriculo cu ON cu.id_curriculo = a.id_curriculo
JOIN tb_curso c      ON c.id_curso = cu.id_curso
WHERE a.ativo_aluno = true
  AND c.codigo = 'CCO'
ORDER BY a.nome_aluno;

-- ---------------------------------------------------------------------
-- Consulta 2 — junção interna simples
-- Grade de oferta do período 2026/2: turma, disciplina, professor e
-- turno. Três tabelas ligadas por INNER/LEFT JOIN (o LEFT JOIN em professor é só
-- por segurança de leitura; aqui a FK é obrigatória).
-- ---------------------------------------------------------------------
SELECT t.codigo AS turma, d.codigo AS disciplina, d.nome AS disciplina_nome,
       p.nome_professor AS professor, t.turno, t.vagas
FROM tb_turma t
JOIN tb_disciplina d ON d.id_disciplina = t.id_disciplina
JOIN tb_periodo_letivo pl ON pl.id_periodo_letivo = t.id_periodo_letivo
LEFT JOIN tb_professor p ON p.id_professor = t.id_professor
WHERE pl.ano = 2026 AND pl.semestre = 2
ORDER BY d.codigo, t.codigo;

-- ---------------------------------------------------------------------
-- Consulta 3 — [OBRIGATÓRIA] junção externa com agregação
-- Ocupação de cada turma: vagas totais, ocupadas e restantes. O LEFT
-- JOIN garante que turmas sem NENHUMA matrícula ainda apareçam no
-- resultado (com ocupadas = 0) — é exatamente o papel da junção
-- externa aqui: se fosse INNER JOIN, turmas vazias sumiriam do relatório.
-- ---------------------------------------------------------------------
SELECT t.id_turma, t.codigo, d.codigo AS disciplina, t.vagas,
       COUNT(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO')            AS ocupadas,
       t.vagas - COUNT(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO')  AS vagas_restantes
FROM tb_turma t
JOIN tb_disciplina d      ON d.id_disciplina = t.id_disciplina
LEFT JOIN tb_matricula m  ON m.id_turma = t.id_turma
GROUP BY t.id_turma, t.codigo, d.codigo, t.vagas
ORDER BY vagas_restantes;

-- ---------------------------------------------------------------------
-- Consulta 4 — anti-junção (NOT EXISTS)
-- Alunos que não têm nenhuma matrícula registrada. Usa NOT EXISTS em
-- vez de NOT IN de propósito: NOT IN quebra silenciosamente se a
-- subconsulta trouxer NULL, NOT EXISTS não tem esse risco.
-- ---------------------------------------------------------------------
SELECT a.cpf, a.nome_aluno
FROM tb_aluno a
WHERE NOT EXISTS (
    SELECT 1 FROM tb_matricula m WHERE m.id_aluno = a.id_aluno
)
ORDER BY a.nome_aluno;

-- ---------------------------------------------------------------------
-- Consulta 5 — agregação com HAVING
-- Disciplinas cuja média geral de rendimento (média das médias gerais
-- de todos os alunos já avaliados) está abaixo da média geral de TODAS
-- as disciplinas. HAVING filtra sobre o resultado já agregado, diferente
-- do WHERE da Consulta 1 — e usar a média geral como corte (em vez de um
-- número fixo tipo "6") é mais robusto: sempre aponta as disciplinas
-- relativamente mais fracas, não depende de decidir um limiar arbitrário
-- que pode não bater com a distribuição real dos dados.
-- ---------------------------------------------------------------------
SELECT d.codigo, d.nome,
       ROUND(AVG(h.media_geral), 2) AS media_disciplina,
       COUNT(*) AS avaliacoes_consideradas
FROM tb_historico h
JOIN tb_matricula m  ON m.id_matricula = h.id_matricula
JOIN tb_turma t      ON t.id_turma = m.id_turma
JOIN tb_disciplina d ON d.id_disciplina = t.id_disciplina
WHERE h.media_geral IS NOT NULL
GROUP BY d.codigo, d.nome
HAVING AVG(h.media_geral) < (
    SELECT AVG(media_geral) FROM tb_historico WHERE media_geral IS NOT NULL
)
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
    SELECT pr.id_disciplina, pr.id_requisito, 1 AS nivel
    FROM tb_pre_requisito pr
    WHERE pr.id_disciplina = (SELECT id_disciplina FROM tb_disciplina WHERE codigo = 'ENG001')

    UNION ALL

    SELECT ap.id_disciplina, pr.id_requisito, ap.nivel + 1
    FROM arvore_prereq ap
    JOIN tb_pre_requisito pr ON pr.id_disciplina = ap.id_requisito
)
SELECT ap.nivel, d.codigo, d.nome
FROM arvore_prereq ap
JOIN tb_disciplina d ON d.id_disciplina = ap.id_requisito
ORDER BY ap.nivel, d.codigo;

-- ---------------------------------------------------------------------
-- Consulta 7 — [OBRIGATÓRIA] consulta recursiva: disciplinas que o
-- aluno já pode cursar
-- Para um aluno específico (troque o CPF '10000000001' pelo que quiser
-- testar), lista as disciplinas da matriz curricular dele que ele ainda
-- não aprovou E cujos pré-requisitos — inclusive os indiretos — já foram
-- todos aprovados. Primeiro monta o fecho transitivo de pré-requisitos
-- (fechamento_prereq, recursivo), depois cruza com o que o aluno já
-- aprovou (situação APROVADO em tb_historico).
-- ---------------------------------------------------------------------
WITH RECURSIVE fechamento_prereq AS (
    SELECT id_disciplina, id_requisito
    FROM tb_pre_requisito

    UNION

    SELECT fp.id_disciplina, pr.id_requisito
    FROM fechamento_prereq fp
    JOIN tb_pre_requisito pr ON pr.id_disciplina = fp.id_requisito
),
aprovadas_aluno AS (
    SELECT DISTINCT t.id_disciplina
    FROM tb_matricula m
    JOIN tb_historico h ON h.id_matricula = m.id_matricula
    JOIN tb_turma t     ON t.id_turma = m.id_turma
    WHERE m.id_aluno = (SELECT id_aluno FROM tb_aluno WHERE cpf = '10000000001')
      AND h.situacao = 'APROVADO'
)
SELECT d.codigo, d.nome
FROM tb_aluno al
JOIN tb_curriculo_disciplina cd ON cd.id_curriculo = al.id_curriculo
JOIN tb_disciplina d            ON d.id_disciplina = cd.id_disciplina
WHERE al.cpf = '10000000001'
  AND d.id_disciplina NOT IN (SELECT id_disciplina FROM aprovadas_aluno)
  AND NOT EXISTS (
      SELECT 1
      FROM fechamento_prereq fp
      WHERE fp.id_disciplina = d.id_disciplina
        AND fp.id_requisito NOT IN (SELECT id_disciplina FROM aprovadas_aluno)
  )
ORDER BY d.codigo;

-- ---------------------------------------------------------------------
-- Consulta 8 — [OBRIGATÓRIA] função de janela: ranking e percentil
-- Posição de cada aluno dentro do seu curso, por média geral (RANK —
-- empates recebem a mesma posição e pulam a próxima), e o percentil em
-- que ele se encontra dentro do curso (PERCENT_RANK, 0 a 100%).
-- ---------------------------------------------------------------------
SELECT c.codigo AS curso, a.nome_aluno AS aluno, h.media_geral,
       RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_geral DESC) AS posicao_no_curso,
       ROUND(
           (PERCENT_RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_geral) * 100)::numeric,
           1
       ) AS percentil
FROM tb_historico h
JOIN tb_matricula m  ON m.id_matricula = h.id_matricula
JOIN tb_aluno a      ON a.id_aluno = m.id_aluno
JOIN tb_curriculo cu ON cu.id_curriculo = a.id_curriculo
JOIN tb_curso c      ON c.id_curso = cu.id_curso
WHERE h.media_geral IS NOT NULL
ORDER BY c.codigo, posicao_no_curso;

-- ---------------------------------------------------------------------
-- Consulta 9 — [OBRIGATÓRIA] função de janela: LAG para evolução do
-- rendimento
-- Para cada aluno, compara a média geral de cada matrícula com a da
-- matrícula imediatamente anterior (ordenadas pela data de matrícula),
-- mostrando se o rendimento melhorou ou piorou ao longo do tempo.
-- ---------------------------------------------------------------------
SELECT a.cpf, a.nome_aluno AS aluno, m.data_matricula,
       d.codigo AS disciplina, h.media_geral,
       LAG(h.media_geral) OVER (PARTITION BY a.id_aluno ORDER BY m.data_matricula, m.id_matricula) AS media_anterior,
       h.media_geral
         - LAG(h.media_geral) OVER (PARTITION BY a.id_aluno ORDER BY m.data_matricula, m.id_matricula) AS variacao
FROM tb_historico h
JOIN tb_matricula m  ON m.id_matricula = h.id_matricula
JOIN tb_aluno a      ON a.id_aluno = m.id_aluno
JOIN tb_turma t      ON t.id_turma = m.id_turma
JOIN tb_disciplina d ON d.id_disciplina = t.id_disciplina
WHERE h.media_geral IS NOT NULL
ORDER BY a.cpf, m.data_matricula, m.id_matricula;

-- ---------------------------------------------------------------------
-- Consulta 10 — fechamento: CTE + função de janela + filtro
-- Top 3 alunos de cada curso por média geral. Não dá para filtrar o
-- resultado de uma window function direto no WHERE (ela só existe
-- depois do SELECT ser calculado), por isso o RANK entra numa CTE e o
-- filtro "posicao <= 3" vem na consulta externa. É a consulta que mais
-- combina conceitos das anteriores.
-- ---------------------------------------------------------------------
WITH ranking_curso AS (
    SELECT c.codigo AS curso, a.nome_aluno AS aluno, h.media_geral,
           RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_geral DESC) AS posicao
    FROM tb_historico h
    JOIN tb_matricula m  ON m.id_matricula = h.id_matricula
    JOIN tb_aluno a      ON a.id_aluno = m.id_aluno
    JOIN tb_curriculo cu ON cu.id_curriculo = a.id_curriculo
    JOIN tb_curso c      ON c.id_curso = cu.id_curso
    WHERE h.media_geral IS NOT NULL
)
SELECT curso, posicao, aluno, media_geral
FROM ranking_curso
WHERE posicao <= 3
ORDER BY curso, posicao;
