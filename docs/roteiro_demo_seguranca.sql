-- =====================================================================
-- ROTEIRO DA DEMONSTRAÇÃO — SEGURANÇA / RLS  (rodar no Query Tool do
-- pgAdmin, banco marco3, conectado como bd2). Rode bloco a bloco.
-- Cada bloco diz o RESULTADO ESPERADO.
-- No modelo de 16 tabelas o histórico do aluno é tb_historico (notas,
-- frequência, média e situação), ligado ao aluno por tb_matricula;
-- vw_historico_aluno é a forma legível de lê-lo.
-- Login de aluno = "a" + CPF (aluno 1: a10000000001; aluno 2: a10000000002).
-- =====================================================================
SET search_path TO academico;

-- 0) Visão do dono (bd2, superusuário): enxerga tudo
RESET ROLE;
SELECT count(*) AS matriculas_visiveis_para_o_dono FROM tb_matricula;      -- 300

-- 1) ALUNO 1 (login a10000000001): só o PRÓPRIO histórico
SET ROLE a10000000001;
SELECT current_user;
SELECT count(*) AS matriculas_do_aluno1 FROM tb_matricula;                 -- 3
SELECT cpf_aluno, disciplina, media_geral, situacao FROM vw_historico_aluno;
                                                                           -- 3 linhas, só o CPF 10000000001
-- Tentar ver o histórico do aluno 2 de propósito:
SELECT * FROM vw_historico_aluno WHERE cpf_aluno = '10000000002';          -- 0 linhas (RLS esconde)
SELECT count(*) AS historicos_visiveis FROM tb_historico;                  -- 3 (só os dele)
SELECT count(*) AS alunos_visiveis FROM tb_aluno;                          -- 1 (ele mesmo)

-- 2) ALUNO 1 não pode alterar nota, nem ler o log, nem a MV
UPDATE tb_historico SET nota_a1 = 10;                                      -- ERRO: permission denied for table tb_historico
INSERT INTO tb_historico (id_matricula, nota_a1) VALUES (1, 10);           -- ERRO: permission denied (aluno não grava nota)
SELECT * FROM tb_log_matricula LIMIT 1;                                    -- ERRO: permission denied
SELECT * FROM mv_indicadores_curso;                                        -- ERRO: permission denied

-- 3) ALUNO 1 não pode matricular OUTRO aluno (WITH CHECK da RLS)
INSERT INTO tb_matricula (id_aluno, id_turma, status_matricula) VALUES (2, 7, 'MATRICULADO');
                                                                           -- ERRO: new row violates row-level security policy

-- 4) ALUNO 1 ainda enxerga vagas (agregado), sem ver quem está matriculado
SELECT turma, vagas, ocupadas, vagas_restantes FROM vw_vagas_turma ORDER BY turma;   -- 8 linhas (7 turmas da carga + CONC do script 08), valores globais

-- 5) COORDENAÇÃO: lê tudo, mas sem CPF/nascimento
RESET ROLE; SET ROLE coord_cco;
SELECT count(*) FROM tb_matricula;                                         -- 300
SELECT count(*) FROM tb_historico;                                         -- 300
SELECT nome_aluno, ingresso_aluno FROM tb_aluno LIMIT 3;                   -- OK
SELECT cpf FROM tb_aluno LIMIT 1;                                          -- ERRO: permission denied for table tb_aluno (coluna cpf)
SELECT * FROM mv_indicadores_curso ORDER BY curso;                         -- OK (3 linhas)
DELETE FROM tb_matricula;                                                  -- ERRO: permission denied

-- 6) SECRETARIA: opera (lança nota), mas não apaga
RESET ROLE; SET ROLE sec_maria;
SELECT count(*) FROM tb_matricula;                                         -- 300
SELECT cpf FROM tb_aluno LIMIT 1;                                          -- OK
UPDATE tb_historico SET nota_a1 = nota_a1 WHERE id_historico = 1;          -- OK (UPDATE 1)
DELETE FROM tb_matricula WHERE id_matricula = 1;                           -- ERRO: permission denied

-- 7) Volta ao dono
RESET ROLE;

-- 8) Auditoria do que está configurado (para mostrar ao professor)
SELECT tablename, policyname, roles, cmd FROM pg_policies
 WHERE schemaname = 'academico' ORDER BY tablename, policyname;            -- 10 policies
SELECT relname, relrowsecurity AS rls_ligada FROM pg_class
 WHERE relnamespace = 'academico'::regnamespace
   AND relname IN ('tb_aluno','tb_matricula','tb_historico');
