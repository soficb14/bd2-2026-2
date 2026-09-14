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
(cole aqui)
```

## 2. Execução dos scripts, na ordem

Rode cada arquivo de `sql/` na ordem (via `psql`, DBeaver ou pgAdmin, com
`SET search_path TO academico;` antes):

1. `sql/01_tipos.sql`
2. `sql/02_tabelas.sql`
3. `sql/03_restricoes.sql`
4. `sql/04_carga.sql`
5. `sql/05_consultas.sql`

- [ ] Os quatro primeiros rodaram sem erro, do zero, nesta ordem
- Se algo quebrou, anote aqui o erro e o que você mudou pra corrigir:

```
(cole aqui, ou escreva "nenhum erro")
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
