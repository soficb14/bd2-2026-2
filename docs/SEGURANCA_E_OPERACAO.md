# Segurança e operação: papéis, GRANT/REVOKE, RLS, views

**Frente:** Administração e Operação · **Scripts:** `sql/06_views.sql`, `sql/09_seguranca.sql` · **Roteiro de demonstração:** `docs/roteiro_demo_seguranca.sql`

## 1. Princípio

Defesa em camadas: (1) **GRANT/REVOKE** decidem quem toca em qual tabela ou coluna; (2) **RLS** decide quais *linhas* cada um enxerga dentro da tabela;
(3) **views** expõem só agregados quando o dado bruto não deve sair. Parte do zero: `REVOKE ALL ... FROM PUBLIC` e concede só o necessário.

## 2. Papéis e o que cada um pode

| Papel | Quem é | Enxerga | Escreve |
|---|---|---|---|
| `aluno` | cada aluno (login = `a` + CPF, ex. `a10000000001`) | **só a própria linha** em `tb_aluno`, **só as próprias** matrículas e **só o próprio histórico**; cadastros de oferta; vagas (agregado) | `INSERT` em `tb_matricula` **apenas em seu nome** e ativa; **não escreve em `tb_historico`** (nota e frequência) |
| `secretaria` | `sec_maria` | tudo, incluindo CPF | `tb_aluno`, `tb_matricula`, `tb_historico` (notas e frequência) e cadastros de oferta; **sem DELETE** |
| `coordenacao` | `coord_cco` | todos os dados acadêmicos e os indicadores; **sem CPF e sem data de nascimento** (privilégio por coluna) | nada (só leitura) |

Os logins de demonstração (`a10000000001`, `a10000000002`, `sec_maria`, `coord_cco`, senha `demo`) são só de laboratório.

## 3. Como o aluno é identificado na RLS

A função `fn_aluno_id(login)` devolve o `id_aluno` do aluno cujo login (`a` + CPF) é o informado; `tb_aluno` não tem matrícula, então o CPF faz esse papel. As policies usam `fn_aluno_id(current_user)`.

- É `SECURITY DEFINER` para ler `tb_aluno` sem passar pela própria RLS dessa tabela (evita dependência circular).
- Recebe o usuário **como parâmetro** porque dentro de uma função `SECURITY DEFINER` o `current_user` vira o dono da função, e não quem chamou.
- Tem `search_path` fixo e `EXECUTE` revogado de `PUBLIC` (boa prática contra sequestro de nomes).

## 4. Policies (resumo)

| Tabela | Policy | Para | Regra |
|---|---|---|---|
| `tb_aluno` | `aluno_ve_a_si_mesmo` | `aluno` | só a própria linha |
| `tb_matricula` | `aluno_ve_suas_matriculas` | `aluno` | `SELECT` só das próprias |
| `tb_matricula` | `aluno_se_matricula` | `aluno` | `INSERT ... WITH CHECK (id_aluno = ele mesmo AND status_matricula = 'MATRICULADO')` |
| `tb_historico` | `aluno_ve_seu_historico` | `aluno` | `SELECT` só das linhas cuja matrícula é dele |
| as três tabelas | `secretaria_total_*` / `coordenacao_le_*` | secretaria / coordenação | tudo / só leitura |

No modelo de 16 tabelas o **histórico é `tb_historico`** (1:1 com a matrícula) e não tem `id_aluno`: a posse vem de `tb_matricula`, então a policy `aluno_ve_seu_historico`
consulta as matrículas do aluno. Ela é o requisito central do edital ("o aluno nunca vê o histórico de outro"), e a view `vw_historico_aluno` (`security_invoker`) herda essa regra.
Total: 10 policies. A linha vazia do histórico é criada pelo trigger `tg_cria_historico` (`SECURITY DEFINER`), porque o aluno não tem permissão de escrita nessa tabela;
o log é gravado do mesmo jeito por `tg_log_matricula`.

## 5. A armadilha: RLS × trigger de vagas (decisão importante)

`fn_valida_vaga()` conta as matrículas da turma. Com RLS ligada em `tb_matricula`, se quem insere é um aluno, essa contagem enxergaria **só as matrículas dele**, e o limite
de vagas deixaria de valer para quem se matricula sozinho. Testado: numa turma de 1 vaga já ocupada, um aluno **entrou indevidamente** (2 matriculados).
Correção em `09_seguranca.sql`: `ALTER FUNCTION fn_valida_vaga() SECURITY DEFINER SET search_path = academico, pg_temp;`. Agora a contagem enxerga todas as linhas
e o trigger bloqueia como deveria.

## 6. Views

| Objeto | Para que serve | Segurança |
|---|---|---|
| `vw_oferta_turmas` | oferta do período: turma, disciplina, professor, horários e salas | roda com direitos do dono; liberada para os três papéis |
| `vw_vagas_turma` | vagas, ocupadas e restantes por turma | roda com direitos do dono: o aluno vê **quantas vagas restam sem ver quem está matriculado** |
| `vw_historico_aluno` | histórico legível | `security_invoker = true`: aplica a RLS de **quem consulta** (aluno vê só o seu) |
| `mv_indicadores_curso` (materializada) | taxa de aprovação, médias e frequência por curso/período | só secretaria e coordenação |

### Política de atualização da materialized view

Os indicadores só mudam quando notas e situação são lançadas ou fechadas: eventos raros e previsíveis, não cada matrícula. Um número "de ontem" serve à gestão;
recalcular a cada escrita (trigger por linha) tornaria a matrícula mais lenta sem benefício. Portanto:

1. Atualizar **todo dia de madrugada** e **manualmente após o fechamento de notas**.
2. Usar `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_indicadores_curso;`: não bloqueia quem consulta durante a atualização.
   Exige o índice único `uq_mv_indicadores_curso` (já criado) e a view já populada.
3. Custo aceito: o refresh concorrente é um pouco mais lento que o simples.

## 7. Limites (para a arguição)

- O dono das tabelas (`bd2`, superusuário) **ignora a RLS**. Em produção a aplicação não usaria o dono, e as tabelas teriam `FORCE ROW LEVEL SECURITY`.
- O mapeamento "login = a + CPF" é uma convenção de laboratório; em produção seria uma tabela de mapeamento ou um parâmetro de sessão definido pela aplicação.
- Papéis pertencem ao cluster: ver `docs/BACKUP_RESTAURACAO.md` (`pg_dumpall --globals-only`).
