-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 02 - TABELAS (16) com chaves, UNIQUE, CHECK e colunas calculadas
-- Pré-requisito: 01_tipos.sql
-- =====================================================================

SET search_path TO academico, public;

-- =====================================================================
-- 3. ESTRUTURA INSTITUCIONAL E DISCIPLINAS
-- =====================================================================
-- Convenções valem para todas as tabelas:
--  * PK "integer GENERATED ALWAYS AS IDENTITY": o próprio banco gera o id
--    (padrão SQL, substitui o antigo serial). ALWAYS impede que alguém
--    force um id manualmente por engano; para cargas com id fixo use
--    INSERT ... OVERRIDING SYSTEM VALUE.
--  * Toda restrição tem NOME (pk_, fk_, uq_, ck_): a mensagem de erro
--    diz exatamente qual regra foi violada.
--  * FK sem ON DELETE = RESTRICT (padrão): não se apaga o "pai" que ainda
--    tem "filhos". CASCADE só é usado em tabela puramente dependente.

-- ---- tb_campus -------------------------------------------------------
-- POR QUÊ : a instituição tem mais de uma unidade; salas, cursos e
--           feriados pertencem a um campus.
-- O QUE   : nome do campus é único (não existem dois "Campus Sul").
CREATE TABLE tb_campus (
    id_campus    integer GENERATED ALWAYS AS IDENTITY,
    nome_campus  varchar(120) NOT NULL,
    cidade       varchar(120) NOT NULL,
    CONSTRAINT pk_campus      PRIMARY KEY (id_campus),
    CONSTRAINT uq_campus_nome UNIQUE (nome_campus)
);

-- ---- tb_curso --------------------------------------------------------
-- POR QUÊ : cada curso é oferecido em um campus e tem um código oficial.
-- O QUE   : codigo único; carga horária total deve ser positiva.
-- COMO    : FK id_campus RESTRICT — não dá para apagar um campus que
--           ainda tenha cursos.
CREATE TABLE tb_curso (
    id_curso        integer GENERATED ALWAYS AS IDENTITY,
    id_campus       integer      NOT NULL,
    codigo          varchar(120) NOT NULL,
    nome_curso      varchar(120) NOT NULL,
    grau            varchar(50)  NOT NULL,            -- bacharelado, licenciatura, tecnólogo...
    ch_total_curso  integer      NOT NULL,
    CONSTRAINT pk_curso        PRIMARY KEY (id_curso),
    CONSTRAINT uq_curso_codigo UNIQUE (codigo),
    CONSTRAINT fk_curso_campus FOREIGN KEY (id_campus) REFERENCES tb_campus (id_campus),
    CONSTRAINT ck_curso_ch     CHECK (ch_total_curso > 0)
);

-- ---- tb_curriculo ----------------------------------------------------
-- POR QUÊ : um curso muda de grade com o tempo (matriz 2019, matriz 2024).
--           O aluno fica preso à matriz em que ingressou.
-- O QUE   : (curso, ano) é único; e só UMA matriz ativa por curso.
-- COMO    : o índice único PARCIAL (WHERE ativo_curriculo) só indexa as
--           linhas ativas; assim duas ativas do mesmo curso colidem, mas
--           qualquer quantidade de inativas é permitida.
CREATE TABLE tb_curriculo (
    id_curriculo     integer GENERATED ALWAYS AS IDENTITY,
    id_curso         integer  NOT NULL,
    ano_vigente      smallint NOT NULL,
    ativo_curriculo  boolean  NOT NULL DEFAULT true,
    CONSTRAINT pk_curriculo       PRIMARY KEY (id_curriculo),
    CONSTRAINT fk_curriculo_curso FOREIGN KEY (id_curso) REFERENCES tb_curso (id_curso),
    CONSTRAINT uq_curriculo_ano   UNIQUE (id_curso, ano_vigente),
    CONSTRAINT ck_curriculo_ano   CHECK (ano_vigente BETWEEN 1990 AND 2100)
);
CREATE UNIQUE INDEX uq_curriculo_ativo ON tb_curriculo (id_curso) WHERE ativo_curriculo;

-- ---- tb_disciplina ---------------------------------------------------
-- POR QUÊ : catálogo único de disciplinas, reaproveitado por várias
--           matrizes (a mesma "Banco de Dados II" serve a vários cursos).
-- O QUE   : ch_total_disciplina é CALCULADA = teórica + prática.
-- COMO    : "GENERATED ALWAYS AS (...) STORED" — o banco calcula e grava;
--           ninguém consegue inserir um total inconsistente.
CREATE TABLE tb_disciplina (
    id_disciplina        integer GENERATED ALWAYS AS IDENTITY,
    codigo               varchar(20)  NOT NULL,
    nome                 varchar(120) NOT NULL,
    ch_teorico           smallint     NOT NULL DEFAULT 0,
    ch_pratica           smallint     NOT NULL DEFAULT 0,
    ch_total_disciplina  smallint GENERATED ALWAYS AS (ch_teorico + ch_pratica) STORED,
    ementa               text,
    CONSTRAINT pk_disciplina        PRIMARY KEY (id_disciplina),
    CONSTRAINT uq_disciplina_codigo UNIQUE (codigo),
    CONSTRAINT uq_disciplina_nome   UNIQUE (nome),
    CONSTRAINT ck_disciplina_ch     CHECK (ch_teorico >= 0 AND ch_pratica >= 0
                                           AND ch_teorico + ch_pratica > 0)
);

-- ---- tb_curriculo_disciplina (associativa N:N) ----------------------
-- POR QUÊ : uma matriz tem várias disciplinas e uma disciplina está em
--           várias matrizes -> relação N:N vira tabela própria.
-- O QUE   : PK composta (currículo + disciplina) impede repetir a
--           disciplina na mesma matriz. Guarda o período sugerido e se é
--           obrigatória ou optativa NAQUELA matriz.
-- COMO    : CASCADE no currículo: se a matriz é removida, a lista de
--           disciplinas dela perde o sentido. A disciplina em si é
--           RESTRICT (não se apaga disciplina que está em matriz).
CREATE TABLE tb_curriculo_disciplina (
    id_curriculo   integer     NOT NULL,
    id_disciplina  integer     NOT NULL,
    periodo        smallint    NOT NULL,
    tipo           tipo_disc_t NOT NULL DEFAULT 'OBRIGATORIA',
    CONSTRAINT pk_curriculo_disciplina PRIMARY KEY (id_curriculo, id_disciplina),
    CONSTRAINT fk_cd_curriculo  FOREIGN KEY (id_curriculo)  REFERENCES tb_curriculo  (id_curriculo) ON DELETE CASCADE,
    CONSTRAINT fk_cd_disciplina FOREIGN KEY (id_disciplina) REFERENCES tb_disciplina (id_disciplina),
    CONSTRAINT ck_cd_periodo    CHECK (periodo BETWEEN 1 AND 12)
);

-- ---- tb_pre_requisito (auto-relacionamento N:N) ---------------------
-- POR QUÊ : "para cursar X é preciso ter feito Y" (ou cursar junto).
-- O QUE   : id_disciplina = a disciplina que EXIGE; id_requisito = a que
--           é exigida; vinculo diz se é pré ou co-requisito.
-- COMO    : as duas colunas apontam para tb_disciplina. O CHECK impede
--           que uma disciplina seja requisito de si mesma.
CREATE TABLE tb_pre_requisito (
    id_requisito   integer    NOT NULL,
    id_disciplina  integer    NOT NULL,
    vinculo        vinculo_t  NOT NULL DEFAULT 'PRE_REQUISITO',
    CONSTRAINT pk_pre_requisito PRIMARY KEY (id_requisito, id_disciplina),
    CONSTRAINT fk_pr_requisito  FOREIGN KEY (id_requisito)  REFERENCES tb_disciplina (id_disciplina) ON DELETE CASCADE,
    CONSTRAINT fk_pr_disciplina FOREIGN KEY (id_disciplina) REFERENCES tb_disciplina (id_disciplina) ON DELETE CASCADE,
    CONSTRAINT ck_pr_distintas  CHECK (id_requisito <> id_disciplina)
);

-- ---- tb_professor ----------------------------------------------------
-- POR QUÊ : docente é identificado por matrícula funcional e e-mail
--           institucional; ambos não podem repetir.
CREATE TABLE tb_professor (
    id_professor         integer GENERATED ALWAYS AS IDENTITY,
    matricula_professor  varchar(20)  NOT NULL,
    nome_professor       varchar(120) NOT NULL,
    email_professor      varchar(120) NOT NULL,
    titulacao            varchar(120),                -- opcional: nem todo cadastro tem
    CONSTRAINT pk_professor           PRIMARY KEY (id_professor),
    CONSTRAINT uq_professor_matricula UNIQUE (matricula_professor),
    CONSTRAINT uq_professor_email     UNIQUE (email_professor),
    CONSTRAINT ck_professor_email     CHECK (email_professor LIKE '_%@_%._%')
);

-- ---- tb_sala ---------------------------------------------------------
-- POR QUÊ : sala pertence a um campus; o código ("B-201") só precisa ser
--           único DENTRO do campus.
-- O QUE   : UNIQUE (id_campus, codigo) em vez de UNIQUE (codigo).
CREATE TABLE tb_sala (
    id_sala     integer GENERATED ALWAYS AS IDENTITY,
    id_campus   integer      NOT NULL,
    codigo      varchar(20)  NOT NULL,
    capacidade  smallint     NOT NULL,
    tipo        tipo_sala_t  NOT NULL DEFAULT 'TEORICA',
    CONSTRAINT pk_sala        PRIMARY KEY (id_sala),
    CONSTRAINT fk_sala_campus FOREIGN KEY (id_campus) REFERENCES tb_campus (id_campus),
    CONSTRAINT uq_sala_codigo UNIQUE (id_campus, codigo),
    CONSTRAINT ck_sala_cap    CHECK (capacidade > 0)
);

-- =====================================================================
-- 4. OFERTA: PERÍODO, TURMA E HORÁRIO
-- =====================================================================
-- ---- tb_periodo_letivo ----------------------------------------------
-- POR QUÊ : toda turma acontece em um semestre (2026/2, 2027/1...).
-- O QUE   : (ano, semestre) único; semestre só 1 ou 2; fim depois do
--           início; e dois períodos NÃO podem se sobrepor no calendário.
-- COMO    : EXCLUDE com daterange(...) && é a "unique" para intervalos:
--           rejeita qualquer linha cujo intervalo de datas encoste em
--           outro já existente. '[]' = extremos inclusos.
CREATE TABLE tb_periodo_letivo (
    id_periodo_letivo  integer GENERATED ALWAYS AS IDENTITY,
    ano                smallint NOT NULL,
    semestre           smallint NOT NULL,
    data_inicio        date     NOT NULL,
    data_fim           date     NOT NULL,
    CONSTRAINT pk_periodo_letivo PRIMARY KEY (id_periodo_letivo),
    CONSTRAINT uq_periodo        UNIQUE (ano, semestre),
    CONSTRAINT ck_periodo_sem    CHECK (semestre IN (1, 2)),
    CONSTRAINT ck_periodo_datas  CHECK (data_fim > data_inicio),
    CONSTRAINT ex_periodo_sobrep EXCLUDE USING gist
        (daterange(data_inicio, data_fim, '[]') WITH &&)
);

-- ---- tb_turma --------------------------------------------------------
-- POR QUÊ : turma = uma disciplina, ofertada em um período, por um
--           professor, com número limitado de vagas.
-- O QUE   : o código da turma ("A", "N01") é único dentro de
--           (período + disciplina). vagas > 0.
-- COMO    : três FKs RESTRICT: não se apaga professor, disciplina ou
--           período que ainda tenham turmas.
CREATE TABLE tb_turma (
    id_turma           integer GENERATED ALWAYS AS IDENTITY,
    id_disciplina      integer     NOT NULL,
    id_periodo_letivo  integer     NOT NULL,
    id_professor       integer     NOT NULL,
    codigo             varchar(20) NOT NULL,
    turno              turno_t     NOT NULL,               -- (no desenho: "tuno")
    vagas              smallint    NOT NULL,
    CONSTRAINT pk_turma            PRIMARY KEY (id_turma),
    CONSTRAINT fk_turma_disciplina FOREIGN KEY (id_disciplina)     REFERENCES tb_disciplina      (id_disciplina),
    CONSTRAINT fk_turma_periodo    FOREIGN KEY (id_periodo_letivo) REFERENCES tb_periodo_letivo  (id_periodo_letivo),
    CONSTRAINT fk_turma_professor  FOREIGN KEY (id_professor)      REFERENCES tb_professor       (id_professor),
    CONSTRAINT uq_turma_codigo     UNIQUE (id_periodo_letivo, id_disciplina, codigo),
    CONSTRAINT ck_turma_vagas      CHECK (vagas > 0)
);

-- ---- tb_turma_horario ------------------------------------------------
-- POR QUÊ : uma turma tem vários encontros na semana (seg 19h–21h na
--           sala B-201, qua 19h–21h no laboratório...).
-- O QUE   : cada linha = um encontro. O desenho tinha "faixa
--           varchar(20)" (texto livre, ex. '19:00-21:00'); texto não
--           permite o banco comparar horários. Foi trocado por
--           hora_inicio + hora_fim (type time).
-- COMO    :
--  * CHECK hora_fim > hora_inicio impede intervalo invertido.
--  * timerange (criado em 01_tipos.sql) é um INTERVALO de horas. O
--    construtor timerange(a, b) usa '[)' (fecha no início, abre no fim): uma aula
--    que termina às 21:00 NÃO conflita com a que começa às 21:00.
--  * EXCLUDE ... USING gist: "não pode existir outra linha com a MESMA
--    sala, MESMO dia e intervalo que SE SOBREPÕE (&&)". É a regra
--    "uma sala, um horário, uma turma" garantida pelo banco, sem depender
--    do código da aplicação. Precisa da extensão btree_gist.
--  * CASCADE na turma: horário não existe sem a turma.
CREATE TABLE tb_turma_horario (
    id_turma_horario  integer GENERATED ALWAYS AS IDENTITY,
    id_turma          integer  NOT NULL,
    id_sala           integer  NOT NULL,
    dia_semana        smallint NOT NULL,                  -- ISO: 1=segunda ... 7=domingo
    hora_inicio       time     NOT NULL,
    hora_fim          time     NOT NULL,
    CONSTRAINT pk_turma_horario PRIMARY KEY (id_turma_horario),
    CONSTRAINT fk_th_turma      FOREIGN KEY (id_turma) REFERENCES tb_turma (id_turma) ON DELETE CASCADE,
    CONSTRAINT fk_th_sala       FOREIGN KEY (id_sala)  REFERENCES tb_sala  (id_sala),
    CONSTRAINT ck_th_dia        CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT ck_th_horas      CHECK (hora_fim > hora_inicio),
    CONSTRAINT ex_sala_ocupada  EXCLUDE USING gist
        (id_sala WITH =, dia_semana WITH =, timerange(hora_inicio, hora_fim) WITH &&)
);

-- =====================================================================
-- 5. VIDA ACADÊMICA: ALUNO, MATRÍCULA, HISTÓRICO
-- =====================================================================
-- ---- tb_aluno --------------------------------------------------------
-- POR QUÊ : o aluno ingressa em UMA matriz curricular (e é por ela que
--           se descobre o curso: aluno -> currículo -> curso).
-- O QUE   : CPF com 11 dígitos numéricos e único; e-mail único.
-- COMO    : char(11) + CHECK com expressão regular '^[0-9]{11}$' rejeita
--           letras, pontos e traços (o CPF é guardado só com dígitos).
CREATE TABLE tb_aluno (
    id_aluno         integer GENERATED ALWAYS AS IDENTITY,
    id_curriculo     integer      NOT NULL,
    cpf              char(11)     NOT NULL,
    nome_aluno       varchar(120) NOT NULL,
    email_aluno      varchar(120) NOT NULL,
    nascimento       date         NOT NULL,
    ingresso_aluno   smallint     NOT NULL,                -- ano de ingresso
    ativo_aluno      boolean      NOT NULL DEFAULT true,   -- false = evadido/formado
    CONSTRAINT pk_aluno           PRIMARY KEY (id_aluno),
    CONSTRAINT fk_aluno_curriculo FOREIGN KEY (id_curriculo) REFERENCES tb_curriculo (id_curriculo),
    CONSTRAINT uq_aluno_cpf       UNIQUE (cpf),
    CONSTRAINT uq_aluno_email     UNIQUE (email_aluno),
    CONSTRAINT ck_aluno_cpf       CHECK (cpf ~ '^[0-9]{11}$'),
    CONSTRAINT ck_aluno_email     CHECK (email_aluno LIKE '_%@_%._%'),
    CONSTRAINT ck_aluno_nasc      CHECK (nascimento >= DATE '1900-01-01'),
    CONSTRAINT ck_aluno_ingresso  CHECK (ingresso_aluno BETWEEN 1990 AND 2100)
);

-- ---- tb_matricula ----------------------------------------------------
-- POR QUÊ : liga aluno a turma (N:N com atributos: data e status).
-- O QUE   : o mesmo aluno não pode se matricular duas vezes na mesma
--           turma. "Trancar" e "cancelar" são mudanças de STATUS — a
--           linha não é apagada (histórico e auditoria dependem dela).
CREATE TABLE tb_matricula (
    id_matricula       integer GENERATED ALWAYS AS IDENTITY,
    id_aluno           integer       NOT NULL,
    id_turma           integer       NOT NULL,
    data_matricula     date          NOT NULL DEFAULT current_date,
    status_matricula   status_mat_t  NOT NULL DEFAULT 'MATRICULADO',
    CONSTRAINT pk_matricula       PRIMARY KEY (id_matricula),
    CONSTRAINT fk_matricula_aluno FOREIGN KEY (id_aluno) REFERENCES tb_aluno (id_aluno),
    CONSTRAINT fk_matricula_turma FOREIGN KEY (id_turma) REFERENCES tb_turma (id_turma),
    CONSTRAINT uq_matricula       UNIQUE (id_aluno, id_turma)
);

-- ---- tb_historico ----------------------------------------------------
-- POR QUÊ : o resultado final do aluno naquela matrícula: notas,
--           frequência, média e situação (aprovado/reprovado).
-- O QUE   : relação 1:1 com a matrícula (id_matricula é FK + UNIQUE).
--           media_geral e situacao são CALCULADAS pelo banco:
--             media   : sem P3 -> 0,4*A1 + 0,6*A2
--                       com P3 -> a P3 substitui a menor nota (vale a
--                                 melhor das duas combinações)
--             situacao: sem A1 ou A2 -> CURSANDO
--                       frequência < 75% -> REPROVADO_FALTA
--                       média >= 6,0 -> APROVADO, senão REPROVADO_NOTA
-- COMO    : a fórmula mora em UMA função (fn_media_geral, IMMUTABLE) e é
--           chamada pelas duas colunas "GENERATED ALWAYS ... STORED":
--           o banco recalcula a cada INSERT/UPDATE e ninguém consegue
--           gravar média ou situação incoerentes. A função precisa ser
--           IMMUTABLE (mesma entrada -> mesma saída) para ser aceita em
--           coluna gerada. nota_t / pct_t aplicam o CHECK 0–10 e 0–100.
CREATE FUNCTION fn_media_geral(a1 numeric, a2 numeric, p3 numeric)
RETURNS numeric(4,2)
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE
        WHEN a1 IS NULL OR a2 IS NULL THEN NULL
        WHEN p3 IS NULL THEN round(0.4 * a1 + 0.6 * a2, 2)
        ELSE round(greatest(0.4 * p3 + 0.6 * a2,
                            0.4 * a1 + 0.6 * p3), 2)
    END
$$;

CREATE TABLE tb_historico (
    id_historico  integer GENERATED ALWAYS AS IDENTITY,
    id_matricula  integer NOT NULL,
    nota_a1       nota_t,
    nota_a2       nota_t,
    nota_p3       nota_t,
    frequencia    pct_t   NOT NULL DEFAULT 100,
    situacao      situacao_t GENERATED ALWAYS AS (
        CASE
            WHEN nota_a1 IS NULL OR nota_a2 IS NULL THEN 'CURSANDO'::situacao_t
            WHEN frequencia < 75                    THEN 'REPROVADO_FALTA'
            WHEN fn_media_geral(nota_a1, nota_a2, nota_p3) >= 6 THEN 'APROVADO'
            ELSE 'REPROVADO_NOTA'
        END
    ) STORED,
    media_geral   nota_t GENERATED ALWAYS AS (fn_media_geral(nota_a1, nota_a2, nota_p3)) STORED,
    CONSTRAINT pk_historico           PRIMARY KEY (id_historico),
    CONSTRAINT uq_historico_matricula UNIQUE (id_matricula),
    CONSTRAINT fk_historico_matricula FOREIGN KEY (id_matricula) REFERENCES tb_matricula (id_matricula)
);

-- ---- tb_feriado ------------------------------------------------------
-- POR QUÊ : dias sem aula por campus (feriado municipal difere entre cidades).
-- O QUE   : um campus não repete a mesma data. PK corrigida para id_feriado.
CREATE TABLE tb_feriado (
    id_feriado  integer GENERATED ALWAYS AS IDENTITY,
    id_campus   integer      NOT NULL,
    descricao   varchar(120) NOT NULL,
    data        date         NOT NULL,
    CONSTRAINT pk_feriado        PRIMARY KEY (id_feriado),
    CONSTRAINT fk_feriado_campus FOREIGN KEY (id_campus) REFERENCES tb_campus (id_campus),
    CONSTRAINT uq_feriado        UNIQUE (id_campus, data)
);

-- ---- tb_log_matricula (auditoria) -----------------------------------
-- POR QUÊ : saber QUEM mudou QUE matrícula e QUANDO (matrícula é dado
--           sensível: vaga, prazo, disputa).
-- O QUE   : só é escrita pelo trigger da seção 6; ninguém insere à mão.
-- COMO    : FK RESTRICT: como o log existe desde o INSERT da matrícula,
--           matrícula nunca é apagada — apenas cancelada por status.
CREATE TABLE tb_log_matricula (
    id_log_matricula  integer GENERATED ALWAYS AS IDENTITY,
    id_matricula      integer      NOT NULL,
    acao              varchar(50)  NOT NULL,
    usuario           varchar(120) NOT NULL DEFAULT current_user,
    ocorrido_em       timestamp    NOT NULL DEFAULT now(),
    detalhe           text,
    CONSTRAINT pk_log_matricula PRIMARY KEY (id_log_matricula),
    CONSTRAINT fk_log_matricula FOREIGN KEY (id_matricula) REFERENCES tb_matricula (id_matricula)
);

