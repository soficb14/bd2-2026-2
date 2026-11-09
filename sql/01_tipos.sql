-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 01 - SCHEMA, TIPOS E DOMÍNIOS  (modelo lógico de 16 tabelas, PostgreSQL 16)
--
-- Como ler os blocos de comentário:
--   POR QUÊ : a necessidade do negócio que justifica a estrutura
--   O QUE   : o que o comando cria / garante
--   COMO    : o mecanismo do PostgreSQL que faz isso funcionar
--
-- Ordem dos scripts: 01 tipos -> 02 tabelas -> 03 restrições (triggers e
-- índices) -> 04 carga -> 05 consultas -> 06 views -> 07 índices ->
-- 08 concorrência -> 09 segurança.
-- Rode em um banco VAZIO (ex.: marco3). Para refazer: DROP DATABASE e crie de novo.
--
-- Ajustes em relação ao desenho do modelo lógico (3 erros de digitação):
--   1) tb_feriado: a PK estava como "id_turma"  -> id_feriado
--   2) tb_turma  : a coluna "tuno"              -> turno
--   3) tb_curriculo_disciplina.tipo: o tipo era vinculo_t -> tipo_disc_t
--      (obrigatória/optativa; vinculo_t é de pré/co-requisito)
-- Ajuste de projeto: tb_turma_horario.faixa varchar(20) virou
--   hora_inicio + hora_fim (ver 02_tabelas.sql).
-- Colunas calculadas pelo banco (mesmo nome e tipo do desenho):
--   tb_disciplina.ch_total_disciplina, tb_historico.media_geral e situacao.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. SCHEMA E EXTENSÃO
-- ---------------------------------------------------------------------
-- POR QUÊ : isolar o sistema acadêmico do schema public (permissões e
--           backup por schema ficam simples).
-- O QUE   : cria o schema "academico" e coloca ele no search_path, assim
--           podemos escrever tb_aluno em vez de academico.tb_aluno.
CREATE SCHEMA academico;
SET search_path = academico, public;

-- POR QUÊ : a regra "uma sala não pode ter duas aulas ao mesmo tempo"
--           precisa comparar igualdade (sala = sala) E sobreposição de
--           intervalo (&&) dentro da MESMA restrição.
-- O QUE   : btree_gist ensina o índice GiST a tratar tipos comuns
--           (integer, smallint) com o operador "=".
-- COMO    : sem esta extensão o EXCLUDE de tb_turma_horario não compila.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------------
-- 1. TIPOS ENUM
-- ---------------------------------------------------------------------
-- POR QUÊ : colunas que só aceitam um conjunto fechado de valores.
-- O QUE   : o banco rejeita qualquer texto fora da lista (ex.: 'NOITE').
-- COMO    : CREATE TYPE ... AS ENUM guarda o valor em 4 bytes e mantém a
--           ordem declarada (MATUTINO < VESPERTINO < NOTURNO), mais
--           barato e mais seguro que varchar + CHECK repetido em vários
--           lugares. Para incluir um valor novo: ALTER TYPE ... ADD VALUE.
CREATE TYPE turno_t      AS ENUM ('MATUTINO','VESPERTINO','NOTURNO');
CREATE TYPE tipo_disc_t  AS ENUM ('OBRIGATORIA','OPTATIVA');           -- tb_curriculo_disciplina.tipo
CREATE TYPE vinculo_t    AS ENUM ('PRE_REQUISITO','CO_REQUISITO');     -- tb_pre_requisito.vinculo
CREATE TYPE status_mat_t AS ENUM ('MATRICULADO','TRANCADO','CANCELADO');
CREATE TYPE situacao_t   AS ENUM ('CURSANDO','APROVADO','REPROVADO_NOTA','REPROVADO_FALTA');
CREATE TYPE tipo_sala_t  AS ENUM ('TEORICA','LABORATORIO');

-- ---------------------------------------------------------------------
-- 2. DOMÍNIOS
-- ---------------------------------------------------------------------
-- POR QUÊ : nota (0 a 10) e percentual (0 a 100) aparecem em várias
--           colunas; a regra deve ser escrita UMA vez.
-- O QUE   : nota_t e pct_t são "tipos com CHECK embutido".
-- COMO    : CREATE DOMAIN envolve um tipo base (numeric) e aplica o CHECK
--           em toda coluna que o usar. Mudou a regra? Altera-se no domínio.
--           NULL passa no CHECK (a nota ainda não lançada é NULL).
CREATE DOMAIN nota_t AS numeric(4,2) CHECK (VALUE >= 0 AND VALUE <= 10);
CREATE DOMAIN pct_t  AS numeric(5,2) CHECK (VALUE >= 0 AND VALUE <= 100);


-- ---------------------------------------------------------------------
-- 3. INTERVALO DE HORÁRIOS
-- ---------------------------------------------------------------------
-- POR QUÊ : o PostgreSQL já tem intervalos de inteiro, data e timestamp,
--           mas não de HORA do dia; precisamos dele para comparar
--           "19:00–21:00" com "20:00–22:00" na regra de sala ocupada.
-- O QUE   : timerange = intervalo de valores do tipo time.
-- COMO    : CREATE TYPE ... AS RANGE gera também o construtor
--           timerange(inicio, fim) e o operador && (sobrepõe). O padrão do
--           construtor é '[)': inclui o início e exclui o fim, então uma
--           aula que termina às 21:00 NÃO conflita com a que começa às 21:00.
CREATE TYPE timerange AS RANGE (subtype = time);
