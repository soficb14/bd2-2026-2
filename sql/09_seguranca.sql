-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 09 - SEGURANÇA: PAPÉIS, GRANT/REVOKE E ROW-LEVEL SECURITY (Marco 2)
-- Frente: Administração e Operação  (modelo de 16 tabelas)
--
-- Regra de negócio que este script garante:
--   * ALUNO       enxerga e altera apenas o que é dele (própria linha em
--                 tb_aluno, próprias matrículas e PRÓPRIO histórico).
--                 Nunca o histórico de outro aluno.
--   * SECRETARIA  opera o sistema: lê tudo e escreve em alunos,
--                 matrículas, históricos e cadastros de oferta.
--   * COORDENACAO só lê (todos os dados acadêmicos e os indicadores),
--                 mas NÃO enxerga CPF nem data de nascimento dos alunos
--                 (privilégio por coluna).
--
-- Camadas (defesa em profundidade):
--   1) GRANT/REVOKE   - quem pode tocar em qual TABELA/COLUNA.
--   2) RLS (policies) - dentro da tabela, quais LINHAS cada um enxerga.
--   3) Views          - expõem agregados (vagas) sem abrir a tabela.
--
-- Rodar depois de 06_views.sql. Pode ser executado várias vezes.
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- 1. PAPÉIS (roles) DE GRUPO — não fazem login, só agrupam privilégios
-- ---------------------------------------------------------------------
-- Papéis são objetos do CLUSTER (não do banco): por isso o pg_dump do
-- banco NÃO os leva. No restore em outro servidor, restaurar também os
-- globais (ver docs/BACKUP_RESTAURACAO.md).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aluno')        THEN CREATE ROLE aluno        NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'secretaria')   THEN CREATE ROLE secretaria   NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'coordenacao')  THEN CREATE ROLE coordenacao  NOLOGIN; END IF;
END $$;

-- Usuários DE DEMONSTRAÇÃO (fazem login; senha 'demo' só para laboratório).
-- Convenção: o login de um aluno é a letra "a" + o CPF dele (tb_aluno não
-- tem matrícula); é assim que a RLS descobre quem está consultando
-- (ver fn_aluno_id). Os alunos 1 e 2 da carga têm os CPFs abaixo.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'a10000000001') THEN CREATE ROLE a10000000001 LOGIN PASSWORD 'demo' IN ROLE aluno; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'a10000000002') THEN CREATE ROLE a10000000002 LOGIN PASSWORD 'demo' IN ROLE aluno; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sec_maria')    THEN CREATE ROLE sec_maria    LOGIN PASSWORD 'demo' IN ROLE secretaria; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'coord_cco')    THEN CREATE ROLE coord_cco    LOGIN PASSWORD 'demo' IN ROLE coordenacao; END IF;
END $$;

-- ---------------------------------------------------------------------
-- 2. REVOKE: parte do zero (nada para PUBLIC) e depois concede o mínimo
-- ---------------------------------------------------------------------
REVOKE ALL ON ALL TABLES    IN SCHEMA academico FROM PUBLIC, aluno, secretaria, coordenacao;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA academico FROM PUBLIC, aluno, secretaria, coordenacao;
REVOKE ALL ON SCHEMA academico FROM PUBLIC;

GRANT USAGE ON SCHEMA academico TO aluno, secretaria, coordenacao;
-- (colunas IDENTITY não exigem privilégio na sequência: o INSERT basta)

-- ---------------------------------------------------------------------
-- 3. GRANT — cadastros de oferta (informação pública da instituição)
-- ---------------------------------------------------------------------
GRANT SELECT ON tb_campus, tb_curso, tb_curriculo, tb_disciplina,
                tb_curriculo_disciplina, tb_pre_requisito, tb_professor,
                tb_sala, tb_periodo_letivo, tb_turma, tb_turma_horario,
                tb_feriado
      TO aluno, secretaria, coordenacao;

-- Secretaria mantém a oferta (sem DELETE: apagar cadastro é decisão
-- administrativa, não rotina).
GRANT INSERT, UPDATE ON tb_turma, tb_turma_horario, tb_professor, tb_sala,
                        tb_disciplina, tb_curriculo_disciplina,
                        tb_pre_requisito, tb_feriado
      TO secretaria;

-- ---------------------------------------------------------------------
-- 4. GRANT — dados sensíveis dos alunos
-- ---------------------------------------------------------------------
-- tb_aluno: aluno e secretaria acessam a tabela inteira (a RLS limita as
-- linhas do aluno). Coordenação: por COLUNA, sem CPF e sem nascimento.
GRANT SELECT                  ON tb_aluno TO aluno;
GRANT SELECT, INSERT, UPDATE  ON tb_aluno TO secretaria;
GRANT SELECT (id_aluno, id_curriculo, nome_aluno, email_aluno, ingresso_aluno, ativo_aluno)
                              ON tb_aluno TO coordenacao;

-- tb_matricula:
--  * o aluno LÊ as próprias e pode se matricular (INSERT) nas colunas
--    da matrícula em si; a RLS exige que seja ele mesmo e ativa.
GRANT SELECT                  ON tb_matricula TO aluno, coordenacao;
GRANT INSERT (id_aluno, id_turma, data_matricula, status_matricula) ON tb_matricula TO aluno;
GRANT SELECT, INSERT, UPDATE  ON tb_matricula TO secretaria;

-- tb_historico (notas, frequência, média, situação):
--  * o aluno só LÊ o próprio (RLS); notas e frequência são lançadas
--    pela secretaria. A linha vazia é criada pelo trigger
--    tg_cria_historico (SECURITY DEFINER), não pelo aluno.
GRANT SELECT                  ON tb_historico TO aluno, coordenacao;
GRANT SELECT, INSERT, UPDATE  ON tb_historico TO secretaria;

-- tb_log_matricula: auditoria — aluno nunca vê; só o trigger escreve.
GRANT SELECT                  ON tb_log_matricula TO secretaria, coordenacao;

-- ---------------------------------------------------------------------
-- 5. GRANT — views e materialized view
-- ---------------------------------------------------------------------
-- vw_oferta_turmas e vw_vagas_turma rodam com os direitos do DONO da
-- view: o aluno vê "quantas vagas restam" sem poder ler a tabela
-- tb_matricula inteira (não vê quem está matriculado).
GRANT SELECT ON vw_oferta_turmas, vw_vagas_turma TO aluno, secretaria, coordenacao;
-- vw_historico_aluno é security_invoker: aplica a RLS de quem consulta.
GRANT SELECT ON vw_historico_aluno TO aluno, secretaria, coordenacao;
-- Indicadores agregados: só gestão.
GRANT SELECT ON mv_indicadores_curso TO secretaria, coordenacao;

-- ---------------------------------------------------------------------
-- 6. ROW-LEVEL SECURITY
-- ---------------------------------------------------------------------
-- Quem é o aluno logado? Login = "a" + CPF.
-- SECURITY DEFINER: precisa ler tb_aluno sem passar pela própria RLS dela
-- (senão a política dependeria dela mesma). Recebe o usuário como
-- PARÂMETRO porque, dentro de SECURITY DEFINER, current_user passa a ser
-- o dono da função, não quem chamou.
CREATE OR REPLACE FUNCTION fn_aluno_id(p_login text)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = academico, pg_temp
AS $$
    SELECT id_aluno FROM tb_aluno WHERE 'a' || cpf = lower(p_login)
$$;

REVOKE ALL ON FUNCTION fn_aluno_id(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_aluno_id(text) TO aluno, secretaria, coordenacao;

ALTER TABLE tb_aluno     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_matricula ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_historico ENABLE ROW LEVEL SECURITY;

-- Limpeza para poder rodar de novo
DROP POLICY IF EXISTS aluno_ve_a_si_mesmo         ON tb_aluno;
DROP POLICY IF EXISTS secretaria_total_aluno      ON tb_aluno;
DROP POLICY IF EXISTS coordenacao_le_aluno        ON tb_aluno;
DROP POLICY IF EXISTS aluno_ve_suas_matriculas    ON tb_matricula;
DROP POLICY IF EXISTS aluno_se_matricula          ON tb_matricula;
DROP POLICY IF EXISTS secretaria_total_matricula  ON tb_matricula;
DROP POLICY IF EXISTS coordenacao_le_matricula    ON tb_matricula;
DROP POLICY IF EXISTS aluno_ve_seu_historico      ON tb_historico;
DROP POLICY IF EXISTS secretaria_total_historico  ON tb_historico;
DROP POLICY IF EXISTS coordenacao_le_historico    ON tb_historico;

-- --- tb_aluno --------------------------------------------------------
CREATE POLICY aluno_ve_a_si_mesmo ON tb_aluno
    FOR SELECT TO aluno
    USING (id_aluno = fn_aluno_id(current_user));

CREATE POLICY secretaria_total_aluno ON tb_aluno
    FOR ALL TO secretaria USING (true) WITH CHECK (true);

CREATE POLICY coordenacao_le_aluno ON tb_aluno
    FOR SELECT TO coordenacao USING (true);

-- --- tb_matricula ----------------------------------------------------
CREATE POLICY aluno_ve_suas_matriculas ON tb_matricula
    FOR SELECT TO aluno
    USING (id_aluno = fn_aluno_id(current_user));

-- WITH CHECK: o aluno só consegue inserir matrícula EM SEU NOME e ativa.
CREATE POLICY aluno_se_matricula ON tb_matricula
    FOR INSERT TO aluno
    WITH CHECK (id_aluno = fn_aluno_id(current_user) AND status_matricula = 'MATRICULADO');

CREATE POLICY secretaria_total_matricula ON tb_matricula
    FOR ALL TO secretaria USING (true) WITH CHECK (true);

CREATE POLICY coordenacao_le_matricula ON tb_matricula
    FOR SELECT TO coordenacao USING (true);

-- --- tb_historico ----------------------------------------------------
-- É a regra central do edital: "aluno nunca vê o histórico de outro".
-- O histórico não tem id_aluno; a posse vem da matrícula (id_matricula).
-- A subconsulta usa tb_matricula, que já tem RLS própria para o aluno.
CREATE POLICY aluno_ve_seu_historico ON tb_historico
    FOR SELECT TO aluno
    USING (id_matricula IN (
        SELECT m.id_matricula FROM tb_matricula m
         WHERE m.id_aluno = fn_aluno_id(current_user)));

CREATE POLICY secretaria_total_historico ON tb_historico
    FOR ALL TO secretaria USING (true) WITH CHECK (true);

CREATE POLICY coordenacao_le_historico ON tb_historico
    FOR SELECT TO coordenacao USING (true);

-- A view vw_historico_aluno (security_invoker) herda essas regras.

-- ---------------------------------------------------------------------
-- 7. A ARMADILHA: RLS x trigger de vagas
-- ---------------------------------------------------------------------
-- fn_valida_vaga() conta as matrículas da turma. Com RLS ligada em
-- tb_matricula, quando QUEM CONSULTA é um aluno, essa contagem passaria a
-- enxergar só as matrículas DELE e subestimaria a ocupação — o limite
-- de vagas deixaria de funcionar justamente para quem se matricula
-- sozinho. Solução: a função roda com os direitos do dono (SECURITY
-- DEFINER, que enxerga todas as linhas) e com search_path fixo (evita
-- sequestro de nomes por quem chama).
ALTER FUNCTION fn_valida_vaga() SECURITY DEFINER SET search_path = academico, pg_temp;

-- ---------------------------------------------------------------------
-- 8. Conferência (rodar para mostrar na apresentação)
-- ---------------------------------------------------------------------
-- SELECT rolname, rolcanlogin FROM pg_roles
--  WHERE rolname IN ('aluno','secretaria','coordenacao','a10000000001','a10000000002','sec_maria','coord_cco');
-- SELECT tablename, policyname, roles, cmd FROM pg_policies WHERE schemaname='academico' ORDER BY 1,2;
-- Roteiro completo da demonstração: docs/roteiro_demo_seguranca.sql
