-- =====================================================================
-- BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- 06 - VIEWS E MATERIALIZED VIEW (Marco 2)
-- Frente: Administração e Operação
--
-- Objetos criados:
--   vw_oferta_turmas        - o que está sendo ofertado (turma, disciplina,
--                             professor, horários e salas)
--   vw_vagas_turma          - vagas, ocupadas e restantes por turma
--   vw_historico_aluno      - histórico acadêmico legível (por aluno)
--   mv_indicadores_curso    - MATERIALIZED VIEW com indicadores por curso
--                             e período letivo
--
-- Rodar depois de 01..05 (modelo de 16 tabelas). Pode ser executado várias vezes.
-- ATENÇÃO: reexecutar este script recria a materialized view e apaga os
-- GRANTs dela; se rodar 06 de novo, rode 09_seguranca.sql de novo também.
-- =====================================================================

SET search_path TO academico, public;

-- ---------------------------------------------------------------------
-- VIEW 1 — Oferta de turmas
-- Junta turma + disciplina + professor + período e transforma os
-- horários (tabela tb_turma_horario, N por turma) numa única coluna de
-- texto. LEFT JOIN em horário/sala: turma sem horário definido
-- continua aparecendo na oferta.
-- (dia_semana segue a convenção ISO: 1=segunda ... 7=domingo.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_oferta_turmas AS
SELECT t.id_turma                   AS turma_id,
       t.codigo                     AS turma,
       d.codigo                     AS disciplina_codigo,
       d.nome                       AS disciplina,
       p.ano || '/' || p.semestre   AS periodo,
       t.turno,
       pr.nome_professor            AS professor,
       t.vagas,
       string_agg(
           (ARRAY['seg','ter','qua','qui','sex','sab','dom'])[th.dia_semana]
             || ' ' || to_char(th.hora_inicio, 'HH24:MI')
             || '-' || to_char(th.hora_fim, 'HH24:MI')
             || ' (' || s.codigo || ')',
           '; ' ORDER BY th.dia_semana, th.hora_inicio
       )                            AS horarios
FROM tb_turma t
JOIN tb_disciplina      d  ON d.id_disciplina = t.id_disciplina
JOIN tb_periodo_letivo  p  ON p.id_periodo_letivo = t.id_periodo_letivo
JOIN tb_professor       pr ON pr.id_professor = t.id_professor
LEFT JOIN tb_turma_horario th ON th.id_turma = t.id_turma
LEFT JOIN tb_sala       s  ON s.id_sala = th.id_sala
GROUP BY t.id_turma, t.codigo, d.codigo, d.nome, p.ano, p.semestre,
         t.turno, pr.nome_professor, t.vagas;

COMMENT ON VIEW vw_oferta_turmas IS
  'Oferta do período: turma, disciplina, professor, turno, vagas e horários/salas concatenados.';

-- ---------------------------------------------------------------------
-- VIEW 2 — Vagas por turma
-- Conta só matrículas com status MATRICULADO (a mesma regra do trigger
-- fn_valida_vaga). LEFT JOIN + FILTER: turma sem nenhuma matrícula
-- aparece com 0 ocupadas, em vez de sumir.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_vagas_turma AS
SELECT t.id_turma                                        AS turma_id,
       t.codigo                                          AS turma,
       d.nome                                            AS disciplina,
       t.vagas,
       count(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO')              AS ocupadas,
       t.vagas - count(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO')    AS vagas_restantes,
       round(100.0 * count(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO')
             / t.vagas, 1)                               AS ocupacao_pct
FROM tb_turma t
JOIN tb_disciplina d ON d.id_disciplina = t.id_disciplina
LEFT JOIN tb_matricula m ON m.id_turma = t.id_turma
GROUP BY t.id_turma, t.codigo, d.nome, t.vagas;

COMMENT ON VIEW vw_vagas_turma IS
  'Vagas, ocupadas, restantes e % de ocupação por turma (conta apenas status MATRICULADO).';

-- ---------------------------------------------------------------------
-- VIEW 3 — Histórico do aluno
-- Uma linha por matrícula ativa com notas, média geral e situação
-- (colunas geradas de tb_historico), frequência e disciplina.
--
-- security_invoker = true: a view executa com as permissões (e com a
-- row-level security) de QUEM CONSULTA, e não do dono da view. É isso
-- que faz a política de RLS de 09_seguranca.sql valer também por aqui:
-- um aluno consultando a view só enxerga o próprio histórico.
-- (Sem essa opção, a view rodaria como dono e vazaria tudo.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_historico_aluno
WITH (security_invoker = true) AS
SELECT a.id_aluno      AS aluno_id,
       a.cpf           AS cpf_aluno,
       a.nome_aluno    AS aluno,
       c.codigo        AS curso,
       p.ano || '/' || p.semestre AS periodo,
       d.codigo        AS disciplina_codigo,
       d.nome          AS disciplina,
       t.codigo        AS turma,
       h.nota_a1, h.nota_a2, h.nota_p3,
       h.media_geral,
       h.frequencia,
       h.situacao
FROM tb_historico      h
JOIN tb_matricula      m  ON m.id_matricula = h.id_matricula
JOIN tb_aluno          a  ON a.id_aluno = m.id_aluno
JOIN tb_curriculo      cu ON cu.id_curriculo = a.id_curriculo
JOIN tb_curso          c  ON c.id_curso = cu.id_curso
JOIN tb_turma          t  ON t.id_turma = m.id_turma
JOIN tb_disciplina     d  ON d.id_disciplina = t.id_disciplina
JOIN tb_periodo_letivo p  ON p.id_periodo_letivo = t.id_periodo_letivo
WHERE m.status_matricula = 'MATRICULADO';

COMMENT ON VIEW vw_historico_aluno IS
  'Histórico acadêmico por matrícula. security_invoker: respeita a RLS de quem consulta.';

-- ---------------------------------------------------------------------
-- MATERIALIZED VIEW — Indicadores por curso e período
-- Agrega as matrículas ativas (junta 7 tabelas e calcula taxas e
-- médias). Guardar o resultado pronto evita refazer esse cálculo a
-- cada consulta de dashboard da coordenação.
--
-- POLÍTICA DE ATUALIZAÇÃO (justificativa):
--  * Os números só mudam quando notas/situação são lançadas ou
--    fechadas, ou seja, em eventos raros e previsíveis (fechamento de
--    nota, fim do semestre) — não a cada matrícula. Um indicador
--    "de ontem" é aceitável para gestão acadêmica; um indicador
--    "de agora" não justifica o custo de recalcular a cada escrita
--    (trigger por linha seria caro) nem de tornar a matrícula mais
--    lenta.
--  * Atualizar: (a) todo dia de madrugada (cron / pgAgent) e (b)
--    manualmente após o fechamento de notas:
--        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_indicadores_curso;
--  * CONCURRENTLY: reconstrói sem bloquear leitores — a coordenação
--    pode consultar durante o refresh. Exige um índice ÚNICO na MV
--    (criado abaixo) e a MV já populada (por isso WITH DATA).
--    Custo: refresh um pouco mais lento do que o REFRESH simples.
-- ---------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_indicadores_curso;

CREATE MATERIALIZED VIEW mv_indicadores_curso AS
SELECT c.id_curso                   AS curso_id,
       c.codigo                     AS curso,
       p.id_periodo_letivo          AS periodo_id,
       p.ano || '/' || p.semestre   AS periodo,
       count(DISTINCT m.id_aluno)   AS alunos_com_matricula,
       count(*)                     AS matriculas,
       count(*) FILTER (WHERE h.situacao = 'APROVADO')         AS aprovados,
       count(*) FILTER (WHERE h.situacao IN ('REPROVADO_NOTA','REPROVADO_FALTA')) AS reprovados,
       count(*) FILTER (WHERE h.situacao = 'CURSANDO')         AS cursando,
       round(100.0 * count(*) FILTER (WHERE h.situacao = 'APROVADO')
             / NULLIF(count(*) FILTER (WHERE h.situacao <> 'CURSANDO'), 0), 1)
                                    AS taxa_aprovacao_pct,
       round(avg(h.media_geral), 2) AS media_geral,
       round(avg(h.frequencia), 1)  AS frequencia_media
FROM tb_historico      h
JOIN tb_matricula      m  ON m.id_matricula = h.id_matricula
JOIN tb_aluno          a  ON a.id_aluno = m.id_aluno
JOIN tb_curriculo      cu ON cu.id_curriculo = a.id_curriculo
JOIN tb_curso          c  ON c.id_curso = cu.id_curso
JOIN tb_turma          t  ON t.id_turma = m.id_turma
JOIN tb_periodo_letivo p  ON p.id_periodo_letivo = t.id_periodo_letivo
WHERE m.status_matricula = 'MATRICULADO'
GROUP BY c.id_curso, c.codigo, p.id_periodo_letivo, p.ano, p.semestre
WITH DATA;

-- Índice único: pré-requisito do REFRESH ... CONCURRENTLY.
CREATE UNIQUE INDEX uq_mv_indicadores_curso
    ON mv_indicadores_curso (curso_id, periodo_id);

COMMENT ON MATERIALIZED VIEW mv_indicadores_curso IS
  'Indicadores por curso/período. Atualizar com REFRESH MATERIALIZED VIEW CONCURRENTLY após fechamento de notas e diariamente.';

-- ---------------------------------------------------------------------
-- Conferência rápida (rodar para mostrar na apresentação)
-- ---------------------------------------------------------------------
-- SELECT * FROM vw_oferta_turmas ORDER BY turma;
-- SELECT * FROM vw_vagas_turma   ORDER BY turma;
-- SELECT * FROM vw_historico_aluno WHERE cpf_aluno = '10000000001';
-- SELECT * FROM mv_indicadores_curso ORDER BY curso;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_indicadores_curso;
