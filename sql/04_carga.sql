-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 04 - CARGA DE DADOS (modelo de 16 tabelas)
--
-- Ordem (respeita as FKs): campus, cursos, currículos, disciplinas, grade,
-- pré-requisitos, professores, salas, feriados, períodos, turmas,
-- horários, alunos, matrículas, histórico (notas) e log.
-- Média e situação NÃO são informadas no histórico: o banco calcula.
-- =====================================================================

SET search_path TO academico, public;

-- =====================================================================
-- 1. CAMPUS, CURSOS E CURRÍCULOS
-- =====================================================================
INSERT INTO tb_campus (nome_campus, cidade)
VALUES ('IESB Asa Sul',   'Brasília'),
       ('IESB Asa Norte', 'Brasília');

INSERT INTO tb_curso (id_campus, codigo, nome_curso, grau, ch_total_curso)
VALUES (1, 'CCO',  'Ciência da Computação',                 'BACHARELADO', 3200),
       (1, 'ENGC', 'Engenharia de Computação',              'BACHARELADO', 3600),
       (2, 'ADS',  'Análise e Desenvolvimento de Sistemas', 'TECNOLOGO',   2400);

-- Uma matriz ativa por curso (ids 1 a 3) e uma matriz antiga, inativa, de
-- CCO (id 4): mostra a regra "só uma matriz ativa por curso" funcionando.
INSERT INTO tb_curriculo (id_curso, ano_vigente, ativo_curriculo)
VALUES (1, 2024, TRUE),
       (2, 2024, TRUE),
       (3, 2024, TRUE),
       (1, 2020, FALSE);

-- =====================================================================
-- 2. DISCIPLINAS (ch_total_disciplina é calculada pelo banco)
-- =====================================================================
INSERT INTO tb_disciplina (codigo, nome, ch_teorico, ch_pratica, ementa)
VALUES
    ('ALG001', 'Algoritmos e Programação',          60, 30,
     'Fundamentos de algoritmos, lógica de programação e resolução de problemas.'),
    ('BD001',  'Banco de Dados',                    60, 30,
     'Modelagem de dados, SQL, sistemas gerenciadores de banco de dados e otimização.'),
    ('ED001',  'Estrutura de Dados',                60, 30,
     'Listas, pilhas, filas, árvores, tabelas hash e análise de algoritmos.'),
    ('POO001', 'Programação Orientada a Objetos',   60, 30,
     'Classes, objetos, encapsulamento, herança, polimorfismo e abstração.'),
    ('SO001',  'Sistemas Operacionais',             60, 30,
     'Processos, threads, gerenciamento de memória, arquivos e sistemas operacionais.'),
    ('WEB001', 'Desenvolvimento Web',               45, 45,
     'Desenvolvimento de aplicações web, APIs, interfaces e arquitetura cliente-servidor.'),
    ('ENG001', 'Engenharia de Software',            60, 30,
     'Processos de desenvolvimento, requisitos, arquitetura, testes e manutenção de software.');

-- =====================================================================
-- 3. GRADE: DISCIPLINAS DE CADA MATRIZ (currículo)
-- =====================================================================
-- CCO 2024 (currículo 1)
INSERT INTO tb_curriculo_disciplina (id_curriculo, id_disciplina, periodo, tipo)
VALUES (1,1,1,'OBRIGATORIA'), (1,2,2,'OBRIGATORIA'), (1,3,3,'OBRIGATORIA'),
       (1,4,3,'OBRIGATORIA'), (1,5,4,'OBRIGATORIA'), (1,6,4,'OPTATIVA'),
       (1,7,5,'OBRIGATORIA');
-- Engenharia de Computação 2024 (currículo 2)
INSERT INTO tb_curriculo_disciplina (id_curriculo, id_disciplina, periodo, tipo)
VALUES (2,1,1,'OBRIGATORIA'), (2,2,2,'OBRIGATORIA'), (2,3,3,'OBRIGATORIA'),
       (2,4,3,'OBRIGATORIA'), (2,5,4,'OBRIGATORIA');
-- ADS 2024 (currículo 3)
INSERT INTO tb_curriculo_disciplina (id_curriculo, id_disciplina, periodo, tipo)
VALUES (3,1,1,'OBRIGATORIA'), (3,2,2,'OBRIGATORIA'), (3,4,3,'OBRIGATORIA'),
       (3,6,3,'OBRIGATORIA'), (3,7,4,'OBRIGATORIA');
-- CCO 2020, matriz antiga e inativa (currículo 4)
INSERT INTO tb_curriculo_disciplina (id_curriculo, id_disciplina, periodo, tipo)
VALUES (4,1,1,'OBRIGATORIA'), (4,2,2,'OBRIGATORIA'), (4,3,3,'OBRIGATORIA'),
       (4,4,3,'OBRIGATORIA');

-- =====================================================================
-- 4. PRÉ-REQUISITOS  (id_requisito é exigido por id_disciplina)
-- =====================================================================
INSERT INTO tb_pre_requisito (id_requisito, id_disciplina, vinculo)
VALUES (1, 3, 'PRE_REQUISITO'),   -- Algoritmos -> Estrutura de Dados
       (1, 4, 'PRE_REQUISITO'),   -- Algoritmos -> POO
       (3, 5, 'PRE_REQUISITO'),   -- Estrutura de Dados -> SO
       (1, 6, 'PRE_REQUISITO'),   -- Algoritmos -> Web
       (4, 7, 'PRE_REQUISITO');   -- POO -> Engenharia de Software

-- =====================================================================
-- 5. PROFESSORES, SALAS E FERIADOS
-- =====================================================================
INSERT INTO tb_professor (matricula_professor, nome_professor, email_professor, titulacao)
VALUES
    ('PROF0001', 'Ana Carolina Silva',     'ana.silva@iesb.edu.br',     'Doutora'),
    ('PROF0002', 'Bruno Henrique Costa',   'bruno.costa@iesb.edu.br',   'Mestre'),
    ('PROF0003', 'Camila Oliveira Santos', 'camila.santos@iesb.edu.br', 'Doutora'),
    ('PROF0004', 'Daniel Martins Souza',   'daniel.souza@iesb.edu.br',  'Mestre'),
    ('PROF0005', 'Eduardo Alves Lima',     'eduardo.lima@iesb.edu.br',  'Especialista');

INSERT INTO tb_sala (id_campus, codigo, capacidade, tipo)
VALUES (1, 'A101',  60, 'TEORICA'),
       (1, 'A102',  60, 'TEORICA'),
       (1, 'LAB01', 40, 'LABORATORIO'),
       (2, 'B201',  60, 'TEORICA'),
       (2, 'LAB02', 40, 'LABORATORIO');

-- feriados nacionais do 2º semestre, cadastrados nos dois campi
INSERT INTO tb_feriado (id_campus, descricao, data)
SELECT c.id_campus, f.descricao, f.data
FROM tb_campus c
CROSS JOIN (VALUES
    ('Independência do Brasil',     DATE '2026-09-07'),
    ('Nossa Senhora Aparecida',     DATE '2026-10-12'),
    ('Finados',                     DATE '2026-11-02'),
    ('Proclamação da República',    DATE '2026-11-15'),
    ('Consciência Negra',           DATE '2026-11-20')
) AS f(descricao, data);

-- =====================================================================
-- 6. PERÍODOS LETIVOS, TURMAS E HORÁRIOS
-- =====================================================================
INSERT INTO tb_periodo_letivo (ano, semestre, data_inicio, data_fim)
VALUES (2026, 1, DATE '2026-02-02', DATE '2026-06-30'),
       (2026, 2, DATE '2026-08-03', DATE '2026-12-18');

INSERT INTO tb_turma (codigo, id_disciplina, id_periodo_letivo, id_professor, turno, vagas)
VALUES ('T01', 1, 2, 1, 'MATUTINO',   60),
       ('T02', 2, 2, 2, 'NOTURNO',    60),
       ('T03', 3, 2, 3, 'MATUTINO',   60),
       ('T04', 4, 2, 4, 'VESPERTINO', 60),
       ('T05', 5, 2, 5, 'NOTURNO',    60),
       ('T06', 6, 2, 1, 'MATUTINO',   60);

-- Turma extra, de propósito sem nenhuma matrícula: caso de demonstração
-- para a Consulta 3 (junção externa com agregação). Sem ela, todas as
-- turmas tinham matrícula e o efeito do LEFT JOIN (manter turma com
-- ocupadas = 0 em vez de sumir do relatório) não aparecia visualmente.
-- Segunda turma de BD001 (id_disciplina = 2), período vespertino.
INSERT INTO tb_turma (codigo, id_disciplina, id_periodo_letivo, id_professor, turno, vagas)
VALUES ('T07', 2, 2, 2, 'VESPERTINO', 30);

-- dia_semana ISO: 1=segunda ... 7=domingo
INSERT INTO tb_turma_horario (id_turma, id_sala, dia_semana, hora_inicio, hora_fim)
VALUES (1, 1, 1, '08:00', '10:00'),    -- T01 segunda
       (2, 2, 2, '19:00', '21:00'),    -- T02 terça
       (3, 3, 1, '10:00', '12:00'),    -- T03 segunda
       (4, 4, 3, '14:00', '16:00'),    -- T04 quarta
       (5, 5, 4, '19:00', '21:00'),    -- T05 quinta
       (6, 1, 5, '10:00', '12:00'),    -- T06 sexta
       (7, 1, 2, '08:00', '10:00');    -- T07 terça

-- =====================================================================
-- 7. ALUNOS (120)
-- =====================================================================
-- Cada aluno entra em uma matriz: os 3 cursos se alternam; os alunos de
-- CCO com g > 90 ficam na matriz antiga (currículo 4).
INSERT INTO tb_aluno
    (id_curriculo, cpf, nome_aluno, email_aluno, nascimento, ingresso_aluno, ativo_aluno)
SELECT
    CASE WHEN (g - 1) % 3 = 0 AND g > 90 THEN 4 ELSE ((g - 1) % 3) + 1 END,
    (10000000000 + g)::text,
    'Aluno ' || LPAD(g::text, 3, '0'),
    'aluno' || LPAD(g::text, 3, '0') || '@iesb.edu.br',
    DATE '1998-01-01' + ((g * 37) % 2500),
    2025,
    TRUE
FROM generate_series(1, 120) AS g;

-- =====================================================================
-- 8. MATRÍCULAS (300 = 50 alunos x 6 turmas)
-- =====================================================================
-- Dois triggers são desligados durante a carga:
--   * tg_log_matricula : o log inicial é inserido adiante com a DATA da
--     matrícula (e não a de hoje), o que espalha o log no tempo e permite
--     demonstrar o índice BRIN;
--   * tg_cria_historico: o histórico é inserido adiante já com as notas.
-- O trigger de vagas continua ligado (cada turma recebe 50 de 60 vagas).
ALTER TABLE tb_matricula DISABLE TRIGGER tg_log_matricula;
ALTER TABLE tb_matricula DISABLE TRIGGER tg_cria_historico;

INSERT INTO tb_matricula (id_aluno, id_turma, data_matricula, status_matricula)
SELECT
    ((g.aluno_seq + (t.turma_seq - 1) * 20 - 1) % 110) + 1,
    t.turma_seq,
    DATE '2026-08-01' + ((g.aluno_seq + t.turma_seq) % 25),
    'MATRICULADO'
FROM generate_series(1, 50) AS g(aluno_seq)
CROSS JOIN generate_series(1, 6) AS t(turma_seq)
ORDER BY (t.turma_seq - 1) * 50 + g.aluno_seq;      -- id_matricula = n (1 a 300)

ALTER TABLE tb_matricula ENABLE TRIGGER tg_log_matricula;
ALTER TABLE tb_matricula ENABLE TRIGGER tg_cria_historico;

-- =====================================================================
-- 9. HISTÓRICO: NOTAS E FREQUÊNCIA (1 por matrícula)
-- =====================================================================
-- n = id_matricula (1 a 300). p (0 a 9) é o "perfil" da matrícula e varia
-- de uma turma para outra (cada turma tem 5 matrículas de cada perfil):
--   0,1  sem notas ainda          -> CURSANDO
--   2,3  frequência 65% e 68%     -> REPROVADO_FALTA (P3 lançada)
--   4    notas baixas (2,0 a 4,9) -> REPROVADO_NOTA
--   5..9 notas de 5,0 a 10,0      -> APROVADO (ou REPROVADO_NOTA se a média ficar < 6)
-- A situação e a média NÃO são informadas: o banco calcula.
INSERT INTO tb_historico (id_matricula, nota_a1, nota_a2, nota_p3, frequencia)
SELECT
    m.id_matricula,
    CASE WHEN p IN (0, 1) THEN NULL
         WHEN p = 4       THEN round((2 + (n % 29) / 10.0)::numeric, 2)
         ELSE                  round((5 + (n % 51) / 10.0)::numeric, 2) END,
    CASE WHEN p IN (0, 1) THEN NULL
         WHEN p = 4       THEN round((2 + ((n * 7) % 29) / 10.0)::numeric, 2)
         ELSE                  round((5 + ((n * 7) % 51) / 10.0)::numeric, 2) END,
    CASE WHEN p IN (2, 3) THEN round((6 + ((n * 3) % 41) / 10.0)::numeric, 2)
         ELSE NULL END,
    CASE WHEN p = 2 THEN 65.00
         WHEN p = 3 THEN 68.00
         ELSE round((75 + (n % 26))::numeric, 2) END
FROM generate_series(1, 300) AS n
CROSS JOIN LATERAL
    (SELECT ((n - 1) / 50) + 1 AS turma_seq,
            ((n - 1) % 50) + 1 AS aluno_seq) AS s
CROSS JOIN LATERAL
    (SELECT (s.aluno_seq + 3 * s.turma_seq) % 10 AS p) AS x
JOIN tb_matricula m ON m.id_matricula = n;

-- =====================================================================
-- 10. LOG DE MATRÍCULA (carga inicial, com a data da matrícula)
-- =====================================================================
INSERT INTO tb_log_matricula (id_matricula, acao, ocorrido_em, detalhe)
SELECT m.id_matricula,
       'INSERT',
       m.data_matricula + TIME '08:00',
       'carga inicial: aluno ' || m.id_aluno || ' na turma ' || m.id_turma
         || ' (' || m.status_matricula || ')'
FROM tb_matricula m
ORDER BY m.id_matricula;

-- =====================================================================
-- FINALIZAÇÃO DA CARGA
-- =====================================================================
ANALYZE;
