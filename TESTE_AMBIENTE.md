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
docker exec -i bd2_postgres psql -U bd2 -d matricula -c "DROP DATABASE IF EXISTS marco1;"
docker exec -i bd2_postgres psql -U bd2 -d matricula -c "CREATE DATABASE marco1;"
```

Aí sim, rode cada arquivo de `sql/` na ordem contra o banco `marco1`
(via `psql`, DBeaver ou pgAdmin — no pgAdmin, conecte no banco `marco1`,
não no `matricula`, e rode `SET search_path TO academico;` antes):

```bash
docker exec -i bd2_postgres psql -U bd2 -d marco1 < sql/01_tipos.sql
docker exec -i bd2_postgres psql -U bd2 -d marco1 < sql/02_tabelas.sql
docker exec -i bd2_postgres psql -U bd2 -d marco1 < sql/03_restricoes.sql
docker exec -i bd2_postgres psql -U bd2 -d marco1 < sql/04_carga.sql
docker exec -i bd2_postgres psql -U bd2 -d marco1 < sql/05_consultas.sql
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
O Resultado de: 01_tipos.sql foi ERRO.
O script foi executado diretamente pelo PostgreSQL utilizando:

  `Get-Content .\sql\01_tipos.sql | docker exec -i bd2_postgres psql -U bd2 -d matricula`

Foram identificados erros informando que o schema `academico` e os tipos/domínios (`turno_t`, `tipo_disc_t`, `vinculo_t`, `status_mat_t`, `situacao_t`, `tipo_sala_t`, `nota_t`, `pct_t` e `timerange`) já existem. A causa identificada é que o `docker-compose.yml` monta a pasta `initdb/` no PostgreSQL e, na inicialização do banco vazio, os arquivos `initdb/01_modelo.sql` e `initdb/02_dados.sql` já criam e carregam esses objetos.

O Resultado de: 02_tabelas.sql foi
```

## 3. Conferência dos mínimos do Marco 1

Rode e cole o resultado de cada contagem:

```sql
SELECT count(*) FROM aluno;       -- mínimo exigido: 100
SELECT count(*) FROM turma;       -- mínimo exigido: 6
SELECT count(*) FROM matricula;   -- mínimo exigido: 300
```

```
(cole aqui os três números)
```

- [ ] Os três mínimos do edital foram atingidos

## 4. As 10 consultas rodam e fazem sentido

Rode as 10 consultas de `sql/05_consultas.sql` uma a uma.

- [ ] Todas as 10 executaram sem erro
- Para as duas recursivas (Consulta 6 e Consulta 7) e a Consulta 3 (junção
  externa com agregação), cole uma amostra do resultado (bastam as
  primeiras linhas) — são as três que mais provavelmente caem na
  arguição cruzada:

```
Consulta 3 (ocupação de turmas):
(cole aqui)

Consulta 6 (árvore de pré-requisitos de ENG001):
(cole aqui)

Consulta 7 (disciplinas que o aluno já pode cursar):
(cole aqui)
```

## 5. Problemas encontrados e correções

Liste aqui qualquer coisa que você teve que corrigir para o ambiente
rodar do zero (mesmo pequena — isso também é parte do seu trabalho no
Marco 1, e pode virar pergunta na arguição cruzada sobre por que o
ambiente precisou desse ajuste):

```
(descreva, ou escreva "nada a corrigir")
```

---

Depois de preencher, commit este arquivo com uma mensagem tipo:
`test: valida ambiente do zero e execucao dos scripts do Marco 1`
