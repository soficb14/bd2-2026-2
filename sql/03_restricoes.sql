-- ============================================================
-- 03_restricoes.sql
-- Restrições adicionais, trigger e índices
-- ============================================================

SET search_path TO academico, public;

-- ============================================================
-- 1. Impede conflito de horários na mesma sala
-- ============================================================

ALTER TABLE turma_horario
    ADD CONSTRAINT ex_sala_ocupada
    EXCLUDE USING gist (
        sala_id WITH =,
        dia_semana WITH =,
        faixa WITH &&
    );


-- ============================================================
-- 2. Função para validar vagas da turma
-- ============================================================

CREATE OR REPLACE FUNCTION fn_valida_vaga()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_vagas   smallint;
    v_ocupadas integer;
BEGIN
    SELECT vagas
      INTO v_vagas
      FROM turma
     WHERE id = NEW.turma_id;

    SELECT count(*)
      INTO v_ocupadas
      FROM matricula
     WHERE turma_id = NEW.turma_id
       AND status = 'MATRICULADO'
       AND id <> COALESCE(NEW.id, -1);

    IF v_ocupadas >= v_vagas THEN
        RAISE EXCEPTION
            'Turma % sem vagas (% de %)',
            NEW.turma_id,
            v_ocupadas,
            v_vagas
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 3. Trigger de controle de vagas
-- ============================================================

CREATE TRIGGER tg_valida_vaga
BEFORE INSERT OR UPDATE ON matricula
FOR EACH ROW
EXECUTE FUNCTION fn_valida_vaga();


-- ============================================================
-- 4. Índices para desempenho
-- ============================================================

-- Índice parcial: considera somente matrículas ativas.
CREATE INDEX ix_matricula_turma_ativa
    ON matricula(turma_id)
    WHERE status = 'MATRICULADO';


-- Facilita consultas de matrículas por aluno.
CREATE INDEX ix_matricula_aluno
    ON matricula(aluno_id);


-- Facilita consultas de turmas por período e disciplina.
CREATE INDEX ix_turma_periodo_disc
    ON turma(periodo_letivo_id, disciplina_id);


-- Índice parcial para situações já encerradas.
CREATE INDEX ix_historico_situacao
    ON historico(situacao)
    WHERE situacao <> 'CURSANDO';


-- BRIN é adequado para dados temporais naturalmente ordenados.
CREATE INDEX ix_log_ocorrido
    ON log_matricula
    USING brin(ocorrido_em);


-- Busca textual na ementa das disciplinas.
CREATE INDEX ix_disciplina_ementa_fts
    ON disciplina
    USING gin(
        to_tsvector('portuguese', coalesce(ementa, ''))
    );