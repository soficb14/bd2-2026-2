-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 08 - TRANSAÇÕES E CONCORRÊNCIA: A DISPUTA PELA ÚLTIMA VAGA (Marco 2)
-- Frente: Transações e Concorrência
--
-- Este script PREPARA o cenário e oferece utilitários. As duas sessões
-- concorrentes (que precisam de DUAS abas do Query Tool) estão em
-- docs/CONCORRENCIA.md, passo a passo.
--
-- O PROBLEMA
--   Turma com 1 vaga restante, dois alunos se matriculando AO MESMO
--   TEMPO. O trigger fn_valida_vaga() (03_restricoes.sql) conta as
--   matrículas e recusa se a turma estiver cheia. Em READ COMMITTED
--   (o padrão), cada transação só enxerga o que já foi COMMITADO:
--   a sessão B não vê a matrícula da sessão A, que ainda não commitou,
--   conta "0 ocupadas" e também entra. Resultado: 2 matriculados numa
--   turma de 1 vaga. O trigger é necessário, mas NÃO é suficiente: o
--   "verifica e depois insere" não é atômico entre transações.
--
-- AS DUAS CORREÇÕES
--   1) Bloqueio explícito: SELECT ... FOR UPDATE na linha da turma
--      antes de inserir. Quem chega depois ESPERA o outro terminar.
--   2) Nível de isolamento: SERIALIZABLE. As duas transações rodam
--      juntas; o banco detecta o conflito e ABORTA uma (erro 40001),
--      que a aplicação precisa REPETIR.
--
-- Rodar depois de 01..06. Pode ser executado várias vezes.
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- Cenário isolado: a turma 'CONC' (disciplina Banco de Dados, período
-- 2026/2). Não mexe nas turmas T01..T07 da carga.
-- fn_reset_cenario_concorrencia(n): apaga qualquer matrícula da turma
-- de teste e a recria com n vagas. Devolve o id da turma.
--
-- No modelo de 16 tabelas a matrícula tem "filhos": tb_historico e
-- tb_log_matricula (FK sem CASCADE, de propósito: matrícula real nunca
-- é apagada). Por isso o reset apaga primeiro histórico e log DA TURMA
-- DE TESTE e só então as matrículas. É função de laboratório: nunca
-- aponte-a para uma turma de verdade.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_reset_cenario_concorrencia(p_vagas integer DEFAULT 1)
RETURNS integer
LANGUAGE plpgsql
SET search_path = academico, public   -- funciona de qualquer sessão, sem SET search_path prévio
AS $$
DECLARE
    v_turma integer;
BEGIN
    SELECT id_turma INTO v_turma FROM tb_turma WHERE codigo = 'CONC';

    IF v_turma IS NULL THEN
        INSERT INTO tb_turma (codigo, id_disciplina, id_periodo_letivo, id_professor, turno, vagas)
        SELECT 'CONC',
               (SELECT id_disciplina FROM tb_disciplina WHERE codigo = 'BD001'),
               (SELECT id_periodo_letivo FROM tb_periodo_letivo WHERE ano = 2026 AND semestre = 2),
               (SELECT id_professor FROM tb_professor ORDER BY id_professor LIMIT 1),
               'NOTURNO', p_vagas
        RETURNING id_turma INTO v_turma;
    ELSE
        DELETE FROM tb_historico
         WHERE id_matricula IN (SELECT id_matricula FROM tb_matricula WHERE id_turma = v_turma);
        DELETE FROM tb_log_matricula
         WHERE id_matricula IN (SELECT id_matricula FROM tb_matricula WHERE id_turma = v_turma);
        DELETE FROM tb_matricula WHERE id_turma = v_turma;
        UPDATE tb_turma SET vagas = p_vagas WHERE id_turma = v_turma;
    END IF;

    RETURN v_turma;
END;
$$;

COMMENT ON FUNCTION fn_reset_cenario_concorrencia(integer) IS
  'Recria a turma de teste CONC com N vagas e sem matrículas (cenário da disputa pela última vaga).';

-- ---------------------------------------------------------------------
-- Conferência: a turma está consistente? (ocupadas <= vagas)
-- Se "excesso" for > 0, a anomalia aconteceu (overbooking).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_conferencia_vagas AS
SELECT t.codigo                                   AS turma,
       t.vagas,
       count(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO') AS matriculados,
       greatest(count(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO') - t.vagas, 0) AS excesso,
       CASE WHEN count(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO') > t.vagas
            THEN 'ANOMALIA: turma estourou' ELSE 'ok' END AS situacao
FROM tb_turma t
LEFT JOIN tb_matricula m ON m.id_turma = t.id_turma
GROUP BY t.id_turma, t.codigo, t.vagas;

-- ---------------------------------------------------------------------
-- Preparação padrão para a demonstração: 1 vaga.
-- ---------------------------------------------------------------------
SELECT fn_reset_cenario_concorrencia(1) AS turma_id_de_teste;

-- Conferir:
-- SELECT * FROM vw_conferencia_vagas WHERE turma = 'CONC';
-- Para repetir qualquer demonstração do zero:
-- SELECT fn_reset_cenario_concorrencia(1);
