-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 04 - CARGA DE DADOS (Marco 1)
-- Autor original: Sofia (branch feat/modelo-fisico, como
-- sql/00_dados_projeto.sql) — renumerado para 04_carga.sql para
-- respeitar a ordem de execução exigida no edital (scripts numerados
-- na ordem em que rodam: 01_tipos -> 02_tabelas -> 03_restricoes ->
-- 04_carga -> 05_consultas). O conteúdo é o mesmo, só o número mudou.
--
-- Objetivo:
--   Construir um cenário de dados próprio para o Marco 1.
--
-- Ordem:
--   1. Dados estruturais
--   2. Alunos
--   3. Turmas
--   4. Matrículas
--   5. Históricos
-- =====================================================================

SET search_path TO academico, public;


-- =====================================================================
-- 1. CAMPI
-- =====================================================================

INSERT INTO campus (nome, cidade)
VALUES
    ('Campus Asa Sul', 'Brasília'),
    ('Campus Norte', 'Brasília');


-- =====================================================================
-- 2. CURSOS
-- =====================================================================

INSERT INTO curso (
    codigo,
    nome,
    grau,
    ch_total,
    campus_id
)
VALUES
    ('CCO', 'Ciência da Computação', 'BACHARELADO', 3200, 1),
    ('ENGC', 'Engenharia de Computação', 'BACHARELADO', 3600, 1),
    ('ADS', 'Análise e Desenvolvimento de Sistemas', 'TECNOLOGO', 2200, 2);


-- =====================================================================
-- 3. CURRÍCULOS
-- =====================================================================
-- O curso CCO possui dois currículos para demonstrar a regra de
-- currículo ativo/inativo.
--
-- Apenas um currículo de cada curso deve permanecer ativo.

INSERT INTO curriculo (
    curso_id,
    ano_vigencia,
    ativo
)
VALUES
    (1, 2025, false),
    (1, 2026, true),
    (2, 2026, true),
    (3, 2026, true);


-- =====================================================================
-- 4. DISCIPLINAS
-- =====================================================================

INSERT INTO disciplina (
    codigo,
    nome,
    ch_teorica,
    ch_pratica,
    ementa
)
VALUES
    (
        'ALG001',
        'Algoritmos e Programação',
        60,
        30,
        'Fundamentos de algoritmos, lógica de programação e resolução de problemas.'
    ),
    (
        'BD001',
        'Banco de Dados',
        60,
        30,
        'Modelagem de dados, SQL, sistemas gerenciadores de banco de dados e otimização.'
    ),
    (
        'ED001',
        'Estrutura de Dados',
        60,
        30,
        'Listas, pilhas, filas, árvores, tabelas hash e análise de algoritmos.'
    ),
    (
        'POO001',
        'Programação Orientada a Objetos',
        60,
        30,
        'Classes, objetos, encapsulamento, herança, polimorfismo e abstração.'
    ),
    (
        'SO001',
        'Sistemas Operacionais',
        60,
        30,
        'Processos, threads, gerenciamento de memória, arquivos e sistemas operacionais.'
    ),
    (
        'WEB001',
        'Desenvolvimento Web',
        45,
        45,
        'Desenvolvimento de aplicações web, APIs, interfaces e arquitetura cliente-servidor.'
    ),
    (
        'ENG001',
        'Engenharia de Software',
        60,
        30,
        'Processos de desenvolvimento, requisitos, arquitetura, testes e manutenção de software.'
    );


-- =====================================================================
-- 5. DISCIPLINAS DOS CURRÍCULOS
-- =====================================================================

-- CCO - currículo 2026
INSERT INTO curriculo_disciplina (
    curriculo_id,
    disciplina_id,
    periodo,
    tipo
)
VALUES
    (2, 1, 1, 'OBRIGATORIA'),
    (2, 2, 2, 'OBRIGATORIA'),
    (2, 3, 3, 'OBRIGATORIA'),
    (2, 4, 3, 'OBRIGATORIA'),
    (2, 5, 4, 'OBRIGATORIA'),
    (2, 6, 4, 'OPTATIVA'),
    (2, 7, 5, 'OBRIGATORIA');


-- Engenharia de Computação - currículo 2026
INSERT INTO curriculo_disciplina (
    curriculo_id,
    disciplina_id,
    periodo,
    tipo
)
VALUES
    (3, 1, 1, 'OBRIGATORIA'),
    (3, 2, 2, 'OBRIGATORIA'),
    (3, 3, 3, 'OBRIGATORIA'),
    (3, 4, 3, 'OBRIGATORIA'),
    (3, 5, 4, 'OBRIGATORIA');


-- ADS - currículo 2026
INSERT INTO curriculo_disciplina (
    curriculo_id,
    disciplina_id,
    periodo,
    tipo
)
VALUES
    (4, 1, 1, 'OBRIGATORIA'),
    (4, 2, 2, 'OBRIGATORIA'),
    (4, 4, 3, 'OBRIGATORIA'),
    (4, 6, 3, 'OBRIGATORIA'),
    (4, 7, 4, 'OBRIGATORIA');


-- =====================================================================
-- 6. PRÉ-REQUISITOS
-- =====================================================================


INSERT INTO pre_requisito (
    disciplina_id,
    requisito_id,
    vinculo
)
VALUES
    (3, 1, 'PRE_REQUISITO'),
    (4, 1, 'PRE_REQUISITO'),
    (5, 3, 'PRE_REQUISITO'),
    (6, 1, 'PRE_REQUISITO'),
    (7, 4, 'PRE_REQUISITO');


-- ============================================================
-- 7. PROFESSORES
-- ============================================================


INSERT INTO professor
    (matricula, nome, email, titulacao)
VALUES
    ('PROF0001', 'Ana Carolina Silva', 'ana.silva@iesb.edu.br', 'DOUTOR'),
    ('PROF0002', 'Bruno Henrique Costa', 'bruno.costa@iesb.edu.br', 'MESTRE'),
    ('PROF0003', 'Camila Oliveira Santos', 'camila.santos@iesb.edu.br', 'DOUTOR'),
    ('PROF0004', 'Daniel Martins Souza', 'daniel.souza@iesb.edu.br', 'MESTRE'),
    ('PROF0005', 'Eduardo Alves Lima', 'eduardo.lima@iesb.edu.br', 'ESPECIALISTA');


-- ============================================================
-- 8. SALAS
-- ============================================================


INSERT INTO sala
    (campus_id, codigo, capacidade, tipo)
VALUES
    (1, 'A101', 60, 'TEORICA'),
    (1, 'A102', 60, 'TEORICA'),
    (1, 'LAB01', 40, 'LABORATORIO'),
    (2, 'B201', 60, 'TEORICA'),
    (2, 'LAB02', 40, 'LABORATORIO');


-- ============================================================
-- 9. PERÍODOS LETIVOS
-- ============================================================


INSERT INTO periodo_letivo
    (ano, semestre, data_inicio, data_fim)
VALUES
    (2026, 1, DATE '2026-02-02', DATE '2026-06-30'),
    (2026, 2, DATE '2026-08-03', DATE '2026-12-18');


-- ============================================================
-- 10. FERIADOS
-- ============================================================


INSERT INTO feriado
    (data, descricao, campus_id)
VALUES
    (DATE '2026-02-16', 'Carnaval', NULL),
    (DATE '2026-02-17', 'Carnaval', NULL),
    (DATE '2026-04-03', 'Sexta-feira Santa', NULL),
    (DATE '2026-04-21', 'Tiradentes', NULL),
    (DATE '2026-05-01', 'Dia do Trabalho', NULL),
    (DATE '2026-09-07', 'Independência do Brasil', NULL),
    (DATE '2026-10-12', 'Nossa Senhora Aparecida', NULL),
    (DATE '2026-11-02', 'Finados', NULL),
    (DATE '2026-11-15', 'Proclamação da República', NULL),
    (DATE '2026-11-20', 'Dia da Consciência Negra', NULL);


-- ============================================================
-- 11. TURMAS
-- ============================================================


INSERT INTO turma
    (codigo, disciplina_id, periodo_letivo_id, professor_id, turno, vagas)
VALUES
    ('T01', 1, 2, 1, 'MATUTINO',   60),
    ('T02', 2, 2, 2, 'NOTURNO',    60),
    ('T03', 3, 2, 3, 'MATUTINO',   60),
    ('T04', 4, 2, 4, 'VESPERTINO', 60),
    ('T05', 5, 2, 5, 'NOTURNO',    60),
    ('T06', 6, 2, 1, 'MATUTINO',   60);

-- Turma extra, de propósito sem nenhuma matrícula: caso de demonstração
-- para a Consulta 3 (junção externa com agregação). Sem ela, todas as
-- turmas tinham matrícula e o efeito do LEFT JOIN (manter turma com
-- ocupadas = 0 em vez de sumir do relatório) não aparecia visualmente.
-- Segunda turma de BD001 (disciplina_id = 2), período vespertino.
INSERT INTO turma
    (codigo, disciplina_id, periodo_letivo_id, professor_id, turno, vagas)
VALUES
    ('T07', 2, 2, 2, 'VESPERTINO', 30);


-- ============================================================
-- 12. HORÁRIOS DAS TURMAS
-- ============================================================


INSERT INTO turma_horario
    (turma_id, sala_id, dia_semana, faixa)
VALUES
    (1, 1, 2, '[08:00,10:00)'),
    (2, 2, 3, '[19:00,21:00)'),
    (3, 3, 2, '[10:00,12:00)'),
    (4, 4, 4, '[14:00,16:00)'),
    (5, 5, 5, '[19:00,21:00)'),
    (6, 1, 6, '[10:00,12:00)'),
    (7, 1, 3, '[08:00,10:00)');


-- ============================================================
-- 13. ALUNOS
-- ============================================================


INSERT INTO aluno
    (matricula, nome, cpf, email, nascimento,
     curso_id, curriculo_id, ingresso, ativo)
SELECT
    'ALU2026' || LPAD(g::text, 4, '0'),
    'Aluno ' || LPAD(g::text, 3, '0'),
    (10000000000 + g)::text,
    'aluno' || LPAD(g::text, 3, '0') || '@iesb.edu.br',
    DATE '1998-01-01' + ((g * 37) % 2500),
    CASE ((g - 1) % 3)
        WHEN 0 THEN 1
        WHEN 1 THEN 2
        ELSE 3
    END,
    CASE ((g - 1) % 3)
        WHEN 0 THEN 2
        WHEN 1 THEN 3
        ELSE 4
    END,
    DATE '2025-02-03' + ((g - 1) % 30),
    TRUE
FROM generate_series(1, 120) AS g;


-- ============================================================
-- 14. MATRÍCULAS
-- ============================================================


INSERT INTO matricula
    (aluno_id, turma_id, data_matricula, status)
SELECT
    ((g.aluno_seq + (t.turma_seq - 1) * 20 - 1) % 110) + 1,
    t.turma_seq,
    TIMESTAMPTZ '2026-08-01 08:00:00'
        + ((g.aluno_seq + t.turma_seq) % 25) * INTERVAL '1 day',
    'MATRICULADO'
FROM
    generate_series(1, 50) AS g(aluno_seq)
CROSS JOIN
    generate_series(1, 6) AS t(turma_seq);


-- ============================================================
-- 15. HISTÓRICO
-- ============================================================

INSERT INTO historico
    (matricula_id, nota_a1, nota_a2, nota_p3, frequencia, situacao)
SELECT
    m.id,

    CASE
        WHEN m.id % 10 IN (0, 1) THEN NULL
        ELSE round((5 + (m.id % 51) / 10.0)::numeric, 2)
    END,

    CASE
        WHEN m.id % 10 IN (0, 1) THEN NULL
        ELSE round((5 + ((m.id * 7) % 51) / 10.0)::numeric, 2)
    END,

    CASE
        WHEN m.id % 10 IN (2, 3) THEN
            round((6 + ((m.id * 3) % 41) / 10.0)::numeric, 2)
        ELSE NULL
    END,

    CASE
        WHEN m.id % 10 = 2 THEN 65.00
        WHEN m.id % 10 = 3 THEN 68.00
        ELSE round((75 + (m.id % 26))::numeric, 2)
    END,

    (
        CASE
            WHEN m.id % 10 IN (0, 1) THEN 'CURSANDO'
            WHEN m.id % 10 = 2 THEN 'REPROVADO_FALTA'
            WHEN m.id % 10 IN (3, 4) THEN 'REPROVADO_NOTA'
            ELSE 'APROVADO'
        END
    )::academico.situacao_t

FROM matricula m;


-- ============================================================
-- 16. LOGS DE MATRÍCULA
-- ============================================================


INSERT INTO log_matricula
    (matricula_id, acao, ocorrido_em, usuario, detalhe)
SELECT
    m.id,
    'MATRICULA',
    m.data_matricula,
    current_user,
    jsonb_build_object(
        'origem', 'carga_inicial',
        'turma_id', m.turma_id,
        'aluno_id', m.aluno_id,
        'status', m.status
    )
FROM matricula m;


-- ============================================================
-- FINALIZAÇÃO DA CARGA
-- ============================================================

ANALYZE;
