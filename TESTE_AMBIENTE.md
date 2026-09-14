# Teste do ambiente — Marco 1

Responsável: **Victor**

O edital pede, na Seção 9: "Teste o ambiente antes da apresentação." Este
documento é a evidência desse teste — suba o ambiente do zero, rode os
scripts na ordem, confira os números mínimos e execute as 10 consultas.
Preencha os campos abaixo com o que você realmente observar (cole saída
real do terminal/DBeaver, não invente números).

## 1. Subida do zero

```bash
docker compose down -v      # apaga qualquer estado anterior
docker compose up -d
docker compose logs -f      # acompanhe até a inicialização terminar
```

- [ ] `docker compose ps` mostra os dois serviços (`bd2_postgres`, `bd2_pgadmin`) saudáveis
- Cole aqui a saída de `docker compose ps`:

```
NAME           IMAGE                   COMMAND                  SERVICE    CREATED         STATUS                   PORTS
bd2_pgadmin    dpage/pgadmin4:latest   "/entrypoint.sh"         pgadmin    2 minutes ago   Up 2 minutes             0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
bd2_postgres   postgres:16             "docker-entrypoint.s…"   postgres   2 minutes ago   Up 2 minutes (healthy)   0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
```

## 2. Execução dos scripts, na ordem

**Importante:** o banco `matricula` (que já vem pronto no container) é o
ambiente de PRÁTICA do professor — os scripts de `initdb/` carregam o
schema/dados dele automaticamente, e não tem nada a ver com o que o
grupo entregou. Os scripts do NOSSO projeto (`sql/01` a `sql/05`) têm que
rodar num banco separado e vazio, criado à mão, senão colidem com o
schema do professor ("already exists" pra tudo). Depois de QUALQUER
`docker compose down -v` + `up -d`, esse banco separado desaparece
(ele não é recriado automaticamente) — então o primeiro passo é sempre
recriá-lo:

```bash
docker exec -i bd2_postgres psql -U bd2 -d matricula -c "DROP DATABASE IF EXISTS marco3;"
docker exec -i bd2_postgres psql -U bd2 -d matricula -c "CREATE DATABASE marco3 TEMPLATE template0;"
```

Aí sim, rode cada arquivo de `sql/` na ordem contra o banco `marco3`
(via `psql`, DBeaver ou pgAdmin — no pgAdmin, conecte no banco `marco3`,
não no `matricula`, e rode `SET search_path TO academico;` antes):

```bash
docker exec -i bd2_postgres psql -U bd2 -d marco3 < sql/01_tipos.sql
docker exec -i bd2_postgres psql -U bd2 -d marco3 < sql/02_tabelas.sql
docker exec -i bd2_postgres psql -U bd2 -d marco3 < sql/03_restricoes.sql
docker exec -i bd2_postgres psql -U bd2 -d marco3 < sql/04_carga.sql
docker exec -i bd2_postgres psql -U bd2 -d marco3 < sql/05_consultas.sql
```

Ordem dos arquivos:
1. `sql/01_tipos.sql`
2. `sql/02_tabelas.sql`
3. `sql/03_restricoes.sql`
4. `sql/04_carga.sql`
5. `sql/05_consultas.sql`

- [ ] Os quatro primeiros rodaram sem erro, do zero, nesta ordem
- Se algo quebrou, anote aqui o erro e o que você mudou pra corrigir:

```
Os quatro primeiros scripts foram executados sem erro no banco separado marco3, criado com TEMPLATE template0.

01_tipos.sql: executado sem erro.
02_tabelas.sql: executado sem erro.
03_restricoes.sql: executado sem erro.
04_carga.sql: executado sem erro.

```

## 3. Conferência dos mínimos do Marco 1

Rode e cole o resultado de cada contagem:

```sql
SELECT count(*) FROM aluno;       -- mínimo exigido: 100
SELECT count(*) FROM turma;       -- mínimo exigido: 6
SELECT count(*) FROM matricula;   -- mínimo exigido: 300
```

```
aluno: 120
turma: 7
matricula: 300
```

- [ x ] Os três mínimos do edital foram atingidos

## 4. As 10 consultas rodam e fazem sentido

Rode as 10 consultas de `sql/05_consultas.sql` uma a uma.

- [x] Todas as 10 executaram sem erro
- Para as duas recursivas (Consulta 6 e Consulta 7) e a Consulta 3 (junção
  externa com agregação), cole uma amostra do resultado (bastam as
  primeiras linhas) — são as três que mais provavelmente caem na
  arguição cruzada:

```
Consulta 3 (ocupação de turmas):
turma_id | codigo | disciplina | vagas | ocupadas | vagas_restantes
7        | T07    | BD001      | 30    | 0        | 30

Consulta 6 (árvore de pré-requisitos de ENG001):
1 | POO001 | Programação Orientada a Objetos
2 | ALG001 | Algoritmos e Programação

Consulta 7 (disciplinas que o aluno já pode cursar):
ALG001 | Algoritmos e Programação
BD001  | Banco de Dados
```

## 5. Problemas encontrados e correções

Liste aqui qualquer coisa que você teve que corrigir para o ambiente
rodar do zero (mesmo pequena — isso também é parte do seu trabalho no
Marco 1, e pode virar pergunta na arguição cruzada sobre por que o
ambiente precisou desse ajuste):

```
1. O banco matricula já possui dados e objetos carregados pelo initdb, portanto os scripts do grupo foram testados em um banco separado e vazio (marco3).

2. A Consulta 8 precisou de um cast para numeric na função ROUND, pois PERCENT_RANK() retorna double precision.

3. Foi adicionada a turma T07 sem matrículas para demonstrar o funcionamento do LEFT JOIN na Consulta 3.

```

---

Depois de preencher, commit este arquivo com uma mensagem tipo:
`test: valida ambiente do zero e execucao dos scripts do Marco 1`
