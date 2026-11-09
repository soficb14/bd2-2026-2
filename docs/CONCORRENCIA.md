# Transações e concorrência — a disputa pela última vaga

**Frente:** Transações e Concorrência · **Scripts:** `sql/08_concorrencia.sql`, `scripts/medir_concorrencia.sh`
**Evidência medida:** `docs/evidencias_concorrencia.txt` (saída do `scripts/medir_concorrencia.sh` no Docker do grupo)

## 1. O problema

Uma turma tem **1 vaga restante**. Dois alunos clicam em "matricular" ao mesmo tempo.

O trigger `fn_valida_vaga()` (em `sql/03_restricoes.sql`) faz: *conta as matrículas ativas da turma; se já houver `vagas`, recusa*.
Isso funciona quando as matrículas chegam uma por vez. Com duas transações simultâneas, no nível de isolamento padrão
(**READ COMMITTED**), cada transação só enxerga o que já foi *commitado*:

| Tempo | Sessão A (aluno 1) | Sessão B (aluno 2) |
|---|---|---|
| t1 | `BEGIN; INSERT` — trigger conta **0** ocupadas, aceita | |
| t2 | | `BEGIN; INSERT` — trigger conta **0** (A não commitou, B não a vê), aceita |
| t3 | `COMMIT` | |
| t4 | | `COMMIT` |
| fim | **2 matriculados em uma turma de 1 vaga** (overbooking) | |

É a anomalia clássica de **verificar-e-depois-escrever** (*check-then-act*): a verificação e a escrita não são atômicas
entre transações. O trigger é necessário, mas **não é suficiente**. Em termos de SQL padrão, é um caso de *write skew*:
as duas transações leem o mesmo estado, e cada uma escreve uma linha diferente que, somadas, violam a regra.

## 2. Preparar o cenário (uma vez, e sempre que quiser repetir)

Abra **duas abas** do Query Tool no pgAdmin, ambas no banco `marco3`. Em cada aba, comece com `SET search_path TO academico;`.
Rode cada comando **separadamente** (selecione a linha e aperte F5) e respeite a ordem indicada.

```sql
-- ABA A  (prepara: turma de teste "CONC" com 1 vaga e nenhuma matrícula)
SELECT fn_reset_cenario_concorrencia(1);
SELECT * FROM vw_conferencia_vagas WHERE turma = 'CONC';   -- vagas=1, matriculados=0, ok
```

## 3. Reproduzindo a anomalia

| Passo | Aba | Comando |
|---|---|---|
| 1 | A | `BEGIN;` |
| 2 | A | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (1, (SELECT id_turma FROM tb_turma WHERE codigo='CONC'));` |
| 3 | B | `BEGIN;` |
| 4 | B | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (2, (SELECT id_turma FROM tb_turma WHERE codigo='CONC'));` ← **passa**, mesmo com a vaga "ocupada" pela aba A |
| 5 | A | `COMMIT;` |
| 6 | B | `COMMIT;` |
| 7 | qualquer | `SELECT * FROM vw_conferencia_vagas WHERE turma='CONC';` → `matriculados = 2`, `excesso = 1`, **ANOMALIA** |

## 4. Correção 1 — bloqueio explícito (`SELECT ... FOR UPDATE`)

Ideia: antes de contar/inserir, **trancar a linha da turma**. Quem chega depois *espera* o primeiro terminar e então enxerga o resultado dele.
(Pessimista: "evito o conflito esperando".)

Rodar `SELECT fn_reset_cenario_concorrencia(1);` e depois:

| Passo | Aba | Comando |
|---|---|---|
| 1 | A | `BEGIN;` |
| 2 | A | `SELECT vagas FROM tb_turma WHERE codigo='CONC' FOR UPDATE;`  ← tranca a turma |
| 3 | A | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (1, (SELECT id_turma FROM tb_turma WHERE codigo='CONC'));` |
| 4 | B | `BEGIN;` |
| 5 | B | `SELECT vagas FROM tb_turma WHERE codigo='CONC' FOR UPDATE;`  ← **fica esperando** (a aba mostra "executando…") |
| 6 | A | `COMMIT;`  ← libera a aba B |
| 7 | B | (o SELECT termina) `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (2, (SELECT id_turma FROM tb_turma WHERE codigo='CONC'));` → **ERRO: Turma … sem vagas (1 de 1)** |
| 8 | B | `ROLLBACK;` |

Por que funciona: o `INSERT` da aba B só roda *depois* do commit de A. O trigger então conta 1 ocupada e recusa. A regra passou a valer de forma atômica.

## 5. Correção 2 — nível de isolamento `SERIALIZABLE`

Ideia: deixar as duas transações rodarem juntas e pedir ao banco que garanta que o resultado seja **equivalente a uma execução em
sequência**. Ao detectar que isso é impossível, o banco **aborta uma delas** com `SQLSTATE 40001`, e a aplicação **repete** a transação.
(Otimista: "deixo correr e desfaço se houver conflito".)

Rodar `SELECT fn_reset_cenario_concorrencia(1);` e depois:

| Passo | Aba | Comando |
|---|---|---|
| 1 | A | `BEGIN ISOLATION LEVEL SERIALIZABLE;` |
| 2 | A | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (1, (SELECT id_turma FROM tb_turma WHERE codigo='CONC'));` |
| 3 | B | `BEGIN ISOLATION LEVEL SERIALIZABLE;` |
| 4 | B | `INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (2, (SELECT id_turma FROM tb_turma WHERE codigo='CONC'));` (passa, sem esperar) |
| 5 | A | `COMMIT;` (ok) |
| 6 | B | `COMMIT;` → **ERRO 40001: could not serialize access due to read/write dependencies among transactions** ("The transaction might succeed if retried") |
| 7 | B | `ROLLBACK;` e **repetir a transação inteira** (passos 3–4 em diante) |
| 8 | B | No retry, o trigger enxerga a matrícula de A e responde **ERRO: Turma … sem vagas (1 de 1)** — o resultado correto |

Pergunta clássica: *e `REPEATABLE READ`?* **Não resolve.** No PostgreSQL ele é *snapshot isolation*: cada transação continua sem ver a outra e
as duas ainda entram (testado: 2 matriculados em 1 vaga). Só `SERIALIZABLE` detecta essa dependência cruzada entre leituras e escritas.

Regra prática: quem commita **depois** é quem recebe o `40001`. Num sistema real, o código da aplicação precisa de um *laço de retentativa*
para `SQLSTATE 40001` (e `40P01`, deadlock); sem ele, o usuário veria um erro aleatório.

## 6. Comparação fundamentada

Medição com carga concorrente real (`scripts/medir_concorrencia.sh`, `pgbench`): **10 rodadas × 20 alunos disputando 5 vagas** (o correto: 50 matrículas aceitas). *Valores da execução de 09/11/2026 no Docker do grupo (PostgreSQL 16, modelo de 16 tabelas); a saída completa está em `docs/evidencias_concorrencia.txt`.*
Cada transação faz "trabalho extra" de 20 ms antes do commit (representa e-mail, log etc.) para alargar a janela da corrida.

| Modo | Matrículas aceitas | Estouro (anomalia) | Latência média | Retentativas |
|---|---:|---:|---:|---:|
| Sem proteção (READ COMMITTED) | 200 | **150** | 46 ms | 0 |
| FOR UPDATE | 50 | 0 | 201 ms | 0 |
| SERIALIZABLE (+ retry) | 50 | 0 | 181 ms | 11078 |

*(Os valores absolutos variam por máquina; o que vale é o padrão: sem proteção estoura, as duas correções dão estouro 0.)*

| Critério | `FOR UPDATE` (bloqueio explícito) | `SERIALIZABLE` (isolamento) |
|---|---|---|
| **Filosofia** | Pessimista: espera para não conflitar | Otimista: executa e aborta se conflitar |
| **Custo** | Baixo: um bloqueio de linha. | Maior: o banco rastreia leituras (locks de predicado SIREAD) em todas as transações serializáveis, com mais memória e CPU. |
| **Contenção** | Quem disputa a mesma turma **espera em fila** (latência sobe, vazão cai nessa turma); turmas diferentes não interferem. | Ninguém espera para começar, mas o **trabalho é desperdiçado** quando uma transação aborta e refaz. Aqui, todos os 20 clientes disputam a mesma linha, que é o pior caso. |
| **Necessidade de retentativa** | **Não.** Quem perde recebe o erro de negócio ("sem vagas") direto. | **Sim, obrigatória.** A aplicação precisa tratar `40001` e repetir. |
| **Risco** | *Deadlock* se uma transação trancar várias turmas em ordens diferentes (solução: sempre trancar em ordem de `id`). Exige que **todo** caminho de matrícula lembre do `FOR UPDATE`. | Falsos positivos: aborta transações que não precisavam. Retentativas em cascata sob alta disputa (11078 acima). |
| **Quando usar** | Disputa por **um recurso conhecido** (vaga de turma): o caso do projeto. | Regras que envolvem **muitas linhas/tabelas** difíceis de trancar uma a uma, e quando o código já tem retry. |

**Conclusão:** para a última vaga, o `FOR UPDATE` é a escolha melhor: o ponto de disputa é uma linha conhecida (a turma), a espera é curta e a
resposta ao usuário é direta. `SERIALIZABLE` é mais genérico e protege sem que cada caminho do código lembre de travar, mas cobra retentativas.

**Melhor ainda (estrutural, sugestão futura):** mover o `SELECT ... FOR UPDATE` para *dentro* de `fn_valida_vaga()`. Assim a regra fica garantida
no banco para **qualquer** cliente, sem depender da disciplina da aplicação. Não alteramos o trigger do Marco 1 para manter o que foi entregue e testado.

## 7. Como repetir a medição

```powershell
docker cp scripts bd2_postgres:/tmp/
docker exec bd2_postgres bash /tmp/scripts/medir_concorrencia.sh
```

Parâmetros opcionais: `docker exec -e RODADAS=20 -e CLIENTES=30 -e VAGAS=5 bd2_postgres bash /tmp/scripts/medir_concorrencia.sh`.
Salve a saída em `docs/evidencias_concorrencia.txt`.
