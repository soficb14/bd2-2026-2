-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 03 - RESTRIÇÕES DE REGRA DE NEGÓCIO (triggers) E ÍNDICES BÁSICOS
-- Pré-requisito: 02_tabelas.sql
-- (a regra de sala ocupada, EXCLUDE, já está em tb_turma_horario)
-- =====================================================================

SET search_path TO academico, public;

-- =====================================================================
-- 1. REGRAS DE NEGÓCIO NO BANCO (triggers)
-- =====================================================================
-- ---- Controle de vagas ----------------------------------------------
-- POR QUÊ : CHECK não consegue olhar outras linhas; "a turma lotou" é uma
--           regra que depende de COUNT(*) em tb_matricula.
-- O QUE   : antes de gravar uma matrícula ATIVA, conta quantas já estão
--           ativas na turma e recusa se as vagas esgotaram.
-- COMO    :
--  * Só valida quando o novo status é MATRICULADO; assim cancelar/trancar
--    numa turma lotada continua funcionando.
--  * id_matricula IS DISTINCT FROM NEW.id_matricula evita que a própria
--    linha (em UPDATE) seja contada contra si mesma.
--  * LIMITAÇÃO PROPOSITAL: "conta e depois insere" não é atômico entre
--    transações. Em READ COMMITTED, duas sessões disputando a última vaga
--    não enxergam a matrícula uma da outra (ainda não commitada) e as
--    duas entram: overbooking. O trigger é necessário, mas não suficiente.
--    A anomalia é demonstrada e corrigida em 08_concorrencia.sql
--    (SELECT ... FOR UPDATE na turma, ou isolamento SERIALIZABLE).
CREATE FUNCTION fn_valida_vaga() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_vagas    smallint;
    v_ocupadas integer;
BEGIN
    IF NEW.status_matricula <> 'MATRICULADO' THEN
        RETURN NEW;
    END IF;

    SELECT vagas INTO v_vagas
      FROM tb_turma WHERE id_turma = NEW.id_turma;

    SELECT count(*) INTO v_ocupadas
      FROM tb_matricula
     WHERE id_turma = NEW.id_turma
       AND status_matricula = 'MATRICULADO'
       AND id_matricula IS DISTINCT FROM NEW.id_matricula;

    IF v_ocupadas >= v_vagas THEN
        RAISE EXCEPTION 'Turma % sem vagas (% de %)', NEW.id_turma, v_ocupadas, v_vagas
              USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER tg_valida_vaga
    BEFORE INSERT OR UPDATE OF status_matricula, id_turma ON tb_matricula
    FOR EACH ROW EXECUTE FUNCTION fn_valida_vaga();

-- ---- Histórico nasce junto com a matrícula ---------------------------
-- POR QUÊ : tb_historico é 1:1 com tb_matricula. Se cada matrícula não
--           ganhar sua linha de histórico automaticamente, "matrícula
--           sem histórico" vira estado possível e as consultas de notas
--           passam a esquecer esses alunos.
-- O QUE   : ao inserir uma matrícula, cria o histórico vazio (situação
--           calculada = CURSANDO, frequência 100).
-- COMO    : AFTER INSERT. SECURITY DEFINER porque quem se matricula pode
--           ser o próprio aluno, que NÃO tem (e não deve ter) permissão
--           de escrita em tb_historico: a função roda com os direitos do
--           dono. search_path fixo evita que alguém "sequestre" nomes.
CREATE FUNCTION fn_cria_historico() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = academico, pg_temp AS $$
BEGIN
    INSERT INTO tb_historico (id_matricula) VALUES (NEW.id_matricula);
    RETURN NULL;
END $$;

CREATE TRIGGER tg_cria_historico
    AFTER INSERT ON tb_matricula
    FOR EACH ROW EXECUTE FUNCTION fn_cria_historico();

-- ---- Auditoria automática -------------------------------------------
-- POR QUÊ : preencher tb_log_matricula na aplicação é esquecível; no
--           banco é obrigatório e vale para qualquer cliente (app, psql).
-- O QUE   : registra toda matrícula criada e toda troca de status.
-- COMO    : AFTER (a linha já existe, então a FK do log é satisfeita).
--           SECURITY DEFINER: ninguém além do trigger precisa (nem pode)
--           escrever no log. Como dentro de uma função DEFINER o
--           current_user vira o dono, o "quem fez" é recuperado de
--           current_setting('role') (papel assumido com SET ROLE) ou, se
--           nenhum, de session_user (o login da conexão).
CREATE FUNCTION fn_log_matricula() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = academico, pg_temp AS $$
DECLARE
    v_usuario text := CASE WHEN current_setting('role', true) IN ('none', '')
                           THEN session_user::text
                           ELSE current_setting('role') END;
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO tb_log_matricula (id_matricula, acao, usuario, detalhe)
        VALUES (NEW.id_matricula, 'INSERT', v_usuario,
                'aluno ' || NEW.id_aluno || ' na turma ' || NEW.id_turma
                || ' (' || NEW.status_matricula || ')');
    ELSIF NEW.status_matricula IS DISTINCT FROM OLD.status_matricula THEN
        INSERT INTO tb_log_matricula (id_matricula, acao, usuario, detalhe)
        VALUES (NEW.id_matricula, 'STATUS', v_usuario,
                OLD.status_matricula || ' -> ' || NEW.status_matricula);
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER tg_log_matricula
    AFTER INSERT OR UPDATE ON tb_matricula
    FOR EACH ROW EXECUTE FUNCTION fn_log_matricula();

-- =====================================================================
-- 2. ÍNDICES BÁSICOS (os de desempenho/estudo ficam em 07_indices.sql)
-- =====================================================================
-- POR QUÊ : o PostgreSQL cria índice automático para PK e UNIQUE, mas NÃO
--           para FK. Sem índice na coluna FK, "listar as turmas de uma
--           disciplina" e a checagem de DELETE no pai varrem a tabela
--           inteira. Só criamos o que ainda não está coberto: uma FK que
--           é a PRIMEIRA coluna de uma PK/UNIQUE já tem índice utilizável
--           (ex.: tb_matricula.id_aluno, tb_sala.id_campus,
--           tb_curriculo.id_curso).
CREATE INDEX ix_curso_campus   ON tb_curso (id_campus);
CREATE INDEX ix_cd_disciplina  ON tb_curriculo_disciplina (id_disciplina);
CREATE INDEX ix_pr_disciplina  ON tb_pre_requisito (id_disciplina);
CREATE INDEX ix_turma_disc     ON tb_turma (id_disciplina);
CREATE INDEX ix_turma_prof     ON tb_turma (id_professor);
CREATE INDEX ix_th_turma       ON tb_turma_horario (id_turma);
CREATE INDEX ix_aluno_curric   ON tb_aluno (id_curriculo);
CREATE INDEX ix_log_matricula  ON tb_log_matricula (id_matricula);

-- Índice PARCIAL: só as matrículas ativas. É o que o trigger de vagas
-- consulta a cada matrícula; fica pequeno porque ignora trancadas e
-- canceladas.
CREATE INDEX ix_matricula_turma_ativa ON tb_matricula (id_turma)
    WHERE status_matricula = 'MATRICULADO';

-- BRIN: a auditoria só cresce em ordem de data; um BRIN guarda só o
-- min/max por bloco de páginas (milhares de vezes menor que um B-tree)
-- e responde bem "o que aconteceu entre ontem e hoje".
CREATE INDEX ix_log_ocorrido ON tb_log_matricula USING brin (ocorrido_em);

-- Índice PARCIAL no histórico: só as matrículas já avaliadas (situação
-- diferente de CURSANDO). Atende consultas de reprovação e indicadores.
CREATE INDEX ix_historico_situacao ON tb_historico (situacao)
    WHERE situacao <> 'CURSANDO';

-- GIN: busca textual na ementa das disciplinas. B-tree não serve para
-- "qual disciplina fala de X"; o GIN é um índice invertido
-- (palavra -> linhas). to_tsvector('portuguese', ...) faz stemming
-- ("modelagem", "modelar" casam) e ignora stop words.
CREATE INDEX ix_disciplina_ementa_fts ON tb_disciplina
    USING gin (to_tsvector('portuguese', coalesce(ementa, '')));
