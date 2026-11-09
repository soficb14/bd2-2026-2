# Guia de apresentação e arguição — Marco 2
*(material de estudo do grupo; não precisa ir para o repositório)*

## 1. Como a nota funciona

- **A2 = 4,0 (artefato do grupo) + 6,0 (apresentação).** Dos 6,0: demonstração ao vivo **1,5** (do grupo), resposta à questão sorteada **3,5** (individual), precisão técnica e tempo **1,0** (individual).
- **A arguição é cruzada.** Cada um responde, sozinho e sem IA, sobre a frente **de outro colega**. Não saber explicar zera o critério individual (3,5). Esse é o maior risco: **todo mundo precisa dominar as três frentes.**
- **A demo tem que rodar ao vivo.** Sem vídeo nem captura de tela. Se não rodar: −1,5. Estourar o tempo: até −0,5.
- Commit único ou trabalho concentrado em uma pessoa: até −1,0. Cada um commita a **própria** parte.

## 2. Pré-voo (fazer na véspera, na máquina que vai apresentar)

1. `docker compose down -v` e `docker compose up -d`; esperar o `bd2_postgres` ficar *healthy*.
2. Criar `marco3` e rodar os scripts 01 a 09 pelo passo a passo do `README.md` (ou `.\scripts\rodar_tudo.ps1`). **Nenhum `ERROR` pode aparecer.**
3. Conferir: `SELECT count(*)` em `tb_aluno`/`tb_turma`/`tb_matricula` (120 / 7 ou 8 / 300) e `SELECT * FROM pg_trigger WHERE tgname='tg_valida_vaga'` (1 linha).
4. Fazer um backup (`backup.sh`) e **copiar para o computador** (`docker cp bd2_postgres:/backup/. ./backup`). Testar uma restauração.
5. No pgAdmin, deixar prontas **3 abas** do Query Tool em `marco3`: **Aba A**, **Aba B** e **Aba Papéis** (cada uma com `SET search_path TO academico;`). Fechar o resto.
6. Rodar `SELECT fn_reset_cenario_concorrencia(1);` e os roteiros uma vez, para saber o que esperar.
7. Ensaiar com cronômetro: **9 minutos** é pouco.

## 3. Roteiro da demo (~9 min)

| Min | Quem (sugestão) | O que mostrar |
|---|---|---|
| 0:00 | Frente 1 | Ambiente no ar (`docker compose ps`), pgAdmin, esquema `academico`; **restrições funcionando**: um `INSERT` que viola `CHECK`/`UNIQUE`/`FK`, outro que a trigger recusa (turma cheia) |
| 2:00 | Frente 1 | **`EXPLAIN (ANALYZE, BUFFERS)`** de uma consulta, antes e depois de um índice (parcial), com o ganho medido |
| 4:00 | Frente 2 | **Anomalia ao vivo** com as abas A e B (`docs/CONCORRENCIA.md` §3): 2 matriculados em 1 vaga. Depois a **correção 1** (`FOR UPDATE`, §4) e a **correção 2** (`SERIALIZABLE`, §5, mostrando o erro 40001 e o retry). 1 frase de comparação |
| 6:30 | Frente 3 | **RLS** (`docs/roteiro_demo_seguranca.sql`): como `a10000000001` vê só as 3 matrículas dele; tenta ver as do aluno 2 e vê 0 linhas; coordenação sem CPF |
| 8:00 | Frente 3 | **Restauração ao vivo**: `DROP SCHEMA academico CASCADE` → `pg_restore` → contagens de volta (`docs/BACKUP_RESTAURACAO.md` §2) |

Dica: deixe os comandos longos em um bloco de notas ao lado, prontos para colar. Digitar ao vivo consome o tempo.

## 4. Perguntas prováveis — Frente 2 (Transações e Concorrência)

**1. Por que o trigger de vagas não impede a anomalia?**
Em `READ COMMITTED` cada comando enxerga apenas o que já foi commitado. A sessão B conta as matrículas, não vê a de A (ainda sem commit) e também entra. A verificação e a escrita não são atômicas entre transações.

**2. Que tipo de anomalia é essa?**
*Check-then-act* / *write skew*: as duas transações leem o mesmo estado e escrevem linhas diferentes que, juntas, violam a regra (nenhuma sobrescreve a outra, por isso nem o `UNIQUE` pega).

**3. Como o `FOR UPDATE` resolve?**
Tranca a linha da turma. A sessão B espera o commit de A. Quando B continua, o `INSERT` dela roda com um snapshot novo, vê a matrícula de A e o trigger recusa. Transforma a corrida em fila.

**4. E se um caminho do código esquecer o `FOR UPDATE`?**
A anomalia volta nesse caminho. Por isso o ideal é pôr o `FOR UPDATE` dentro do próprio trigger: a regra fica garantida no banco, para qualquer cliente.

**5. Como o `SERIALIZABLE` funciona?**
No PostgreSQL usa SSI (*Serializable Snapshot Isolation*): registra o que cada transação lê (locks de predicado, `SIREAD`, que **não bloqueiam ninguém**), detecta dependências cruzadas leitura→escrita entre as transações e, se houver um ciclo perigoso, aborta uma delas com `SQLSTATE 40001`.

**6. Por que precisa de retentativa?**
O banco só desfaz a transação; quem refaz é a aplicação. O erro 40001 diz "pode funcionar se tentar de novo". No retry, o trigger já enxerga a matrícula da outra transação e responde "sem vagas".

**7. `REPEATABLE READ` resolveria?**
Não. No PostgreSQL ele é *snapshot isolation*: as duas transações continuam sem se enxergar e ambas entram (testado). Só `SERIALIZABLE` detecta o *write skew*.

**8. Qual das duas você usaria e por quê?**
`FOR UPDATE`, porque o ponto de disputa é uma linha conhecida (a turma): espera curta, sem retentativas, erro de negócio direto. `SERIALIZABLE` é mais genérico, mas cobra retentativas e rastreamento (nos testes: milhares de retentativas contra 0 — conferir o número em `docs/evidencias_concorrencia.txt`).

**9. Existe risco de deadlock?**
No `FOR UPDATE`, se uma transação trancar várias turmas em ordens diferentes. Solução: trancar sempre em ordem crescente de `id`.

**10. Por que o benchmark tem 20 ms de espera antes do commit?**
Representa o trabalho extra de uma transação real (log, e-mail). Alarga a janela em que as transações se sobrepõem. Sem ela, a corrida seria curta demais para aparecer de forma confiável.

**11. Por que tanta retentativa no `SERIALIZABLE`?**
Foi o pior caso: 20 clientes disputando a **mesma** turma. Em uso real, os alunos se espalham por muitas turmas e os conflitos são raros.

## 5. Perguntas prováveis — Frente 3 (Administração e Operação)

**1. Por que uma materialized view e não uma view comum?**
Os indicadores juntam 7 tabelas e agregam o histórico inteiro; a view comum refaz tudo a cada consulta. A materializada guarda o resultado. O preço é ficar defasada, o que é aceitável porque os números só mudam no fechamento de notas.

**2. Qual a política de atualização e por que ela?**
Diária, de madrugada, e manual após o fechamento de notas, com `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Atualizar a cada escrita (trigger) deixaria a matrícula mais lenta sem benefício.

**3. O que o `CONCURRENTLY` exige?**
Um índice **único** na view (`uq_mv_indicadores_curso`) e que ela já esteja populada. Em troca, não bloqueia quem está lendo. Custo: refresh um pouco mais lento.

**4. Qual a diferença entre GRANT/REVOKE e RLS?**
GRANT decide quem acessa *a tabela ou a coluna*. RLS decide *quais linhas* dentro dela. Um aluno tem `SELECT` em `tb_matricula`, mas a policy só deixa passar as linhas dele.

**5. O que é `security_invoker` na `vw_historico_aluno`?**
Faz a view usar as permissões e a RLS de **quem consulta**, não do dono. Sem isso a view rodaria como dono (que ignora a RLS) e vazaria o histórico de todos.

**6. Por que `fn_aluno_id` é `SECURITY DEFINER` e recebe o usuário por parâmetro?**
Precisa ler `tb_aluno` sem passar pela RLS da própria `tb_aluno`. E dentro de `SECURITY DEFINER` o `current_user` vira o dono da função, então o login é passado como argumento.

**7. A armadilha do trigger de vagas com a RLS?**
Com RLS em `tb_matricula`, a contagem do trigger rodando como aluno enxergava só as matrículas dele e deixava ultrapassar o limite (testado: 2 em 1 vaga). Corrigimos tornando `fn_valida_vaga()` `SECURITY DEFINER` com `search_path` fixo.

**8. Como a coordenação fica sem ver o CPF?**
Privilégio **por coluna**: `GRANT SELECT (id_aluno, nome_aluno, email_aluno, ...) ON tb_aluno TO coordenacao`, sem `cpf` nem `nascimento`. `SELECT cpf` dá "permission denied" (o aluno nunca vê o histórico alheio porque `tb_historico` não tem `id_aluno`: a policy olha a matrícula).

**9. O dono das tabelas respeita a RLS?**
Não: o dono e o superusuário a ignoram (por isso a demo usa `SET ROLE`). Em produção, a aplicação não conectaria como dono e as tabelas teriam `FORCE ROW LEVEL SECURITY`.

**10. Por que o `pg_dump` não leva os papéis?**
Papéis são objetos do cluster, não do banco. Por isso o backup tem um segundo arquivo (`pg_dumpall --globals-only`). Sem ele, restaurar num servidor novo falha em `CREATE POLICY ... TO aluno`.

**11. Como você prova que o backup funciona?**
Restaura num banco paralelo (`restaurar.sh`) e confere contagens, policies e trigger, ou apaga o schema e restaura ao vivo. Backup não testado é só esperança.

**12. Limite do seu backup?**
É lógico (fotografia do momento do `pg_dump`): o que aconteceu depois se perde. Recuperar até um instante exigiria arquivamento de WAL e `pg_basebackup` (PITR).

## 6. Perguntas prováveis — Frente 1 (para quem não é dela)

- **O que é um índice parcial e onde usamos?** Indexa só as linhas que cumprem uma condição. `ix_matricula_turma_ativa` indexa só matrículas `MATRICULADO`: menor, mais rápido e é exatamente o que o trigger de vagas consulta.
- **`EXPLAIN` x `EXPLAIN ANALYZE`?** O primeiro mostra o plano **estimado**. O segundo **executa** e mostra tempos e linhas reais. `BUFFERS` mostra páginas lidas (cache x disco).
- **O que o `EXCLUDE USING gist` garante?** Que duas linhas não tenham, ao mesmo tempo, a mesma sala no mesmo dia com horários sobrepostos (conflito de sala), o que um `UNIQUE` comum não consegue expressar.
- **O que é uma coluna gerada?** `media_geral` e `situacao` em `tb_historico` (e `ch_total_disciplina` em `tb_disciplina`) são calculadas pelo banco a partir de outras colunas e armazenadas (`STORED`); ninguém precisa (nem consegue) digitá-las erradas.
- **Por que o modelo tem `tb_historico` separado da matrícula?** Porque matrícula (o vínculo aluno-turma) e histórico (o resultado dessa matrícula) são 1:1 mas têm ciclos diferentes: a matrícula nasce na inscrição, as notas chegam no semestre. Um trigger (`tg_cria_historico`) garante que toda matrícula tenha seu histórico.
- **Por que `tb_turma_horario` tem `hora_inicio` e `hora_fim` e não um texto?** Para o banco comparar horários: com `timerange(hora_inicio, hora_fim)` o `EXCLUDE` recusa duas aulas na mesma sala, no mesmo dia, em horários que se sobrepõem.
- **Por que BRIN no log?** O log só cresce em ordem de tempo; BRIN guarda só o intervalo de valores por bloco de páginas: minúsculo e suficiente para filtro por data.
- **Por que GIN na ementa?** Busca textual (`to_tsvector`) precisa de índice invertido; B-tree não serve.

## 7. Se algo der errado na demo

- Aba trava no `FOR UPDATE`? É o esperado (a B está esperando a A). Dê `COMMIT` na A.
- Aba ficou com transação aberta e erro (`current transaction is aborted`)? `ROLLBACK;`.
- Quer repetir um cenário? `SELECT fn_reset_cenario_concorrencia(1);`.
- Papéis ficaram "grudados"? `RESET ROLE;`.
- Nada funciona? Tenha o backup: `restaurar.sh` recupera o banco em segundos.
