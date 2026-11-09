# Sistema de Matrícula Acadêmica — Banco de Dados II (CCO072)

**IESB · 2026/2 · Prof. Rodrigo Gonçalves** · Grupo: Pedro, Sofia e Victor

Banco de dados **PostgreSQL** do sistema de matrícula acadêmica: 16 tabelas com restrições de integridade, 10 consultas, views, índices medidos com `EXPLAIN`, controle de concorrência na disputa pela última vaga, segurança por papéis e *row-level security*, e backup com restauração. Tudo roda em Docker e é reconstruído do zero com os comandos deste arquivo.

> **Em resumo:** com o Docker aberto, suba os contêineres, crie o banco `marco3` no pgAdmin e rode os scripts `01` a `09` no Query Tool (seção 3). Só o `07` (índices), o `pgbench` e o backup precisam de terminal. Para reconstruir tudo de uma vez pelo terminal: `.\scripts\rodar_tudo.ps1` (seção 4).

## Sumário

1. [Pré-requisitos](#1-pré-requisitos)
2. [O que roda onde](#2-o-que-roda-onde)
3. [Passo a passo no pgAdmin](#3-passo-a-passo-no-pgadmin)
4. [Alternativa: tudo pelo terminal](#4-alternativa-tudo-pelo-terminal)
5. [Os scripts SQL](#5-os-scripts-sql)
6. [Roteiro da demonstração ao vivo](#6-roteiro-da-demonstração-ao-vivo)
7. [Evidências](#7-evidências)
8. [Modelo lógico](#8-modelo-lógico)
9. [Estrutura do repositório](#9-estrutura-do-repositório)
10. [Problemas comuns](#10-problemas-comuns)
11. [Autores](#11-autores)

---

## 1. Pré-requisitos

- **Docker Desktop** instalado e **aberto** (Windows, macOS ou Linux).
- **PowerShell** (os comandos deste README são para PowerShell, rodados na pasta do projeto). No Linux/macOS os mesmos comandos funcionam em qualquer shell.
- Portas **5432** (PostgreSQL) e **8080** (pgAdmin) livres.

O ambiente do professor (`docker-compose.yml`) sobe um **PostgreSQL 16** e o **pgAdmin**. O banco de prática `matricula`, do professor, já vem carregado; o banco **do projeto** é o `marco3`, separado e criado nos passos abaixo. O schema usado é o `academico`.

| Serviço | Endereço | Credenciais |
|---|---|---|
| PostgreSQL | `localhost:5432` | usuário `bd2` · senha `bd2` · bancos `matricula` (professor) e `marco3` (projeto) |
| pgAdmin | http://localhost:8080 | login `admin@iesb.br` · senha `admin` |

---

## 2. O que roda onde

O caminho principal usa o **pgAdmin** para tudo o que ele consegue fazer. O terminal fica só com o que o pgAdmin não faz.

| Etapa | Onde |
|---|---|
| Subir e derrubar o Docker | terminal (`docker compose`) |
| Criar o banco `marco3` | **pgAdmin** |
| Scripts `01` a `06`, `08` e `09` | **pgAdmin** (Query Tool) |
| As 10 consultas (`05`), restrições de integridade, `EXPLAIN`, concorrência e RLS | **pgAdmin** |
| `07_indices.sql` (índices) | terminal: tem `VACUUM`, que o pgAdmin não aceita |
| Medição de concorrência com `pgbench` | terminal |
| Backup e restauração | terminal |

**Atalho:** `.\scripts\rodar_tudo.ps1` reconstrói tudo do zero, de uma vez, pelo terminal (seção 4.1). Serve para conferir se o banco inteiro sobe sem erro; para a demonstração, use o caminho do pgAdmin.

---

## 3. Passo a passo no pgAdmin

### 3.1 Subir o Docker (terminal)

Na pasta do projeto, no PowerShell:

```powershell
docker compose down -v          # apaga qualquer estado anterior (inclusive o marco3)
docker compose up -d            # sobe PostgreSQL + pgAdmin
docker compose ps               # espere o bd2_postgres ficar (healthy)
```

Na primeira subida o PostgreSQL ainda carrega o banco `matricula` do professor: acompanhe com `docker compose logs -f postgres` até aparecer `database system is ready to accept connections`. O pgAdmin pode levar de 1 a 3 minutos para responder; se a página der *timeout*, espere e recarregue (Ctrl+Shift+R).

> O `docker-compose.yml` do grupo monta as pastas `sql/` e `docs/` dentro do pgAdmin (somente leitura), para que o Query Tool abra os scripts direto do projeto. Isso só vale depois de um `docker compose up -d` novo, como o do comando acima.

### 3.2 Registrar o servidor no pgAdmin

Abra http://localhost:8080 e entre com `admin@iesb.br` / `admin`. Clique com o botão direito em *Servers → Register → Server* e preencha:

| Aba | Campo | Valor |
|---|---|---|
| General | Name | `bd2` |
| Connection | Host name/address | `postgres` (é o nome do serviço no Docker; **não** use `localhost`) |
| Connection | Port | `5432` |
| Connection | Maintenance database | `matricula` |
| Connection | Username / Password | `bd2` / `bd2` (marque *Save password*) |

### 3.3 Criar o banco `marco3`

*Servers → bd2 → Databases*, botão direito, *Create → Database…*: em *Database* digite `marco3`, em *Owner* escolha `bd2`, e clique em *Save*. Depois de qualquer `docker compose down -v` o `marco3` desaparece e este passo se repete.

### 3.4 Rodar os scripts, em ordem

1. Clique em `marco3` e abra o Query Tool (*Tools → Query Tool*, ou o ícone de raio no topo).
2. No Query Tool, clique no ícone de **pasta** (*Open File*) e escolha `/projeto/sql/01_tipos.sql`.
3. Clique dentro do editor e aperte **F5** (ou o botão ▶ da barra de ferramentas). Se o foco estiver fora do editor, o F5 recarrega a página do navegador: se aparecer "Leave page", escolha **Stay on page**. Depois olhe a aba *Messages*: deve aparecer `Query returned successfully`. Qualquer `ERROR` em vermelho é um defeito; pare e corrija antes de seguir.
4. Repita para os próximos, **nesta ordem**: `02`, `03`, `04`, `06`, `08`, `09`. (O `05` e o `07` ficam de fora desta sequência, veja abaixo.)

| Script | Observação |
|---|---|
| `05_consultas.sql` | abra, mas **selecione uma consulta por vez** e aperte F5. Com o arquivo inteiro, o pgAdmin só mostra o resultado da última. Pode rodar a qualquer momento depois do `04` |
| `06_views.sql`, `09_seguranca.sql` | mensagens `NOTICE ... does not exist, skipping` são normais: o script faz `DROP ... IF EXISTS` antes de criar |
| `08_concorrencia.sql` | termina mostrando o id da turma de teste `CONC` |
| `07_indices.sql` | **não** roda no pgAdmin; veja 3.6 |

Se o seletor de arquivos abrir em `/home/` vazio, digite `/projeto/sql` na barra de caminho e aperte Enter. Se ainda assim não aparecer nada, o contêiner do pgAdmin foi criado antes do volume: rode `docker compose up -d --force-recreate pgadmin` na pasta do projeto e reabra o seletor.

Alternativa que sempre funciona: abra no VS Code o arquivo da pasta `sql/` que corresponde ao passo (`sql/01_tipos.sql`, depois `sql/02_tabelas.sql` e assim por diante), selecione tudo (Ctrl+A), copie (Ctrl+C), cole no editor do Query Tool (Ctrl+V) e aperte F5. Um script de cada vez, na ordem da lista acima. O resultado é o mesmo.

Para cada comando dos roteiros da seção 6, abra uma aba nova do Query Tool no `marco3` e comece com:

```sql
SET search_path TO academico;
```

Rode **um comando por vez** (selecione a linha e aperte F5); o pgAdmin pode juntar vários comandos num lote só.

### 3.5 Conferir

No Query Tool:

```sql
SELECT (SELECT count(*) FROM academico.tb_aluno)                                  AS alunos,
       (SELECT count(*) FROM academico.tb_turma)                                  AS turmas,
       (SELECT count(*) FROM academico.tb_matricula)                              AS matriculas,
       (SELECT count(*) FROM academico.tb_historico WHERE media_geral IS NOT NULL) AS com_nota,
       (SELECT count(*) FROM pg_policies WHERE schemaname = 'academico')          AS policies;
```

Resultado esperado: `120 | 8 | 300 | 240 | 10`. As 8 turmas são as 7 da carga mais a turma de teste `CONC`.

### 3.6 Índices (`07`), pelo terminal

O `07` monta um laboratório de ~600 mil linhas e leva alguns minutos. Rode no PowerShell, depois dos outros:

```powershell
docker cp sql bd2_postgres:/tmp/
docker cp scripts bd2_postgres:/tmp/        # usado depois pelo pgbench e pelo backup
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -f /tmp/sql/07_indices.sql
```

A saída mostra o `EXPLAIN (ANALYZE, BUFFERS)` antes e depois de cada índice. Para **manter** o laboratório e refazer os `EXPLAIN` ao vivo no pgAdmin (seção 6.2), acrescente `-e 'PGOPTIONS=-c perf.manter=on'` logo depois de `docker exec`.

---

## 4. Alternativa: tudo pelo terminal

### 4.1 Um comando só

```powershell
.\scripts\rodar_tudo.ps1
```

Se o Windows bloquear scripts (`a execução de scripts está desabilitada`), rode assim:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\rodar_tudo.ps1
```

O script faz o que as seções 4.2 a 4.5 descrevem, na mesma ordem, e para no primeiro erro dizendo qual etapa falhou. Ao final confere as contagens e deve imprimir:

```
obtido  : alunos=120 turmas=8 matriculas=300 com_nota=240 policies=10 trigger_vagas=1
esperado: alunos=120 turmas=8 matriculas=300 com_nota=240 policies=10 trigger_vagas=1
```

| Opção | Efeito |
|---|---|
| `-SemIndices` | pula o `07_indices.sql`, que leva alguns minutos (cria ~600 mil linhas de laboratório) |
| `-SemReset` | não roda `docker compose down -v` (mantém o banco `matricula` do professor como está) |
| `-GravarEvidencias` | regrava `docs\evidencias_indices.txt` e `docs\evidencias_concorrencia.txt` em UTF-8 |

Na primeira vez, o Docker baixa as imagens e carrega o banco do professor: **espere alguns minutos**.

### 4.2 Subir os contêineres e criar o banco

```powershell
docker compose down -v
docker compose up -d
docker compose ps               # espere (healthy)
docker exec -i bd2_postgres psql -U bd2 -d matricula -c "CREATE DATABASE marco3 TEMPLATE template0;"
```

> Cuidado: o texto entre aspas depois do `-c` faz parte do comando. Sem ele o `psql` responde `option requires an argument -- 'c'`.

### 4.3 Copiar os scripts para o contêiner

```powershell
docker cp sql bd2_postgres:/tmp/
docker cp scripts bd2_postgres:/tmp/
```

### 4.4 Rodar os scripts SQL, em ordem

O `-v ON_ERROR_STOP=1` faz qualquer erro aparecer e parar, em vez de passar despercebido.

```powershell
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/01_tipos.sql
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/02_tabelas.sql
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/03_restricoes.sql
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/04_carga.sql
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/05_consultas.sql
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/06_views.sql
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/07_indices.sql
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/08_concorrencia.sql
docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f /tmp/sql/09_seguranca.sql
```

O `05` só imprime resultados (no pgAdmin ele é mais útil). O `07` leva alguns minutos; para ver a saída completa dos `EXPLAIN`, tire o `-q`.

### 4.5 Conferir e conectar de outras formas

```powershell
docker exec bd2_postgres psql -U bd2 -d marco3 -At -c "SELECT 'alunos='||(SELECT count(*) FROM academico.tb_aluno)||' matriculas='||(SELECT count(*) FROM academico.tb_matricula)||' com_nota='||(SELECT count(*) FROM academico.tb_historico WHERE media_geral IS NOT NULL)||' policies='||(SELECT count(*) FROM pg_policies WHERE schemaname='academico')"
```

Resultado esperado: `alunos=120 matriculas=300 com_nota=240 policies=10`.

**psql interativo:** `docker exec -it bd2_postgres psql -U bd2 -d marco3`

**DBeaver:** host `localhost`, porta `5432`, banco `marco3`, usuário `bd2`, senha `bd2`; defina o schema padrão da conexão como `academico`. Mais detalhes em `docs/README_ambiente_professor.md`.

---

## 5. Os scripts SQL

Numerados na ordem de execução. Os comentários de cada script seguem o padrão **POR QUÊ / O QUE / COMO**.

| Script | O que faz | Frente |
|---|---|---|
| `01_tipos.sql` | schema `academico`, 6 ENUMs, domínios `nota_t` e `pct_t`, tipo de intervalo `timerange` | Modelagem física |
| `02_tabelas.sql` | as 16 tabelas com PK, FK, `UNIQUE`, `CHECK`, `NOT NULL`, colunas geradas e `EXCLUDE` | Modelagem física |
| `03_restricoes.sql` | triggers (vagas, criação do histórico, log de matrícula) e 12 índices | Modelagem física |
| `04_carga.sql` | 120 alunos, 7 turmas, 300 matrículas e 300 históricos | Modelagem física |
| `05_consultas.sql` | 10 consultas comentadas, de complexidade crescente (recursivas, janela, junção externa) | Marco 1 |
| `06_views.sql` | 3 views + 1 materialized view (`vw_historico_aluno` é `security_invoker`) | Administração |
| `07_indices.sql` | 4 índices (2 parciais, GIN, BRIN) com `EXPLAIN (ANALYZE, BUFFERS)` antes e depois | Modelagem física |
| `08_concorrencia.sql` | cenário da última vaga (turma `CONC`), função de reset e view de conferência | Transações |
| `09_seguranca.sql` | papéis, `GRANT`/`REVOKE` por coluna e *row-level security* (10 policies) | Administração |

Scripts auxiliares em `scripts/`:

| Arquivo | Para quê |
|---|---|
| `rodar_tudo.ps1` | reconstrói tudo do zero pelo terminal (seção 4.1) |
| `medir_concorrencia.sh` | benchmark com `pgbench`: sem proteção × `FOR UPDATE` × `SERIALIZABLE` |
| `backup.sh` | gera o dump do banco e o arquivo dos papéis |
| `restaurar.sh` | restaura um dump (no mesmo banco, num banco paralelo ou num servidor novo) |

### 5.1 As 10 consultas, prontas para colar no pgAdmin

**Onde:** pgAdmin. Abra um Query Tool novo no `marco3`, cole **uma consulta por vez** (apague a anterior antes) e clique em ▶. O resultado aparece na aba *Data Output*. Os comentários completos de cada uma estão em `sql/05_consultas.sql`.

Rode isto **uma vez**, antes da primeira consulta (vale para a aba inteira):

```sql
SET search_path TO academico, public;
```

**Consulta 1 — Filtro simples:** alunos ativos do curso CCO, em ordem alfabética.

```sql
SELECT a.cpf, a.nome_aluno, a.email_aluno
FROM tb_aluno a
JOIN tb_curriculo cu ON cu.id_curriculo = a.id_curriculo
JOIN tb_curso c      ON c.id_curso = cu.id_curso
WHERE a.ativo_aluno = true
  AND c.codigo = 'CCO'
ORDER BY a.nome_aluno;
```

**Consulta 2 — Junção interna:** a oferta de 2026/2: turma, disciplina, professor e turno.

```sql
SELECT t.codigo AS turma, d.codigo AS disciplina, d.nome AS disciplina_nome,
       p.nome_professor AS professor, t.turno, t.vagas
FROM tb_turma t
JOIN tb_disciplina d ON d.id_disciplina = t.id_disciplina
JOIN tb_periodo_letivo pl ON pl.id_periodo_letivo = t.id_periodo_letivo
LEFT JOIN tb_professor p ON p.id_professor = t.id_professor
WHERE pl.ano = 2026 AND pl.semestre = 2
ORDER BY d.codigo, t.codigo;
```

**Consulta 3 — Junção externa com agregação (obrigatória):** vagas, ocupadas e restantes de cada turma; turma sem matrícula também aparece.

```sql
SELECT t.id_turma, t.codigo, d.codigo AS disciplina, t.vagas,
       COUNT(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO')            AS ocupadas,
       t.vagas - COUNT(m.id_matricula) FILTER (WHERE m.status_matricula = 'MATRICULADO')  AS vagas_restantes
FROM tb_turma t
JOIN tb_disciplina d      ON d.id_disciplina = t.id_disciplina
LEFT JOIN tb_matricula m  ON m.id_turma = t.id_turma
GROUP BY t.id_turma, t.codigo, d.codigo, t.vagas
ORDER BY vagas_restantes;
```

**Consulta 4 — Anti-junção com `NOT EXISTS`:** alunos sem nenhuma matrícula.

```sql
SELECT a.cpf, a.nome_aluno
FROM tb_aluno a
WHERE NOT EXISTS (
    SELECT 1 FROM tb_matricula m WHERE m.id_aluno = a.id_aluno
)
ORDER BY a.nome_aluno;
```

**Consulta 5 — Agregação com `HAVING`:** disciplinas com média de rendimento abaixo da média geral.

```sql
SELECT d.codigo, d.nome,
       ROUND(AVG(h.media_geral), 2) AS media_disciplina,
       COUNT(*) AS avaliacoes_consideradas
FROM tb_historico h
JOIN tb_matricula m  ON m.id_matricula = h.id_matricula
JOIN tb_turma t      ON t.id_turma = m.id_turma
JOIN tb_disciplina d ON d.id_disciplina = t.id_disciplina
WHERE h.media_geral IS NOT NULL
GROUP BY d.codigo, d.nome
HAVING AVG(h.media_geral) < (
    SELECT AVG(media_geral) FROM tb_historico WHERE media_geral IS NOT NULL
)
ORDER BY media_disciplina;
```

**Consulta 6 — Consulta recursiva (obrigatória):** a cadeia de pré-requisitos de ENG001, direta e indireta.

```sql
WITH RECURSIVE arvore_prereq AS (
    SELECT pr.id_disciplina, pr.id_requisito, 1 AS nivel
    FROM tb_pre_requisito pr
    WHERE pr.id_disciplina = (SELECT id_disciplina FROM tb_disciplina WHERE codigo = 'ENG001')

    UNION ALL

    SELECT ap.id_disciplina, pr.id_requisito, ap.nivel + 1
    FROM arvore_prereq ap
    JOIN tb_pre_requisito pr ON pr.id_disciplina = ap.id_requisito
)
SELECT ap.nivel, d.codigo, d.nome
FROM arvore_prereq ap
JOIN tb_disciplina d ON d.id_disciplina = ap.id_requisito
ORDER BY ap.nivel, d.codigo;
```

**Consulta 7 — Consulta recursiva (obrigatória):** disciplinas que o aluno de CPF 10000000001 já pode cursar (troque o CPF para testar outro aluno).

```sql
WITH RECURSIVE fechamento_prereq AS (
    SELECT id_disciplina, id_requisito
    FROM tb_pre_requisito

    UNION

    SELECT fp.id_disciplina, pr.id_requisito
    FROM fechamento_prereq fp
    JOIN tb_pre_requisito pr ON pr.id_disciplina = fp.id_requisito
),
aprovadas_aluno AS (
    SELECT DISTINCT t.id_disciplina
    FROM tb_matricula m
    JOIN tb_historico h ON h.id_matricula = m.id_matricula
    JOIN tb_turma t     ON t.id_turma = m.id_turma
    WHERE m.id_aluno = (SELECT id_aluno FROM tb_aluno WHERE cpf = '10000000001')
      AND h.situacao = 'APROVADO'
)
SELECT d.codigo, d.nome
FROM tb_aluno al
JOIN tb_curriculo_disciplina cd ON cd.id_curriculo = al.id_curriculo
JOIN tb_disciplina d            ON d.id_disciplina = cd.id_disciplina
WHERE al.cpf = '10000000001'
  AND d.id_disciplina NOT IN (SELECT id_disciplina FROM aprovadas_aluno)
  AND NOT EXISTS (
      SELECT 1
      FROM fechamento_prereq fp
      WHERE fp.id_disciplina = d.id_disciplina
        AND fp.id_requisito NOT IN (SELECT id_disciplina FROM aprovadas_aluno)
  )
ORDER BY d.codigo;
```

**Consulta 8 — Função de janela (obrigatória):** posição (`RANK`) e percentil de cada aluno dentro do curso.

```sql
SELECT c.codigo AS curso, a.nome_aluno AS aluno, h.media_geral,
       RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_geral DESC) AS posicao_no_curso,
       ROUND(
           (PERCENT_RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_geral) * 100)::numeric,
           1
       ) AS percentil
FROM tb_historico h
JOIN tb_matricula m  ON m.id_matricula = h.id_matricula
JOIN tb_aluno a      ON a.id_aluno = m.id_aluno
JOIN tb_curriculo cu ON cu.id_curriculo = a.id_curriculo
JOIN tb_curso c      ON c.id_curso = cu.id_curso
WHERE h.media_geral IS NOT NULL
ORDER BY c.codigo, posicao_no_curso;
```

**Consulta 9 — Função de janela com `LAG` (obrigatória):** evolução da média de cada aluno de uma matrícula para a seguinte.

```sql
SELECT a.cpf, a.nome_aluno AS aluno, m.data_matricula,
       d.codigo AS disciplina, h.media_geral,
       LAG(h.media_geral) OVER (PARTITION BY a.id_aluno ORDER BY m.data_matricula, m.id_matricula) AS media_anterior,
       h.media_geral
         - LAG(h.media_geral) OVER (PARTITION BY a.id_aluno ORDER BY m.data_matricula, m.id_matricula) AS variacao
FROM tb_historico h
JOIN tb_matricula m  ON m.id_matricula = h.id_matricula
JOIN tb_aluno a      ON a.id_aluno = m.id_aluno
JOIN tb_turma t      ON t.id_turma = m.id_turma
JOIN tb_disciplina d ON d.id_disciplina = t.id_disciplina
WHERE h.media_geral IS NOT NULL
ORDER BY a.cpf, m.data_matricula, m.id_matricula;
```

**Consulta 10 — CTE + janela + filtro:** os 3 melhores alunos de cada curso.

```sql
WITH ranking_curso AS (
    SELECT c.codigo AS curso, a.nome_aluno AS aluno, h.media_geral,
           RANK() OVER (PARTITION BY c.codigo ORDER BY h.media_geral DESC) AS posicao
    FROM tb_historico h
    JOIN tb_matricula m  ON m.id_matricula = h.id_matricula
    JOIN tb_aluno a      ON a.id_aluno = m.id_aluno
    JOIN tb_curriculo cu ON cu.id_curriculo = a.id_curriculo
    JOIN tb_curso c      ON c.id_curso = cu.id_curso
    WHERE h.media_geral IS NOT NULL
)
SELECT curso, posicao, aluno, media_geral
FROM ranking_curso
WHERE posicao <= 3
ORDER BY curso, posicao;
```

---

## 6. Roteiro da demonstração ao vivo

A apresentação mostra, no mínimo: restrições de integridade, a anomalia de concorrência e sua correção, um `EXPLAIN ANALYZE`, a política de RLS e uma restauração de backup. Cada item abaixo diz o que rodar e o que deve aparecer. Antes de começar, tenha o ambiente da seção 3 pronto (inclusive o `07`, se for mostrar índices) e o pgAdmin conectado ao `marco3`.

### 6.1 Restrições de integridade em funcionamento

**Onde:** pgAdmin (Query Tool).

No Query Tool, com `SET search_path TO academico;`. Cada comando **deve falhar**, e a mensagem mostra qual regra do banco o barrou:

```sql
-- CPF com menos de 11 dígitos
INSERT INTO tb_aluno (id_curriculo, cpf, nome_aluno, email_aluno, nascimento, ingresso_aluno)
VALUES (1, '123', 'Teste', 't@x.com', '2000-01-01', 2026);
-- ERRO: violates check constraint "ck_aluno_cpf"

-- nota fora do intervalo 0 a 10 (domínio nota_t)
UPDATE tb_historico SET nota_a1 = 11 WHERE id_historico = 1;
-- ERRO: value for domain nota_t violates check constraint "nota_t_check"

-- a situação é calculada pelo banco; não aceita valor digitado
INSERT INTO tb_historico (id_matricula, nota_a1, nota_a2, frequencia, situacao)
VALUES (1, 2, 2, 40, 'APROVADO');
-- ERRO: cannot insert a non-DEFAULT value into column "situacao"

-- matrícula duplicada (mesmo aluno na mesma turma)
INSERT INTO tb_matricula (id_aluno, id_turma)
SELECT id_aluno, id_turma FROM tb_matricula WHERE id_matricula = 1;
-- ERRO: duplicate key value violates unique constraint "uq_matricula"

-- aluno que não existe (chave estrangeira)
INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (99999, 1);
-- ERRO: violates foreign key constraint "fk_matricula_aluno"

-- horário invertido
INSERT INTO tb_turma_horario (id_turma, id_sala, dia_semana, hora_inicio, hora_fim)
VALUES (2, 3, 2, '10:00', '08:00');
-- ERRO: violates check constraint "ck_th_horas"

-- mesma sala, mesmo dia, horário que se sobrepõe a uma aula já existente
INSERT INTO tb_turma_horario (id_turma, id_sala, dia_semana, hora_inicio, hora_fim)
VALUES (2, 1, 1, '09:00', '11:00');
-- ERRO: conflicting key value violates exclusion constraint "ex_sala_ocupada"
```

Turma cheia (trigger `fn_valida_vaga`), usando a turma de teste de 1 vaga:

```sql
SELECT fn_reset_cenario_concorrencia(1);
INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (1, (SELECT id_turma FROM tb_turma WHERE codigo = 'CONC'));  -- ok
INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (2, (SELECT id_turma FROM tb_turma WHERE codigo = 'CONC'));  -- ERRO: Turma ... sem vagas (1 de 1)
SELECT fn_reset_cenario_concorrencia(1);   -- deixa a turma limpa para a demo de concorrência
```

Explicação de cada regra: comentários de `sql/02_tabelas.sql` e `sql/03_restricoes.sql`.

### 6.2 Índices e `EXPLAIN (ANALYZE, BUFFERS)`

**Onde:** pgAdmin; só a criação do laboratório (`07` com `perf.manter=on`) é no terminal.

O `07_indices.sql` monta um laboratório (schema `perf`, ~600 mil linhas), mede cada consulta **antes** e **depois** de criar o índice e apaga o schema. Para refazer um `EXPLAIN` ao vivo, mantenha o laboratório:

```powershell
docker exec -e 'PGOPTIONS=-c perf.manter=on' bd2_postgres psql -U bd2 -d marco3 -f /tmp/sql/07_indices.sql
```

No Query Tool, um comando por vez:

```sql
SET search_path TO perf, academico;
DROP INDEX ix_matricula_turma_ativa;

EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM perf.tb_matricula WHERE id_turma = 1500 AND status_matricula = 'MATRICULADO';
-- Seq Scan, ~3.822 páginas lidas

CREATE INDEX ix_matricula_turma_ativa ON perf.tb_matricula (id_turma) WHERE status_matricula = 'MATRICULADO';
VACUUM ANALYZE perf.tb_matricula;

EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM perf.tb_matricula WHERE id_turma = 1500 AND status_matricula = 'MATRICULADO';
-- Index Only Scan, 4 páginas lidas
```

Ao terminar, apague o laboratório (ele entraria no backup): `DROP SCHEMA perf CASCADE;`

Resultado medido (a saída completa está em `docs/evidencias_indices.txt`):

| Índice | Plano antes → depois | Páginas lidas |
|---|---|---|
| `ix_matricula_turma_ativa` (B-tree parcial) | Seq Scan → Index Only Scan | 3.822 → 4 |
| `ix_historico_situacao` (B-tree parcial) | Seq Scan → Index Only Scan | 3.244 → 6 |
| `ix_disciplina_ementa_fts` (GIN) | Seq Scan → Bitmap Heap Scan | 658 → 62 |
| `ix_log_ocorrido` (BRIN) | Seq Scan → Bitmap Heap Scan | 6.712 → 130 |

Explicação completa: `docs/INDICES_E_DESEMPENHO.md`.

### 6.3 Transações e concorrência: a disputa pela última vaga

**Onde:** pgAdmin, em duas abas; a medição com `pgbench` é no terminal.

**O problema:** a turma de teste `CONC` tem **1 vaga**. Dois alunos tentam se matricular ao mesmo tempo. O trigger confere se há vaga, mas no nível padrão (`READ COMMITTED`) cada transação só vê o que já foi confirmado pela outra. As duas conferem "0 ocupadas" e as duas entram: **2 matriculados em 1 vaga**.

**Preparação das duas abas**

1. Abra **dois** Query Tools no `marco3` (*Tools → Query Tool*, duas vezes). Chame uma de **A** e a outra de **B** (use o nome da aba para não se perder).
2. Em cada uma, rode: `SET search_path TO academico;`
3. Em todos os passos abaixo, deixe **apenas um comando** no editor da aba (apague o anterior, cole o novo) e clique em ▶. Cada aba é uma sessão independente e mantém a transação aberta entre os comandos.

**Preparar o cenário (aba A)** — repita este bloco antes de cada uma das três demonstrações:

```sql
SELECT fn_reset_cenario_concorrencia(1);
```
```sql
SELECT * FROM vw_conferencia_vagas WHERE turma = 'CONC';
-- esperado: vagas = 1, matriculados = 0, situacao = ok
```

#### a) A anomalia (sem proteção)

Siga a ordem exata dos passos (a coluna diz em qual aba rodar):

| Passo | Aba | Comando |
|---|---|---|
| 1 | A | `BEGIN;` |
| 2 | A | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (1, (SELECT id_turma FROM tb_turma WHERE codigo = 'CONC'));` |
| 3 | B | `BEGIN;` |
| 4 | B | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (2, (SELECT id_turma FROM tb_turma WHERE codigo = 'CONC'));` **passa**, mesmo com a vaga "ocupada" pela aba A |
| 5 | A | `COMMIT;` |
| 6 | B | `COMMIT;` |
| 7 | qualquer | `SELECT * FROM vw_conferencia_vagas WHERE turma = 'CONC';` |

Resultado esperado no passo 7: `matriculados = 2`, `excesso = 1`, `situacao = ANOMALIA: turma estourou`.

#### b) Correção 1: bloqueio explícito (`FOR UPDATE`)

Rode o bloco "Preparar o cenário" de novo (aba A) e siga:

| Passo | Aba | Comando |
|---|---|---|
| 1 | A | `BEGIN;` |
| 2 | A | `SELECT vagas FROM tb_turma WHERE codigo = 'CONC' FOR UPDATE;` (tranca a turma) |
| 3 | A | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (1, (SELECT id_turma FROM tb_turma WHERE codigo = 'CONC'));` |
| 4 | B | `BEGIN;` |
| 5 | B | `SELECT vagas FROM tb_turma WHERE codigo = 'CONC' FOR UPDATE;` **fica esperando** (a aba mostra o relógio girando) |
| 6 | A | `COMMIT;` (libera a aba B) |
| 7 | B | o `SELECT` termina; rode `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (2, (SELECT id_turma FROM tb_turma WHERE codigo = 'CONC'));` |
| 8 | B | `ROLLBACK;` |

Resultado esperado no passo 7: **ERRO `Turma ... sem vagas (1 de 1)`**. A aba B esperou, enxergou a matrícula de A e foi recusada. A conferência final mostra `matriculados = 1`, `ok`.

#### c) Correção 2: nível `SERIALIZABLE`

Rode o bloco "Preparar o cenário" de novo (aba A) e siga:

| Passo | Aba | Comando |
|---|---|---|
| 1 | A | `BEGIN ISOLATION LEVEL SERIALIZABLE;` |
| 2 | A | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (1, (SELECT id_turma FROM tb_turma WHERE codigo = 'CONC'));` |
| 3 | B | `BEGIN ISOLATION LEVEL SERIALIZABLE;` |
| 4 | B | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (2, (SELECT id_turma FROM tb_turma WHERE codigo = 'CONC'));` (passa, sem esperar) |
| 5 | A | `COMMIT;` (ok) |
| 6 | B | `COMMIT;` |
| 7 | B | `ROLLBACK;` |
| 8 | B | repita os passos 3 e 4 (a "retentativa") |

Resultado esperado: no passo 6, **ERRO `could not serialize access due to read/write dependencies among transactions`** (código `40001`). No passo 8, o banco responde **ERRO `Turma ... sem vagas (1 de 1)`**, que é o resultado correto. Depois de um erro dentro de `BEGIN`, a aba só aceita `ROLLBACK;`.

Se uma aba ficar travada em "executando", vá à outra aba e termine a transação dela (`COMMIT;` ou `ROLLBACK;`). Para recomeçar do zero, rode `ROLLBACK;` nas duas abas e o bloco "Preparar o cenário".

#### d) Medição com carga real (terminal)

```powershell
docker exec bd2_postgres bash /tmp/scripts/medir_concorrencia.sh
```

Resultado medido (10 rodadas, 20 alunos disputando 5 vagas; o correto são 50 matrículas aceitas):

| Modo | Aceitas | Estouro | Latência média | Retentativas |
|---|---:|---:|---:|---:|
| Sem proteção (`READ COMMITTED`) | 200 | **150** | 46 ms | 0 |
| `FOR UPDATE` | 50 | 0 | 201 ms | 0 |
| `SERIALIZABLE` (com retry) | 50 | 0 | 181 ms | 11.078 |

Comparação completa entre as duas correções: `docs/CONCORRENCIA.md`. Pergunta clássica da arguição: `REPEATABLE READ` **não** resolve, porque no PostgreSQL ele continua sem ver a outra transação.

### 6.4 Segurança: papéis e *row-level security*

**Onde:** pgAdmin (Query Tool).

Papéis: `aluno`, `secretaria` e `coordenacao`. Logins de demonstração (senha `demo`, só de laboratório): `a10000000001` e `a10000000002` (alunos; o login é a letra `a` mais o CPF), `sec_maria` e `coord_cco`.

Rode o `docs/roteiro_demo_seguranca.sql` no Query Tool, bloco a bloco; ele indica o resultado esperado de cada comando. O essencial:

```sql
SET search_path TO academico;
SET ROLE a10000000001;
SELECT count(*) FROM tb_matricula;        -- 3 (só as dele; o dono do banco vê 300)
SELECT count(*) FROM tb_historico;        -- 3
SELECT * FROM vw_historico_aluno WHERE cpf_aluno = '10000000002';   -- 0 linhas: não vê o histórico de outro aluno

RESET ROLE;
SET ROLE coord_cco;
SELECT cpf FROM tb_aluno LIMIT 1;         -- ERRO: permission denied (a coordenação não lê CPF)
RESET ROLE;
```

O dono do banco (`bd2`, superusuário) ignora a RLS; por isso a demonstração usa `SET ROLE`. Explicação completa: `docs/SEGURANCA_E_OPERACAO.md`.

### 6.5 Backup e restauração ao vivo

**Onde:** terminal; a conferência antes e depois é no pgAdmin.

> **A ordem importa: o backup vem ANTES do desastre.** Um backup feito depois do `DROP SCHEMA` guarda um banco vazio (o arquivo `.dump` fica com menos de 1 KB) e a restauração não traz nada de volta. Um dump bom do `marco3` tem dezenas de KB.

**a) Antes do desastre, no pgAdmin**, confira os números:

```sql
SELECT (SELECT count(*) FROM academico.tb_matricula) AS matriculas,
       (SELECT count(*) FROM academico.tb_historico WHERE media_geral IS NOT NULL) AS com_nota;   -- 300 | 240
```

Se o schema `perf` do `07` estiver no banco, apague-o antes (`DROP SCHEMA IF EXISTS perf CASCADE;`): ele carrega cerca de 200 MB de dados de teste.

**b) Gerar o backup** e copiá-lo para o seu computador (a última linha é obrigatória: o sistema de arquivos do contêiner é apagado em `docker compose down`):

```powershell
docker cp scripts bd2_postgres:/tmp/
docker exec bd2_postgres bash /tmp/scripts/backup.sh
docker cp bd2_postgres:/backup/. ./backup
docker exec bd2_postgres ls -l /backup       # confira o tamanho do .dump: dezenas de KB, não 860 bytes
```

São gerados dois arquivos: `marco3_AAAAMMDD_HHMMSS.dump` (o banco inteiro) e `globais_AAAAMMDD_HHMMSS.sql` (os papéis, que o `pg_dump` não inclui). O `/.` no fim de `/backup/.` copia o **conteúdo** da pasta; sem ele, se `./backup` já existir, o Docker cria `backup\backup` e a restauração não acha os arquivos. Os nomes levam a data e a hora da execução, por exemplo `marco3_20261109_064540.dump`. **`AAAAMMDD_HHMMSS` é só um modelo: copie o nome real que o `ls` mostrou.**

**c) Desastre:**

```powershell
docker exec bd2_postgres psql -U bd2 -d marco3 -c "DROP SCHEMA academico CASCADE"
```

No pgAdmin, *Refresh* no `marco3`: o schema `academico` sumiu e qualquer consulta falha.

**d) Restaurar.** O jeito mais seguro é deixar o PowerShell escolher o dump mais recente, sem digitar o nome:

```powershell
$dump = docker exec bd2_postgres sh -c "ls -t /backup/marco3_*.dump | head -1"
$dump                                         # confira o nome impresso
docker exec bd2_postgres pg_restore -U bd2 -d marco3 --no-owner --exit-on-error $dump
```

Ou digitando o nome real: `docker exec bd2_postgres pg_restore -U bd2 -d marco3 --no-owner --exit-on-error /backup/marco3_20261109_064540.dump`.

**e) Conferir:** rodar de novo o `SELECT` do item (a) e voltar a ver `300 | 240`. A segurança volta junto:

```sql
SET ROLE a10000000001;  SELECT count(*) FROM academico.tb_matricula;  RESET ROLE;   -- 3
```

**Outras formas de restaurar** (detalhes em `docs/BACKUP_RESTAURACAO.md`):

```powershell
# num banco paralelo, sem tocar no original
docker exec bd2_postgres bash /tmp/scripts/restaurar.sh /backup/marco3_AAAAMMDD_HHMMSS.dump marco3_restaurado

# em servidor novo (docker compose down -v; docker compose up -d), recriando os papéis antes
docker cp scripts bd2_postgres:/tmp/
docker cp ./backup/. bd2_postgres:/backup
docker exec bd2_postgres bash /tmp/scripts/restaurar.sh /backup/marco3_AAAAMMDD_HHMMSS.dump marco3 /backup/globais_AAAAMMDD_HHMMSS.sql
```

---

## 7. Evidências

| Evidência | Arquivo |
|---|---|
| `EXPLAIN (ANALYZE, BUFFERS)` antes e depois de cada índice (saída completa do `07`) | `docs/evidencias_indices.txt` |
| Medição de concorrência com `pgbench` | `docs/evidencias_concorrencia.txt` |
| Explicação dos índices e da medição | `docs/INDICES_E_DESEMPENHO.md` |
| Anomalia, correções e comparação | `docs/CONCORRENCIA.md` |
| Papéis, RLS, views e política da materialized view | `docs/SEGURANCA_E_OPERACAO.md` |
| Backup e restauração | `docs/BACKUP_RESTAURACAO.md` |
| Roteiro de perguntas e respostas da arguição | `guia_apresentacao_marco2.md` |

Os arquivos de evidência são a saída real da execução no Docker do grupo. Para refazê-los: `.\scripts\rodar_tudo.ps1 -GravarEvidencias`. Os milissegundos variam de máquina para máquina; o que se repete é o plano escolhido e o número de páginas lidas.

---

## 8. Modelo lógico

O modelo lógico é o de **16 tabelas** (prefixo `tb_`) definido pelo professor, igual ao de todos os grupos. O diagrama está em `docs/modelo_logico.drawio` (abre no diagrams.net ou na extensão *Draw.io* do VS Code).

| Área | Tabelas |
|---|---|
| Estrutura acadêmica | `tb_campus`, `tb_curso`, `tb_curriculo`, `tb_disciplina`, `tb_curriculo_disciplina`, `tb_pre_requisito` |
| Oferta | `tb_professor`, `tb_sala`, `tb_periodo_letivo`, `tb_turma`, `tb_turma_horario`, `tb_feriado` |
| Vida acadêmica | `tb_aluno`, `tb_matricula`, `tb_historico` |
| Auditoria | `tb_log_matricula` |

Ajustes feitos no desenho (documentados no cabeçalho de `sql/01_tipos.sql`):

1. `tb_feriado`: a chave primária estava como `id_turma` e virou `id_feriado`.
2. `tb_turma`: a coluna `tuno` virou `turno`.
3. `tb_curriculo_disciplina.tipo`: o tipo era `vinculo_t` e virou `tipo_disc_t` (obrigatória ou optativa).
4. `tb_turma_horario`: `faixa varchar(20)` virou `hora_inicio` e `hora_fim`, para o banco comparar horários e impedir duas turmas na mesma sala.

Regras que o desenho não define e que o grupo assumiu: situação do aluno (frequência mínima de 75% e média 6), média ponderada (40% da A1 e 60% da A2, com a P3 substituindo a menor nota), `dia_semana` no padrão ISO (1 é segunda) e os triggers que criam o histórico e gravam o log a cada matrícula.

---

## 9. Estrutura do repositório

```
.
├── README.md                    este arquivo
├── AUTORES.md                   frente de cada integrante
├── docker-compose.yml           PostgreSQL 16 + pgAdmin
├── initdb/                      carga do banco de prática "matricula" (professor)
├── sql/                         scripts SQL numerados na ordem de execução (01 a 09)
├── scripts/                     rodar_tudo.ps1, medir_concorrencia.sh, backup.sh, restaurar.sh
├── docs/                        explicações, evidências, modelo lógico e roteiro de segurança
│   └── README_ambiente_professor.md   README original do ambiente (DBeaver, search_path)
├── guia_apresentacao_marco2.md  perguntas e respostas para a arguição
├── TESTE_AMBIENTE.md            teste do ambiente do Marco 1
├── backup/                      dumps gerados pelo backup.sh (ignorados pelo Git, ver .gitignore)
```

---

## 10. Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| `psql: option requires an argument -- 'c'` | o comando foi copiado sem o texto entre aspas depois do `-c`; use a linha completa da seção 4.2 |
| `database "marco3" already exists` | o banco ficou de uma rodada anterior: `docker exec bd2_postgres psql -U bd2 -d matricula -c "DROP DATABASE marco3 WITH (FORCE)"` e recrie |
| `schema "academico" already exists` ao rodar o `01` | o `marco3` não estava vazio (sobrou de uma rodada anterior). No pgAdmin, em um Query Tool do `marco3`, rode `DROP SCHEMA IF EXISTS academico CASCADE;` e `DROP SCHEMA IF EXISTS perf CASCADE;` (um de cada vez) e comece de novo pelo `01`. Os papéis do `09` e a extensão do `01` são recriados sem erro. No terminal: veja a linha acima |
| `relation "tb_aluno" does not exist` | faltou `SET search_path TO academico;` no editor |
| pgAdmin: `The connection has timed out` | na primeira subida ele demora de 1 a 3 minutos; veja `docker compose logs pgadmin --tail 30` e recarregue a página |
| pgAdmin não conecta ao banco | o host é `postgres` (nome do serviço), e não `localhost` |
| o seletor de arquivos do pgAdmin não mostra `/projeto/sql` | o contêiner do pgAdmin foi criado antes de o volume existir: `docker compose up -d --force-recreate pgadmin`. Ou cole o script copiado do VS Code |
| só aparece o resultado da última consulta no pgAdmin | selecione uma consulta por vez antes do F5 |
| `VACUUM cannot run inside a transaction block` | o `07_indices.sql` foi rodado no pgAdmin; rode pelo `psql` (seção 3.6) |
| `role "aluno" does not exist` ao restaurar | falta o arquivo de papéis: passe o `globais_*.sql` como 3º argumento do `restaurar.sh` |
| `port is already allocated` | outro programa usa a porta 5432 ou 8080; feche-o ou mude a porta no `docker-compose.yml` |
| `a execução de scripts está desabilitada` | rode com `powershell -ExecutionPolicy Bypass -File .\scripts\rodar_tudo.ps1` |
| acentos quebrados (`proteção` vira `prote├º├úo`) nos arquivos de evidência | o `Tee-Object` do PowerShell regrava em UTF-16; use `-GravarEvidencias` ou `\| Out-File -Encoding utf8` |
| `docker compose down -v` apagou o `marco3` | é o esperado: refaça a seção 3.1 em diante, ou rode o `rodar_tudo.ps1` |
| os números de tempo da evidência diferem dos do README | os milissegundos variam por máquina; o plano e as páginas lidas se repetem |

---

## 11. Autores

| Frente (Seção 3 do edital) | Responsável |
|---|---|
| Modelagem Física e Desempenho | Pedro |
| Transações e Concorrência | Victor |
| Administração e Operação | Sofia |

Detalhes e arquivos de cada frente em [`AUTORES.md`](AUTORES.md).
