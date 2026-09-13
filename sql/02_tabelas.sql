-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 02 - TABELAS E RESTRIÇÕES ESTRUTURAIS
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- 1. ESTRUTURA INSTITUCIONAL
-- ---------------------------------------------------------------------

CREATE TABLE campus (
    id      SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome    VARCHAR(60) NOT NULL UNIQUE,
    cidade  VARCHAR(60) NOT NULL
);

CREATE TABLE curso (
    id         SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo     VARCHAR(10) NOT NULL UNIQUE,
    nome       VARCHAR(120) NOT NULL,
    grau       VARCHAR(20) NOT NULL
               CHECK (grau IN ('BACHARELADO', 'LICENCIATURA', 'TECNOLOGO')),
    ch_total   INTEGER NOT NULL CHECK (ch_total > 0),
    campus_id  SMALLINT NOT NULL
               REFERENCES campus ON DELETE RESTRICT
);

CREATE TABLE curriculo (
    id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    curso_id      SMALLINT NOT NULL
                  REFERENCES curso ON DELETE CASCADE,
    ano_vigencia  SMALLINT NOT NULL
                  CHECK (ano_vigencia BETWEEN 2000 AND 2100),
    ativo         BOOLEAN NOT NULL DEFAULT FALSE,

    UNIQUE (curso_id, ano_vigencia)
);

CREATE TABLE disciplina (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       VARCHAR(10) NOT NULL UNIQUE,
    nome         VARCHAR(120) NOT NULL,
    ch_teorica   SMALLINT NOT NULL CHECK (ch_teorica >= 0),
    ch_pratica   SMALLINT NOT NULL CHECK (ch_pratica >= 0),
    ch_total     SMALLINT GENERATED ALWAYS AS
                 (ch_teorica + ch_pratica) STORED,
    ementa       TEXT,

    CHECK (ch_teorica + ch_pratica > 0)
);

CREATE TABLE curriculo_disciplina (
    curriculo_id  INTEGER NOT NULL
                  REFERENCES curriculo ON DELETE CASCADE,
    disciplina_id INTEGER NOT NULL
                  REFERENCES disciplina ON DELETE RESTRICT,
    periodo       SMALLINT NOT NULL
                  CHECK (periodo BETWEEN 1 AND 12),
    tipo          tipo_disc_t NOT NULL DEFAULT 'OBRIGATORIA',

    PRIMARY KEY (curriculo_id, disciplina_id)
);

CREATE TABLE pre_requisito (
    disciplina_id INTEGER NOT NULL
                   REFERENCES disciplina ON DELETE CASCADE,
    requisito_id  INTEGER NOT NULL
                   REFERENCES disciplina ON DELETE RESTRICT,
    vinculo       vinculo_t NOT NULL DEFAULT 'PRE_REQUISITO',

    PRIMARY KEY (disciplina_id, requisito_id),

    CHECK (disciplina_id <> requisito_id)
);

CREATE TABLE professor (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula  VARCHAR(12) NOT NULL UNIQUE,
    nome       VARCHAR(120) NOT NULL,
    email      VARCHAR(120) NOT NULL UNIQUE
               CHECK (
                   email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$'
               ),
    titulacao  VARCHAR(20) NOT NULL
               CHECK (titulacao IN ('ESPECIALISTA', 'MESTRE', 'DOUTOR'))
);

CREATE TABLE sala (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    campus_id   SMALLINT NOT NULL
                REFERENCES campus ON DELETE RESTRICT,
    codigo      VARCHAR(10) NOT NULL,
    capacidade  SMALLINT NOT NULL CHECK (capacidade > 0),
    tipo        tipo_sala_t NOT NULL DEFAULT 'TEORICA',

    UNIQUE (campus_id, codigo)
);

-- ---------------------------------------------------------------------
-- 2. OFERTA
-- ---------------------------------------------------------------------

CREATE TABLE periodo_letivo (
    id           SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ano          SMALLINT NOT NULL,
    semestre     SMALLINT NOT NULL CHECK (semestre IN (1, 2)),
    data_inicio  DATE NOT NULL,
    data_fim     DATE NOT NULL,

    UNIQUE (ano, semestre),

    CHECK (data_fim > data_inicio)
);

CREATE TABLE feriado (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data       DATE NOT NULL,
    descricao  VARCHAR(120) NOT NULL,
    campus_id  SMALLINT
               REFERENCES campus ON DELETE CASCADE,

    UNIQUE (data, campus_id)
);

CREATE TABLE turma (
    id                 INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo             VARCHAR(15) NOT NULL,
    disciplina_id      INTEGER NOT NULL
                       REFERENCES disciplina ON DELETE RESTRICT,
    periodo_letivo_id  SMALLINT NOT NULL
                       REFERENCES periodo_letivo ON DELETE RESTRICT,
    professor_id       INTEGER
                       REFERENCES professor ON DELETE SET NULL,
    turno              turno_t NOT NULL,
    vagas              SMALLINT NOT NULL CHECK (vagas > 0),

    UNIQUE (codigo, periodo_letivo_id, disciplina_id)
);

CREATE TABLE turma_horario (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    turma_id    INTEGER NOT NULL
                REFERENCES turma ON DELETE CASCADE,
    sala_id     INTEGER NOT NULL
                REFERENCES sala ON DELETE RESTRICT,
    dia_semana  SMALLINT NOT NULL
                CHECK (dia_semana BETWEEN 1 AND 7),
    faixa       timerange NOT NULL,

    CHECK (NOT isempty(faixa))
);

-- ---------------------------------------------------------------------
-- 3. VIDA ACADÊMICA
-- ---------------------------------------------------------------------

CREATE TABLE aluno (
    id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula     VARCHAR(12) NOT NULL UNIQUE,
    nome          VARCHAR(120) NOT NULL,
    cpf           CHAR(11) NOT NULL UNIQUE
                  CHECK (cpf ~ '^[0-9]{11}$'),
    email         VARCHAR(120) NOT NULL UNIQUE,
    nascimento    DATE NOT NULL
                  CHECK (nascimento < CURRENT_DATE),
    curso_id      SMALLINT NOT NULL
                  REFERENCES curso ON DELETE RESTRICT,
    curriculo_id  INTEGER NOT NULL
                  REFERENCES curriculo ON DELETE RESTRICT,
    ingresso      DATE NOT NULL,
    ativo         BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE matricula (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    aluno_id        INTEGER NOT NULL
                    REFERENCES aluno ON DELETE CASCADE,
    turma_id        INTEGER NOT NULL
                    REFERENCES turma ON DELETE RESTRICT,
    data_matricula  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          status_mat_t NOT NULL DEFAULT 'MATRICULADO',

    UNIQUE (aluno_id, turma_id)
);

CREATE TABLE historico (
    id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula_id  INTEGER NOT NULL UNIQUE
                  REFERENCES matricula ON DELETE CASCADE,
    nota_a1       nota_t,
    nota_a2       nota_t,
    nota_p3       nota_t,
    frequencia    pct_t NOT NULL DEFAULT 100,
    situacao      situacao_t NOT NULL DEFAULT 'CURSANDO',

    media_final   NUMERIC(4,2) GENERATED ALWAYS AS (
        CASE
            WHEN nota_a1 IS NULL OR nota_a2 IS NULL THEN NULL

            WHEN nota_p3 IS NULL THEN
                ROUND(0.4 * nota_a1 + 0.6 * nota_a2, 2)

            ELSE
                ROUND(
                    GREATEST(
                        0.4 * nota_p3 + 0.6 * nota_a2,
                        0.4 * nota_a1 + 0.6 * nota_p3
                    ),
                    2
                )
        END
    ) STORED
);

CREATE TABLE log_matricula (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula_id  INTEGER NOT NULL,
    acao          VARCHAR(20) NOT NULL,
    ocorrido_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    usuario       NAME NOT NULL DEFAULT CURRENT_USER,
    detalhe       JSONB
);